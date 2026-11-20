import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/features/recommendation_evaluation/evaluation_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late RecommendationEvaluationAssets a;
  setUpAll(() async {
    a = await RecommendationEvaluationAssets.load();
  });
  test(
    'Declared original source and three evaluation populations stay frozen',
    () {
      expect(
        a.data['report']['source_hashes']['deep_recommendation_lab.json'],
        '2b4d02026b6313b78a123113923819e6bd9758e3b15cd49030fc14106b7a78fd',
      );
      expect(
        a.data['report']['source_hashes']['recommendation_lab.json'],
        '7b65af279ddf23cd1802c6fda0bb4fec9df5aea9d47e0da97f267e7c90524609',
      );
      for (final pair in [('warm', 28), ('broad', 116), ('cold', 88)]) {
        expect(evaluationCohort(a.data['rows'], pair.$1).length, pair.$2);
      }
      expect(a.totalPositive, 39254);
      expect(a.base.movies.length, 7867);
    },
  );
  test(
    'All eight policies and three cohorts reproduce full source scorecards',
    () {
      for (final method in evaluationMethods) {
        for (final scope in ['warm', 'broad', 'cold']) {
          final actual = evaluationScore(a.data['rows'], method, scope: scope),
              ref = a.data['scorecards'][method][scope];
          for (final key in actual.keys) {
            expect(actual[key], closeTo(ref[key], 1e-12));
          }
        }
      }
    },
  );
  test(
    'MRR is first relevant reciprocal rank and empty targets remain undefined',
    () {
      final m = evaluationMetrics([8, 3, 5, 7], [5, 7]);
      expect(m['mrr'], 1 / 3);
      expect(m['precision'], .2);
      expect(m['recall'], 1);
      expect(
        m['ndcg'],
        closeTo(
          (1 / math.log(4) * math.ln2 + 1 / math.log(5) * math.ln2) /
              (1 + 1 / math.log(3) * math.ln2),
          1e-12,
        ),
      );
      expect(evaluationMetrics([8], [3])['mrr'], 0);
      expect(evaluationMetrics([8], [])['mrr'], isNull);
      expect(evaluationScore([], 'neural50')['recall'], isNull);
    },
  );
  test(
    'All actual case MMR lists and every utility trace reproduce Python',
    () {
      for (final sample in a.data['samples']) {
        for (final strength in [1.0, .75, .5]) {
          final actual = a.mmr(
                List<int>.from(sample['candidates']),
                List<double>.from(sample['scores']),
                strength: strength,
              ),
              ref = sample['results']['mmr${strength == 1 ? '1' : strength}'];
          expect(actual.ranked, ref['ranked']);
          for (var j = 0; j < actual.trace.length; j++) {
            expect(actual.trace[j]['item'], ref['trace'][j]['item']);
            for (final key in ['raw', 'relevance', 'redundancy', 'utility']) {
              expect(
                actual.trace[j][key],
                closeTo(ref['trace'][j][key], 1e-11),
              );
            }
          }
        }
      }
    },
  );
  test('Lambda one recovers all116 original frozen neural100 lists', () {
    for (final row in a.data['rows']) {
      expect(row['rankings']['mmr1'], row['rankings']['neural100']);
    }
  });
  test('MMR handles constant relevance, deterministic IDs and empty pools', () {
    final ids = List<int>.from(a.data['samples'][0]['candidates'])
        .take(3)
        .toList();
    final r = a.mmr(ids, [2, 2, 2]);
    final sorted = [...ids]..sort();
    expect(r.ranked, sorted);
    expect(r.trace.first['utility'], 0);
    expect(a.mmr([], []).ranked, isEmpty);
    expect(a.listQuality([])['ild'], isNull);
    expect(a.listQuality([ids.first])['ild'], isNull);
  });
  test('Warm ILD rarity coverage and slot entropy reproduce all five source summaries', () {
    for (final method in (a.data['diversity'] as Map).keys) {
      final actual = a.diversity(method), ref = a.data['diversity'][method];
      for (final key in actual.keys) {
        expect(actual[key], closeTo(ref[key], 1e-11));
      }
    }
  });
  test('All eight paired intervals preserve source quantiles and confidence nesting', () {
    for (final key in (a.data['paired'] as Map).keys) {
      final ref = a.data['paired'][key]['bootstrap'],
          actual = a.interval(key),
          narrow = a.interval(key, confidence: .9),
          wide = a.interval(key, confidence: .99);
      expect(actual['users'], 28);
      expect(actual['mean'], ref['mean']);
      expect(actual['low'], closeTo(ref['low'], 1e-12));
      expect(actual['high'], closeTo(ref['high'], 1e-12));
      expect(wide['low']!, lessThanOrEqualTo(actual['low']!));
      expect(narrow['low']!, greaterThanOrEqualTo(actual['low']!));
      expect(wide['high']!, greaterThanOrEqualTo(actual['high']!));
      expect(narrow['high']!, lessThanOrEqualTo(actual['high']!));
    }
    expect(evaluationQuantile([3, 0, 2, 1], .25), .75);
    expect(() => evaluationQuantile([], .5), throwsArgumentError);
  });
  test(
    'Frozen future windows have separate gold cohorts and correct scorecards',
    () {
      expect(a.data['report']['future_window_boundary'], 1498029450);
      expect(
        a.data['windows']['early']['events'] +
            a.data['windows']['late']['events'],
        20168,
      );
      for (final w in (a.data['windows'] as Map).values) {
        for (final method in (w['scorecards'] as Map).keys) {
          final actual = evaluationScore(w['rows'], method),
              ref = w['scorecards'][method];
          for (final key in actual.keys) {
            expect(actual[key], closeTo(ref[key], 1e-12));
          }
        }
      }
    },
  );
  test('Declared propensity fixture verifies IPS SNIPS ESS and clipping separately', () {
    for (final clip in <double?>[null, 2]) {
      final actual = evaluationPropensity(clip: clip),
          ref = a.data[clip == null ? 'fixture' : 'fixture_clipped'];
      expect(actual['weights'], ref['weights']);
      for (final key in ['naive', 'ips', 'snips', 'ess']) {
        expect(actual[key], closeTo(ref[key], 1e-12));
      }
    }
    expect(evaluationPropensity()['ips'], 1.5625);
    expect(evaluationPropensity(clip: 2)['ips'], .8125);
    expect(evaluationPropensity(clip: 0)['snips'], isNull);
    expect(evaluationPropensity(clip: 0)['ess'], isNull);
  });
  test(
    'Fixed horizon planner uses absolute MDE and inverse square scaling',
    () {
      expect(evaluationSampleSize(), 14112);
      expect(evaluationSampleSize(), a.data['planner']['per_arm']);
      expect(evaluationSampleSize(mde: .005), 4 * evaluationSampleSize());
      expect(evaluationSampleSize(mde: .02), evaluationSampleSize() ~/ 4);
    },
  );
  test('Observed gain remains inconclusive and stronger MMR exchanges recall for genre ILD', () {
    final ci = a.interval('neural50:user_cf:recall');
    expect(ci['mean']!, greaterThan(0));
    expect(ci['low']!, lessThan(0));
    expect(ci['high']!, greaterThan(0));
    final cards = a.data['scorecards'];
    expect(
      cards['mmr0.5']['warm']['recall'],
      lessThan(cards['mmr1']['warm']['recall']),
    );
    expect(
      a.diversity('mmr0.5')['ild']!,
      greaterThan(a.diversity('mmr1')['ild']!),
    );
  });
}
