import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/features/deep_recommendation/deep_recommendation_model.dart';
import 'package:ml_path/features/recommendation/recommendation_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DeepRecommendationAssets a;
  setUpAll(() async {
    a = await DeepRecommendationAssets.load();
  });
  test('Inner roles are disjoint complete pre-cutoff partitions with original mapping', () {
    final r = Set<int>.from(a.data['retrieval_indices']),
        k = Set<int>.from(a.data['ranking_indices']);
    expect(r.length, 64411);
    expect(k.length, 16257);
    expect(r.intersection(k), isEmpty);
    expect(r.union(k).length, 80668);
    expect(a.users.length, 522);
    expect(a.items.length, 7867);
    expect(a.itemPositive.reduce((x, y) => x + y), 31330);
  });
  test(
    'All522 query and7867 item full neural forwards reproduce saved vectors',
    () {
      for (final pair in [
        (a.queries, a.data['query_vectors']),
        (a.vectors, a.data['item_vectors']),
      ]) {
        for (var j = 0; j < pair.$1.length; j++) {
          for (var k = 0; k < 8; k++) {
            expect(pair.$1[j][k], closeTo(pair.$2[j][k], 1e-11));
          }
          expect(deepDot(pair.$1[j], pair.$1[j]), closeTo(1, 1e-10));
        }
      }
    },
  );
  test(
    'Every source example raw features,scaler and complete MLP logits match',
    () {
      for (final s in a.data['samples']) {
        for (final r in s['scores']) {
          final f = a.features(s['user'], r['item']), z = a.standardize(f);
          for (var j = 0; j < 5; j++) {
            expect(f[j], closeTo(r['features'][j], 1e-11));
            expect(z[j], closeTo(r['standardized'][j], 1e-11));
          }
          expect(a.logit(f), closeTo(r['logit'], 1e-10));
        }
      }
    },
  );
  test('All464 actual candidate pools and reranked lists match exact Python pipeline', () {
    for (final row in a.data['rows']) {
      for (final entry in [
        ('neural20', 20, false),
        ('neural50', 50, false),
        ('neural100', 100, false),
        ('hybrid50', 50, true),
      ]) {
        final p = a.run(row['user'], budget: entry.$2, hybrid: entry.$3),
            ref = row['pipelines'][entry.$1];
        expect(
          p.candidates,
          ref['candidates'],
          reason: '${row['user']} ${entry.$1}',
        );
        expect(p.ranked, ref['ranked']);
        expect(p.fallback, ref['fallback']);
      }
    }
  });
  test(
    'Actual first batch all256 multi-positive row losses and mean reproduce',
    () {
      final actual = a.batchLoss(), ref = a.data['first_batch'];
      expect(actual.length, 256);
      for (var j = 0; j < actual.length; j++) {
        expect(actual[j], closeTo(ref['loss'][j], 1e-10));
      }
      expect(
        actual.reduce((x, y) => x + y) / actual.length,
        closeTo(ref['mean_loss'], 1e-10),
      );
      expect(
        (ref['positive_columns'] as List).any((p) => (p as List).length > 1),
        isTrue,
      );
      expect(
        (ref['candidates'] as List).toSet().length,
        (ref['candidates'] as List).length,
      );
    },
  );
  test('Declared two-positive CE differs from positive-set mass loss and stays finite', () {
    const q = [
          [1.0, 0.0],
        ],
        c = [
          [1.0, 0.0],
          [0.0, 1.0],
          [-1.0, 0.0],
        ],
        positive = [
          [0, 1],
        ];
    final actual = deepBatchLoss(q, c, positive, temperature: 1).first,
        logz = math.log(math.exp(1) + 1 + math.exp(-1));
    expect(actual, closeTo(logz - .5, 1e-12));
    expect(actual, isNot(closeTo(logz - math.log(math.exp(1) + 1), 1e-8)));
    expect(deepLogSumExp([1000, 1000]), closeTo(1000 + math.log(2), 1e-12));
  });
  test(
    'Candidate prefixes nest but actual larger pool final Recall can worsen',
    () {
      final uid = a.data['samples'][0]['user'] as int;
      final p20 = a.run(uid, budget: 20),
          p50 = a.run(uid, budget: 50),
          p100 = a.run(uid, budget: 100);
      expect(p50.candidates.take(20).toList(), p20.candidates);
      expect(p100.candidates.take(50).toList(), p50.candidates);
      final s = a.data['scorecards'];
      expect(
        s['neural100']['warm']['candidate_recall'],
        greaterThan(s['neural50']['warm']['candidate_recall']),
      );
      expect(
        s['neural100']['warm']['recall'],
        lessThan(s['neural50']['warm']['recall']),
      );
    },
  );
  test(
    'Hybrid dedup preserves source pools and allseen low-rating filters',
    () {
      final uid = a.data['samples'][0]['user'] as int,
          p = a.run(uid, hybrid: true),
          neural = a.run(uid),
          pop = a.base
              .recommend(uid, 'popularity', k: 50)
              .map((r) => r.movie)
              .toSet();
      expect(p.candidates.toSet(), {...neural.candidates, ...pop});
      expect(p.candidates.length, lessThanOrEqualTo(100));
      expect(p.candidates.toSet().length, p.candidates.length);
      expect(p.ranked.every(p.candidates.contains), isTrue);
      expect(
        p.candidates.every((i) => !a.base.history[uid]!.containsKey(i)),
        isTrue,
      );
      expect(a.base.history[uid]!.values.any((r) => r < 4), isTrue);
    },
  );
  test('Actual cold source user bypasses ranker and matches popularity for every budget', () {
    final uid = (a.data['samples'] as List).last['user'] as int;
    expect(a.isCold(uid), isTrue);
    for (final budget in [20, 50, 100]) {
      final p = a.run(uid, budget: budget, hybrid: true);
      expect(p.fallback, isTrue);
      expect(
        p.candidates,
        a.base
            .recommend(uid, 'popularity', k: budget)
            .map((r) => r.movie)
            .toList(),
      );
      expect(p.ranked, p.candidates.take(10).toList());
    }
  });
  test(
    'All pipeline cohort metrics,candidate/oracle ceilings match frozen report',
    () {
      for (final config in deepRecommendationConfigs) {
        for (final warm in [true, false]) {
          final actual = deepPipelineScore(
                a.data['rows'],
                config,
                warmOnly: warm,
              ),
              ref = a.data['scorecards'][config][warm ? 'warm' : 'all'];
          for (final key in actual.keys) {
            expect(
              actual[key],
              closeTo(ref[key], 1e-12),
              reason: '$config $key',
            );
          }
          expect(
            actual['recall'],
            lessThanOrEqualTo(actual['oracle_recall10']! + 1e-12),
          );
          expect(
            actual['oracle_recall10'],
            lessThanOrEqualTo(actual['candidate_recall']! + 1e-12),
          );
        }
      }
      expect(deepPipelineScore([], 'neural50')['candidate_recall'], isNull);
    },
  );
  test(
    'Feature mean-neutralization yields z0 and changes actual frozen logit',
    () {
      final s = a.data['samples'][0]['scores'][0],
          u = a.data['samples'][0]['user'] as int,
          f = a.features(u, s['item']),
          changed = [...f]..[0] = a.featureMean[0];
      expect(a.standardize(changed)[0], 0);
      expect(a.logit(changed), isNot(closeTo(a.logit(f), 1e-8)));
    },
  );
  test('Recorded baseline controls preserve same source rows and independent scorecards', () {
    for (var j = 0; j < (a.data['rows'] as List).length; j++) {
      final r = a.data['rows'][j], old = a.base.data['rows'][j];
      for (final key in ['user', 'eligible', 'positive', 'train_count']) {
        expect(r[key], old[key]);
      }
    }
    for (final m in ['popularity', 'user_cf']) {
      for (final warm in [true, false]) {
        final s = recommendationScorecard(
              a.data['rows'],
              m,
              warmOnly: warm,
              catalogSize: a.items.length,
            ),
            r = a.data['scorecards'][m][warm ? 'warm' : 'all'];
        expect(s['recall'], closeTo(r['recall'], 1e-12));
      }
    }
  });
}
