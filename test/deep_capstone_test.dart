import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/features/deep_capstone/deep_capstone_model.dart';
import 'package:ml_path/features/capstone/capstone_model.dart'
    show ValidationPrediction, PolicyResult, bestPolicyThreshold;

void main() {
  final raw = jsonDecode(
        File('assets/datasets/wine_quality/deep_capstone_lab.json')
            .readAsStringSync(),
      ) as Map<String, dynamic>,
      a = DeepCapstoneAssets.fromJson(raw);
  Map<String, dynamic> fresh() =>
      jsonDecode(jsonEncode(raw)) as Map<String, dynamic>;
  void near(List<double> got, dynamic expected) {
    expect(got.length, (expected as List).length);
    for (var k = 0; k < got.length; k++) {
      expect(got[k], closeTo((expected[k] as num).toDouble(), 1e-10));
    }
  }

  test(
    'All six actual observation and trained-pipeline forwards match PyTorch',
    () {
      for (var i = 0; i < 3; i++) {
        for (final r in raw['samples'][i]['references'] as List) {
          final t = a.pipelines[r['id']]!.forward(a.samples[i].raw);
          near(t.standardized, r['standardized']);
          near(t.pre, r['pre']);
          near(t.hidden, r['hidden']);
          expect(t.logit, closeTo(r['logit'], 1e-10));
          expect(t.probability, closeTo(r['probability'], 1e-12));
        }
      }
      expect(a.samples.map((s) => s.sourceRow), [3, 6, 11]);
    },
  );
  test(
    'Every decision threshold reproduces independent Python policy references',
    () {
      for (final row in raw['policy_curve'] as List) {
        final r = a.policy((row['threshold'] as num).toDouble());
        expect(
          [r.tn, r.fp, r.fn, r.tp],
          [row['tn'], row['fp'], row['fn'], row['tp']],
        );
        expect(r.meanCost, closeTo(row['mean_cost'], 1e-12));
        expect(r.precision, row['precision']);
        expect(r.recall, row['recall']);
      }
      expect(a.inspectBestThreshold(), .25);
      expect(a.threshold, .25);
      final zero = a.policy(0);
      expect(zero.fn + zero.tn, 0);
      expect(zero.tp, 620);
      expect(zero.fp, 335);
      final locked = a.policy(a.threshold);
      expect([locked.tn, locked.fp, locked.fn, locked.tp], [65, 270, 11, 609]);
    },
  );
  test('Inclusive boundaries undefined ratios costs and highest-threshold ties are explicit', () {
    ValidationPrediction row(int id, int label, double p) =>
        ValidationPrediction.fromJson({
          'source_row_1based': id,
          'quality': label == 1 ? 6 : 5,
          'positive': label,
          'probability': p,
        });
    final rows = [row(1, 0, .25), row(2, 1, .25)],
        r = PolicyResult.compute(rows, .25);
    expect(r.fp, 1);
    expect(r.tp, 1);
    final emptyPredictions = PolicyResult.compute(rows, 1);
    expect(emptyPredictions.precision, isNull);
    expect(emptyPredictions.recall, 0);
    final noPositiveTruth = PolicyResult.compute([row(1, 0, .2)], .5);
    expect(noPositiveTruth.recall, isNull);
    expect(bestPolicyThreshold([row(1, 1, .1), row(2, 1, .9)], costFn: 0), .95);
    expect(
      a.policy(.25, costFn: 8).meanCost,
      closeTo((270 + 8 * 11) / 955, 1e-12),
    );
    expect(a.threshold, .25);
    for (final t in [-.1, 1.1, double.nan]) {
      expect(() => a.policy(t), throwsArgumentError);
    }
    expect(() => a.policy(.25, costFn: -1), throwsArgumentError);
    expect(() => a.policy(.25, costFn: double.infinity), throwsArgumentError);
  });
  test('Fit-only grouped candidate selection is stable and separate from policy cost', () {
    expect(selectDeepWinner(a.candidates), 'mlp');
    expect(a.winner, 'mlp');
    final candidates = <DeepCandidate>[];
    for (var i = 0; i < 3; i++) {
      candidates.add(
        DeepCandidate.fromJson({
          'id': ['prior', 'logistic', 'mlp'][i],
          'declared_order': i,
          'fold_ap': [.5, .5, .5],
          'mean_ap': .5,
        }),
      );
    }
    expect(selectDeepWinner(candidates.reversed.toList()), 'prior');
    expect(a.mlpDecisionAp, closeTo(.8929086637376022, 1e-12));
    expect(a.noScaleDecisionAp, closeTo(.8130169547109198, 1e-12));
    expect(
      raw['decision_metrics']['logistic']['mean_cost'],
      lessThan(raw['decision_metrics']['mlp']['mean_cost']),
    );
    expect(a.winner, 'mlp');
  });
  test(
    'Declared source roles cover counts without exporting final observations',
    () {
      expect(a.roleRows, {'fit': 2975, 'decision': 955, 'test': 968});
      expect(a.fitIds.length, 2975);
      expect(a.decisionIds.length, 955);
      expect(a.fitIds.toSet().intersection(a.decisionIds.toSet()), isEmpty);
      expect(
        a.decisions.every((r) => a.decisionIds.contains(r.sourceRow)),
        isTrue,
      );
      expect(
        a.samples.every((s) => a.decisionIds.contains(s.sourceRow)),
        isTrue,
      );
      expect(raw['selection']['test_rows_in_labs'], 0);
      for (final p in a.pipelines.values) {
        expect(p.loss.length, 81);
        expect(p.loss.last, lessThan(p.loss.first));
      }
      expect(raw['pipelines'][0]['initial'], raw['pipelines'][1]['initial']);
      expect(a.pipelines['no_scale']!.mean.every((v) => v == 0), isTrue);
      expect(a.pipelines['no_scale']!.scale.every((v) => v == 1), isTrue);
    },
  );
  test('Artifact rejects feature permutations and invalid arithmetic before returning scores', () {
    final p = a.pipelines['scaled']!, x = a.samples.first.raw;
    expect(
      () => p.forward(x, names: whiteFeatures.reversed.toList()),
      throwsFormatException,
    );
    expect(() => p.forward(x.take(10).toList()), throwsFormatException);
    for (final value in [double.nan, double.infinity, 1e308]) {
      expect(() => p.forward(List.filled(11, value)), throwsArgumentError);
    }
    final scaled = p.forward(x), noScale = a.pipelines['no_scale']!.forward(x);
    expect((scaled.logit - noScale.logit).abs(), greaterThan(1e-4));
    near(noScale.standardized, x);
  });
  test('Source observations model weights histories and inference traces are immutable', () {
    final p = a.pipelines['scaled']!, t = p.forward(a.samples.first.raw);
    expect(() => a.pipelines.clear(), throwsUnsupportedError);
    expect(() => a.samples.first.raw[0] = 0, throwsUnsupportedError);
    expect(() => a.fitIds[0] = 1, throwsUnsupportedError);
    expect(() => a.features[0] = 'bad', throwsUnsupportedError);
    expect(() => p.w1[0][0] = 0, throwsUnsupportedError);
    expect(() => p.loss[0] = 0, throwsUnsupportedError);
    expect(() => t.hidden[0] = 0, throwsUnsupportedError);
  });
  test('Corrupt transforms candidate means source identities and locked policies fail', () {
    for (final change in <void Function(Map<String, dynamic>)>[
      (j) => j['features'][0] = 'alcohol',
      (j) => j['parameter_count'] = 53,
      (j) => j['pipelines'][0]['scale'][0] = 0,
      (j) => j['pipelines'][0]['weights']['w1'][0] = [0, 1],
      (j) => j['pipelines'][1]['mean'][0] = 1,
      (j) => j['pipelines'][0]['history'][80]['epoch'] = 79,
      (j) => j['selection']['winner'] = 'prior',
      (j) => j['selection']['candidates'][2]['mean_ap'] = .1,
      (j) => j['selection']['threshold'] = .5,
      (j) => j['selection']['test_rows_in_labs'] = 1,
      (j) => j['samples'][0]['source_row_1based'] = j['fit_rows_1based'][0],
      (j) =>
          j['decision_rows'][0]['source_row_1based'] = j['fit_rows_1based'][0],
    ]) {
      final j = fresh();
      change(j);
      expect(() => DeepCapstoneAssets.fromJson(j), throwsA(anything));
    }
  });
}
