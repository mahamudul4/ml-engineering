import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/features/experimentation/experiment_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ExperimentAssets a;
  setUpAll(() async {
    a = await ExperimentAssets.load();
  });
  void same(dynamic x, dynamic y) {
    if (y is Map) {
      for (final k in y.keys) {
        if (k != 'scope') {
          same(x[k], y[k]);
        }
      }
    } else if (y is List) {
      expect((x as List).length, y.length);
      for (var j = 0; j < y.length; j++) {
        same(x[j], y[j]);
      }
    } else if (y is num) {
      expect(x, closeTo(y, math.max(2e-7, y.abs() * 1e-11)));
    } else {
      expect(x, y);
    }
  }

  Map<String, dynamic> clone(dynamic x) =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(x)));
  test('Historical source roles,original hashes and unknown counterfactuals remain explicit', () {
    expect(a.data['report']['experimental_units'], 445);
    expect(a.data['report']['license'], 'CC BY-NC 2.0');
    expect(a.data['cohorts']['treated'].length, 185);
    expect(a.data['cohorts']['experimental'].length, 260);
    expect(a.data['cohorts']['psid'].length, 2490);
    expect(
      a.data['report']['source_sha256']['nswre74_treated.txt'],
      'e7b742fe0ff07a0f45e129b4ff108bb9611cd83d53604732c48a8a0a3e20eda3',
    );
    expect(a.trialRows.map((r) => r['key']).toSet().length, 445);
    for (final r in a.trialRows) {
      expect(r.containsKey('y0'), isFalse);
      expect(r.containsKey('y1'), isFalse);
    }
  });
  test('Every outcome/confidence mean,unbiased variance,SE,df and Welch interval matches SciPy', () {
    for (final outcome in experimentOutcomes) {
      for (final confidence in experimentConfidences) {
        same(
          a.trial(outcome, confidence),
          a.data['trial'][outcome]['$confidence'],
        );
      }
    }
    expect(a.trial('earnings', .95)['delta'], closeTo(1794.342404270269, 1e-8));
    expect(a.trial('earnings', .95)['se'], closeTo(670.9965463815241, 1e-8));
  });
  test('Positive-earnings source transformation preserves counts and percentage-point units', () {
    final t = experimentValues(a.data['cohorts']['treated'], 'positive'),
        c = experimentValues(a.data['cohorts']['experimental'], 'positive');
    expect(t.where((v) => v == 1).length, 140);
    expect(c.where((v) => v == 1).length, 168);
    expect(
      a.trial('positive', .95)['delta'] * 100,
      closeTo(11.06029106029106, 1e-10),
    );
    expect(() => experimentValues([], 'employment'), throwsArgumentError);
  });
  test('All1000 saved185/445 allocations are unique complements and reproduce both null banks', () {
    final bank = a.data['permutation_bank'] as List;
    expect(bank.length, 1000);
    for (var j = 0; j < bank.length; j++) {
      final ids = (bank[j]['treated_indices'] as List).cast<int>();
      expect(ids.length, 185);
      expect(ids.toSet().length, 185);
      expect(ids.every((i) => i >= 0 && i < 445), isTrue);
      expect(bank[j]['seed'], 37000 + j);
    }
    for (final k in experimentOutcomes) {
      final actual = a.nullValues(k);
      for (var j = 0; j < bank.length; j++) {
        expect(actual[j], closeTo(bank[j][k], 1e-8));
      }
    }
  });
  test('All six randomization prefixes preserve absolute tails,plus-one correction and histograms', () {
    for (final k in experimentOutcomes) {
      for (final n in [100, 500, 1000]) {
        same(a.randomization(k, n), a.data['randomization'][k]['$n']);
        expect(
          (a.randomization(k, n)['bins'] as List).cast<int>().reduce(
            (x, y) => x + y,
          ),
          n,
        );
      }
    }
    final none = experimentRandomization([0, 0], 10, 2);
    expect(none['p_value'], 1 / 3);
    expect(experimentRandomization([1, -1, 0], 1, 3)['extreme'], 2);
    expect(() => experimentRandomization([1], 1, 2), throwsArgumentError);
  });
  test('All108 sample-size/power/cluster planning references match SciPy normal calculations', () {
    expect((a.data['planning'] as Map).length, 108);
    for (final ref in (a.data['planning'] as Map).values) {
      same(
        a.plan(
          delta: ref['delta'],
          allocation: ref['allocation'],
          alpha: ref['alpha'],
          power: ref['power_target'],
          clusterSize: ref['cluster_size'],
          icc: (ref['icc'] as num).toDouble(),
        ),
        ref,
      );
    }
  });
  test('Smaller MDE,allocation imbalance and clustering change required evidence as expected', () {
    final baseline = a.plan(),
        small = a.plan(delta: 1000),
        large = a.plan(delta: 4000),
        imbalanced = a.plan(allocation: .7),
        clustered = a.plan(clusterSize: 5, icc: .05);
    expect(
      small['unrounded_total'],
      closeTo(4 * baseline['unrounded_total'], 1e-8),
    );
    expect(
      large['unrounded_total'],
      closeTo(baseline['unrounded_total'] / 4, 1e-8),
    );
    expect(imbalanced['total'], greaterThan(baseline['total']));
    expect(clustered['design_effect'], 1.2);
    expect(clustered['adjusted_units'], (baseline['total'] * 1.2).ceil());
    expect(() => a.plan(delta: 0), throwsArgumentError);
  });
  test('Logging hash rehearsal matches all source keys and actual declared loss counts', () {
    expect(experimentBucket('hello'), 0x4f9f2cab % 10000);
    for (final loss in [false, true]) {
      same(
        experimentLogging(a.trialRows, loss: loss),
        a.data['logging'][loss ? 'True' : 'False'],
      );
    }
    final fault = experimentLogging(a.trialRows, loss: true);
    expect(fault['dropped'], 77);
    expect(fault['treated'], 148);
    expect(fault['control'], 220);
    expect(fault['flag'], isTrue);
    expect(() => experimentLogging([]), throwsArgumentError);
  });
  test('All eight comparison/outcome/standardization audits match independent Python source aggregation', () {
    for (final comparison in ['experimental', 'psid']) {
      for (final outcome in experimentOutcomes) {
        for (final adjust in [false, true]) {
          same(
            a.observational(
              comparison: comparison,
              outcome: outcome,
              adjust: adjust,
            ),
            a.data['observational'][comparison][outcome][adjust
                ? 'True'
                : 'False'],
          );
        }
      }
    }
    expect(
      a.observational(adjust: true)['shown_gap'],
      closeTo(-5413.950688710562, 1e-8),
    );
    expect(a.observational()['raw_gap'], lessThan(0));
    expect(
      a.observational(comparison: 'experimental')['raw_gap'],
      greaterThan(0),
    );
  });
  test('Unrepresented positive-weight strata block adjusted gap rather than silently renormalize', () {
    final data = clone(a.data);
    data['cohorts']['psid'] = (data['cohorts']['psid'] as List)
        .where((r) => r['re74'] > 0)
        .toList();
    final r = ExperimentAssets(data).observational(adjust: true);
    expect(r['empirical_overlap'], isFalse);
    expect(r['adjusted_gap'], isNull);
    expect(r['shown_gap'], isNull);
    expect((r['strata'] as List).first['control'], 0);
  });
  test('Holm ordering,ties,empty families and invalid p-values retain correct outcome identity', () {
    same(
      experimentHolm(List<double>.from(a.data['multiplicity']['raw'])),
      a.data['multiplicity']['holm'],
    );
    expect(experimentHolm([.5, .01, .01]), [.5, .03, .03]);
    expect(experimentHolm([0, 1]), [0, 1]);
    expect(experimentHolm([]), isEmpty);
    expect(() => experimentHolm([double.nan]), throwsArgumentError);
    expect(() => experimentHolm([1.1]), throwsArgumentError);
  });
  test(
    'Statistical boundaries reject unsupported inputs and no-variance cases',
    () {
      expect(() => experimentSummary([1]), throwsArgumentError);
      expect(
        () => experimentSummary([1, double.infinity]),
        throwsArgumentError,
      );
      expect(
        () => experimentWelch([1, 1], [1, 1], critical: 1.96, confidence: .95),
        throwsArgumentError,
      );
      expect(
        () => experimentWelch([1, 2], [2, 3], critical: 0, confidence: .95),
        throwsArgumentError,
      );
      expect(experimentSmd([1, 1], [1, 1]), isNull);
      expect(experimentNormalCdf(0), closeTo(.5, 1e-8));
      expect(experimentNormalCdf(1.959963984540054), closeTo(.975, 1e-7));
      expect(experimentNormalCdf(-4), closeTo(.0000316712418331, 1e-7));
    },
  );
}
