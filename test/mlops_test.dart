import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/features/mlops/mlops_model.dart';
import 'package:ml_path/features/feature_systems/feature_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MLOpsAssets a;
  setUpAll(() async {
    a = await MLOpsAssets.load();
  });
  void same(dynamic x, dynamic y) {
    if (y is Map) {
      expect((x as Map).keys.toSet(), y.keys.toSet());
      for (final k in y.keys) {
        same(x[k], y[k]);
      }
    } else if (y is List) {
      expect((x as List).length, y.length);
      for (var i = 0; i < y.length; i++) {
        same(x[i], y[i]);
      }
    } else if (y is num) {
      expect(x, closeTo(y, 1e-8));
    } else {
      expect(x, y);
    }
  }

  Map<String, dynamic> clone(dynamic x) =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(x)));
  test('Real source prefix and disjoint358 fit/182 development roles exclude reserved184', () {
    final r = a.data['report'];
    expect(r['used_rows'], 547);
    expect(r['reserved_outcomes_used'], 0);
    expect(r['fit_target_range'], [7, 364]);
    expect(r['development_target_range'], [365, 546]);
    expect(a.data['training'].length, 358);
    expect(a.data['rows'].length, 182);
    expect(
      r['source_hashes']['day.csv'],
      'a6bcf826782d3c0fbfdcbeead17cd0884185a0dafe8ff10cd48a874ee7ba18be',
    );
    for (final s in featureScenarios) {
      expect(a.data['events'][s].length, 547);
      expect(a.data['events'][s].last['date'], '2012-06-30');
    }
    expect(
      a.data['feature_definition']['feature_version'],
      'bike-features35-v1',
    );
  });
  test('Every182 Dart Ridge prediction and seasonal baseline match independent Python fit', () {
    for (final r in a.data['rows']) {
      final f = a.features(r['target'], 'on_time');
      same(f, r['features']);
      expect(
        mlopsPredict(clone(a.data['models']['candidate']), f),
        closeTo(r['candidate'], 1e-8),
      );
      expect(
        mlopsPredict(clone(a.data['models']['baseline']), f),
        r['baseline'],
      );
      expect(r['outcome'], a.data['events']['on_time'][r['target']]['cnt']);
      final response = a.serve(r['target']);
      expect(response['model_version'], 'ridge36-v1');
      expect(response['feature_version'], 'bike-features35-v1');
    }
  });
  test(
    'Fit-only scaler/intercept implement manual ordered inference and clipping',
    () {
      final model = clone(a.data['models']['candidate']);
      expect(model['alpha'], 10);
      expect(model['fit_examples'], 358);
      expect(model['intercept'], closeTo(3446.0614525139663, 1e-8));
      for (final k in mlopsInputFields) {
        final j = mlopsInputFields.indexOf(k),
            values = [
              for (final r in a.data['training'])
                (r['features'][k] as num).toDouble(),
            ],
            mean = values.reduce((x, y) => x + y) / values.length,
            sd = math.sqrt(
              values
                      .map((v) => (v - mean) * (v - mean))
                      .reduce((x, y) => x + y) /
                  values.length,
            );
        expect(model['mean'][j], closeTo(mean, 1e-8));
        expect(model['scale'][j], closeTo(sd, 1e-8));
      }
      final f = a.features(375, 'on_time');
      var manual = (model['intercept'] as num).toDouble();
      for (var j = 0; j < 3; j++) {
        manual +=
            (model['weights'][j] as num) *
            (f[mlopsInputFields[j]]! - (model['mean'][j] as num)) /
            (model['scale'][j] as num);
      }
      expect(mlopsPredict(model, f), closeTo(manual, 1e-8));
      model['intercept'] = -1e8;
      expect(mlopsPredict(model, f), 0);
      expect(mlopsPredict(model, {}), isNull);
    },
  );
  test(
    'Stable UTF8 FNV1a32 known vectors and all four route thresholds agree',
    () {
      expect(mlopsBucket(''), 2166136261 % 10000);
      expect(mlopsBucket('hello'), 0x4f9f2cab % 10000);
      expect(mlopsBucket('a'), 0xe40c292c % 10000);
      for (final scenario in featureScenarios) {
        for (final bp in [0, 1000, 5000, 10000]) {
          same(
            a.replay(scenario: scenario, canaryBp: bp),
            a.data['rollouts'][scenario]['$bp'],
          );
        }
      }
      expect(a.replay(canaryBp: 1000)['candidate'], 22);
      expect(() => a.serve(547), throwsArgumentError);
      expect(() => a.serve(375, canaryBp: 1), throwsArgumentError);
    },
  );
  test('Two arrival schedules preserve real observations while candidate eligibility changes', () {
    var fallback = 0;
    for (var t = 365; t < 547; t++) {
      final f = pointInTimeFeatures(a.data['events']['late_fixture'], t),
          r = a.serve(t, scenario: 'late_fixture');
      same(r['features'], f);
      if (f['lag1'] == null) {
        fallback++;
        expect(r['served'], 'fallback');
        expect(r['prediction'], f['lag7']);
      } else {
        expect(r['served'], 'candidate');
      }
    }
    expect(fallback, 11);
    expect(
      a.serve(375, scenario: 'late_fixture')['reason'],
      'missing_candidate_features',
    );
  });
  test(
    'Rollback and candidate fault route only independently validated baseline',
    () {
      for (final s in featureScenarios) {
        same(a.replay(scenario: s, rollback: true), {
          'requests': 182,
          'candidate': 0,
          'baseline': 182,
          'fallback': 0,
          'blocked': 0,
        });
        expect(a.replay(scenario: s, candidateFault: true)['fallback'], 182);
      }
      final blocked = a.serve(375, baselineFault: true);
      expect(blocked['status'], 'BLOCKED');
      expect(blocked.containsKey('features'), isFalse);
      expect(blocked['prediction'], isNull);
      expect(blocked['model_version'], isNull);
      expect(
        _NoLookup(a.data).serve(375, baselineFault: true)['status'],
        'BLOCKED',
      );
      expect(
        a.serve(375, rollback: true, candidateFault: true)['reason'],
        'rollback',
      );
    },
  );
  test(
    'Every five-field contract fault and malformed model schema rejects safely',
    () {
      final expected = clone(a.data['manifests']['candidate']);
      for (final k in expected.keys) {
        expect(mlopsContractErrors(expected, {...expected, k: 'wrong'}), [k]);
        final missing = {...expected}..remove(k);
        expect(mlopsContractErrors(expected, missing), [k]);
      }
      for (final change in [
        {
          'scale': [1, 0, 1],
        },
        {
          'weights': [1, 2],
        },
        {'intercept': double.nan},
        {'model_version': ''},
        {
          'mean': [1, double.infinity, 3],
        },
        {
          'input_fields': ['lag7', 'lag1', 'mean7'],
        },
      ]) {
        final bad = {...clone(a.data['models']['candidate']), ...change};
        expect(mlopsValidModel(bad), isFalse);
        expect(mlopsPredict(bad, a.features(375, 'on_time')), isNull);
      }
      final bad = clone(a.data);
      bad['models']['candidate']['scale'] = [1, 0, 1];
      expect(MLOpsAssets(bad).serve(375)['served'], 'fallback');
      bad['models']['baseline']['input_fields'] = [];
      expect(MLOpsAssets(bad).serve(375)['status'], 'BLOCKED');
      expect(
        mlopsPredict(clone(a.data['models']['candidate']), {
          'lag1': double.nan,
          'lag7': 1,
          'mean7': 2,
        }),
        isNull,
      );
    },
  );
  test('All nine actual feature drift bin counts,masses and PSI match NumPy reference', () {
    for (final period in mlopsPeriods.keys) {
      for (final feature in mlopsInputFields) {
        same(
          a.monitoring(period, feature),
          a.data['monitoring'][period][feature],
        );
      }
    }
    final s = mlopsPsi([0, 1, 2], [1, 2, 3], [1, 2]);
    expect(s['reference_bins'], [1, 1, 1]);
    expect(s['observed_bins'], [0, 1, 2]);
    expect(
      (s['reference_mass'] as List).cast<double>().reduce((x, y) => x + y),
      closeTo(1, 1e-12),
    );
  });
  test(
    'All nine period/maturity audits compare the same mature-label populations',
    () {
      for (final period in mlopsPeriods.keys) {
        for (final delay in [0, 2, 7]) {
          final q = a.quality(period, delay: delay);
          same(q, a.data['quality'][period]['$delay']);
          expect(q['mature_labels'], (period == 'full' ? 182 : 91) - delay);
          for (final m in ['candidate', 'baseline', 'naive1']) {
            expect(q['models'][m]['labels'], q['mature_labels']);
          }
        }
      }
      expect(
        a.quality('full')['models']['candidate']['mae'],
        closeTo(811.4206425486229, 1e-8),
      );
    },
  );
  test('SLO success+latency denominator,budget,burn and all threshold/target controls', () {
    final rows = a.data['slo']['rows'] as List;
    for (final threshold in [50, 100, 200]) {
      for (final target in [.95, .99, .999]) {
        final s = mlopsSlo(rows, threshold: threshold, target: target),
            good = rows
                .where((r) => r['ok'] == true && r['duration_ms'] <= threshold)
                .length;
        expect(s['good'], good);
        expect(s['composite_sli'], good / 20);
        expect(s['availability'], .9);
        expect(s['allowed_bad'], closeTo(20 * (1 - target), 1e-12));
        expect(
          s['remaining_bad'],
          closeTo(20 * (1 - target) - (20 - good), 1e-12),
        );
        expect(s['burn_rate'], closeTo((20 - good) / 20 / (1 - target), 1e-9));
      }
    }
    final s = mlopsSlo(rows);
    expect(s['good'], 16);
    expect(s['burn_rate'], closeTo(20, 1e-10));
  });
  test('Exact linear quantiles and cumulative histogram preserve all/error populations', () {
    final s = mlopsSlo(a.data['slo']['rows']);
    expect(s['p95_all'], closeTo(152.5, 1e-10));
    expect(s['p95_success'], closeTo(133, 1e-10));
    same(s['histogram'], a.data['slo']['histogram']);
    expect(mlopsQuantile([1], .95), 1);
    expect(mlopsQuantile([2, 1], .5), 1.5);
    expect(mlopsQuantile([], .95), isNull);
  });
  test('Empty telemetry is undefined and future labels cannot influence historical features', () {
    final s = mlopsSlo([]);
    for (final key in [
      'availability',
      'composite_sli',
      'burn_rate',
      'p95_all',
      'p95_success',
    ]) {
      expect(s[key], isNull);
    }
    expect(s['requests'], 0);
    expect(() => mlopsSlo([], target: 1), throwsArgumentError);
    final data = clone(a.data);
    for (final r in data['events']['on_time']) {
      if (r['event_day'] >= 375) {
        r['cnt'] = 999999;
      }
    }
    same(
      MLOpsAssets(data).features(375, 'on_time'),
      a.features(375, 'on_time'),
    );
  });
}

class _NoLookup extends MLOpsAssets {
  _NoLookup(super.data);
  @override
  Map<String, num?> features(int target, String scenario) =>
      throw StateError('Lookup must not run before contract validation');
}
