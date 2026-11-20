import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/features/capstone/capstone_model.dart';

ValidationPrediction row(int id, int y, double p) =>
    ValidationPrediction.fromJson({
      'source_row_1based': id,
      'quality': y == 1 ? 6 : 5,
      'positive': y,
      'probability': p,
    });
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Policy includes exact-threshold ties and computes cost from aligned counts', () {
    final rows = [row(1, 0, .2), row(2, 1, .3), row(3, 1, .9), row(4, 0, .7)],
        r = PolicyResult.compute(rows, .3);
    expect([r.tn, r.fp, r.fn, r.tp], [1, 1, 0, 2]);
    expect(r.precision, closeTo(2 / 3, 1e-12));
    expect(r.meanCost, .25);
    final all = PolicyResult.compute(rows, 0);
    expect(all.tp + all.fp, rows.length);
    final none = PolicyResult.compute(rows, 1);
    expect(none.precision, isNull);
    expect(none.recall, 0);
    expect(PolicyResult.compute([row(1, 1, 1)], 1).tp, 1);
    expect(() => PolicyResult.compute(rows, double.nan), throwsArgumentError);
    expect(() => PolicyResult.compute([], 0), throwsArgumentError);
    expect(
      () => PolicyResult.compute(rows, .5, costFn: -1),
      throwsArgumentError,
    );
  });
  test(
    'Highest threshold wins equal grid costs and costs can change the optimum',
    () {
      final negatives = [row(1, 0, .1), row(2, 0, .1)];
      expect(bestPolicyThreshold(negatives), .95);
      final rows = [row(1, 1, .2), row(2, 0, .3), row(3, 0, .6), row(4, 1, .8)];
      expect(
        bestPolicyThreshold(rows, costFn: 10),
        lessThanOrEqualTo(bestPolicyThreshold(rows, costFn: 1)),
      );
      expect(() => row(1, 1, 1.1), throwsFormatException);
    },
  );
  test(
    'All decision policies reproduce independent Python reference counts',
    () async {
      final a = await CapstoneAssets.load(),
          j = jsonDecode(
            await rootBundle.loadString(
              'assets/datasets/wine_quality/capstone_lab.json',
            ),
          );
      expect(a.rows.length, 313);
      expect(a.selectedId, 'logistic_1');
      expect(a.lockedThreshold, .3);
      for (final ref in j['policy_reference']) {
        final r = PolicyResult.compute(
          a.rows,
          (ref['threshold'] as num).toDouble(),
        );
        expect(
          [r.tn, r.fp, r.fn, r.tp],
          [ref['tn'], ref['fp'], ref['fn'], ref['tp']],
        );
        expect(
          r.meanCost,
          closeTo((ref['mean_cost'] as num).toDouble(), 1e-12),
        );
      }
      expect(bestPolicyThreshold(a.rows), a.lockedThreshold);
      final r = PolicyResult.compute(a.rows, .3);
      expect([r.tp, r.fp, r.fn, r.tn], [148, 67, 15, 83]);
    },
  );
  test(
    'Candidate board means agree with all folds and selected fit-CV rule',
    () async {
      final a = await CapstoneAssets.load();
      expect(a.candidates.length, 7);
      for (final c in a.candidates) {
        expect(c.meanAp, closeTo(c.foldAp.reduce((a, b) => a + b) / 3, 1e-12));
        expect(
          c.meanAp,
          lessThanOrEqualTo(a.candidates[a.selectedIndex].meanAp),
        );
      }
      expect(() => a.candidates[0].foldAp[0] = 1, throwsUnsupportedError);
      expect(() => a.rows.clear(), throwsUnsupportedError);
    },
  );
  test('Stable sigmoid covers extreme finite logits without overflow', () {
    expect(stableSigmoid(0), .5);
    expect(stableSigmoid(1000), 1);
    expect(stableSigmoid(-1000), 0);
    expect(stableSigmoid(.3) + stableSigmoid(-.3), closeTo(1, 1e-12));
    expect(() => stableSigmoid(double.infinity), throwsArgumentError);
  });
  test('Every actual pipeline query reconstructs the sklearn golden logit and probability', () async {
    final a = await CapstoneAssets.load(), p = a.pipeline;
    expect(p.features.length, 11);
    expect(p.queries.length, 24);
    for (final q in p.queries) {
      final terms = p.contributions(q.values),
          manual = p.bias + terms.reduce((a, b) => a + b);
      expect(manual, closeTo(q.referenceLogit, 1e-9));
      expect(p.probability(q.values), closeTo(q.referenceProbability, 1e-10));
      final z = p.standardize(q.values);
      for (var i = 0; i < 11; i++) {
        expect(z[i] * p.scale[i] + p.mean[i], closeTo(q.values[i], 1e-9));
      }
      expect(a.rows.any((r) => r.sourceRow == q.sourceRow), isTrue);
    }
    expect(() => p.mean[0] = 0, throwsUnsupportedError);
    expect(() => p.queries[0].values[0] = 0, throwsUnsupportedError);
    expect(() => p.probability([1]), throwsArgumentError);
  });
  test(
    'Lower thresholds include every higher-threshold positive prediction',
    () async {
      final a = await CapstoneAssets.load();
      var previous = a.rows.length;
      for (var i = 0; i <= 20; i++) {
        final r = PolicyResult.compute(a.rows, i / 20);
        expect(r.tp + r.fp, lessThanOrEqualTo(previous));
        previous = r.tp + r.fp;
        expect(r.n, 313);
      }
    },
  );
  test('Manifest parsing rejects corrupt scores, feature contracts and policy locks', () async {
    final source = await rootBundle.loadString(
      'assets/datasets/wine_quality/capstone_lab.json',
    );
    final policy = jsonDecode(source);
    policy['locked_threshold'] = .9;
    expect(() => CapstoneAssets.fromJson(policy), throwsFormatException);
    final pipeline = jsonDecode(source);
    pipeline['logistic_reference']['weights'][0] = 999;
    expect(() => CapstoneAssets.fromJson(pipeline), throwsFormatException);
    final score = jsonDecode(source);
    score['candidates'][0]['mean_ap'] = 2;
    expect(() => CapstoneAssets.fromJson(score), throwsFormatException);
    final scale = jsonDecode(source);
    scale['logistic_reference']['scale'][0] = 0;
    expect(() => CapstoneAssets.fromJson(scale), throwsFormatException);
  });
}
