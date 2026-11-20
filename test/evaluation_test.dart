import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/features/evaluation/evaluation_model.dart';

void main() {
  test('row and group folds partition validation coverage exactly once', () {
    for (final policy in [FoldPolicy.interleaved, FoldPolicy.grouped]) {
      final coverage = <int>[];
      for (var fold = 0; fold < 3; fold++) {
        final plan = FoldPlan.make(policy, fold);
        expect(
          plan.train.toSet().intersection(plan.validation.toSet()),
          isEmpty,
        );
        expect(plan.train.length, 8);
        coverage.addAll(plan.validation);
        expect(plan.unused, isEmpty);
      }
      expect(coverage..sort(), List.generate(12, (i) => i));
    }
  });
  test(
    'group-disjoint and chronological constraints answer different questions',
    () {
      final rows = FoldPlan.make(FoldPolicy.interleaved, 0);
      final groups = FoldPlan.make(FoldPolicy.grouped, 0);
      final time = FoldPlan.make(FoldPolicy.forward, 0);
      expect(rows.sharedGroups.length, 4);
      expect(groups.sharedGroups, isEmpty);
      expect(groups.trainsOnFuture, isTrue);
      expect(time.trainsOnFuture, isFalse);
      expect(time.sharedGroups, {1});
      final gap = FoldPlan.make(FoldPolicy.forward, 0, gap: 1);
      expect(gap.train, [0, 1]);
      expect(gap.validation, [3, 4, 5]);
      expect(gap.unused, contains(2));
      for (var fold = 0; fold < 3; fold++) {
        final p = FoldPlan.make(FoldPolicy.forward, fold, gap: 1);
        expect(p.train.last, lessThan(p.validation.first - 1));
      }
      expect(() => gap.train.add(11), throwsUnsupportedError);
      expect(() => FoldPlan.make(FoldPolicy.forward, 3), throwsArgumentError);
      expect(
        () => FoldPlan.make(FoldPolicy.forward, 0, gap: 2),
        throwsArgumentError,
      );
    },
  );
  const a = [.4, .2, .5, .8, .3, .6, .4, .7];
  const b = [.2, .3, .4, .5, .5, .5, .4, .5];
  test('paired bootstrap preserves exact identical-model zero uncertainty', () {
    final result = PairedBootstrap.lossDifference(a, a);
    expect(result.estimate, 0);
    expect(result.lower, 0);
    expect(result.upper, 0);
    expect(result.draws.toSet(), {0.0});
    expect(() => result.draws.add(1), throwsUnsupportedError);
  });
  test('paired gain, reproducibility and confidence nesting hold', () {
    final result = PairedBootstrap.lossDifference(a, b);
    final repeat = PairedBootstrap.lossDifference(a, b);
    final narrower = PairedBootstrap.lossDifference(a, b, confidence: .8);
    expect(result.estimate, closeTo(.075, 1e-12));
    expect(result.lower, lessThan(0));
    expect(result.upper, greaterThan(result.estimate));
    expect(result.draws, repeat.draws);
    expect(result.lower, lessThanOrEqualTo(narrower.lower));
    expect(result.upper, greaterThanOrEqualTo(narrower.upper));
    expect(a, [.4, .2, .5, .8, .3, .6, .4, .7]);
  });
  test('constant paired improvement is a point mass, including large finite losses', () {
    final result = PairedBootstrap.lossDifference(
      [.5, .5, .5],
      [.25, .25, .25],
    );
    expect(result.estimate, .25);
    expect(result.lower, .25);
    expect(result.upper, .25);
    final large = PairedBootstrap.lossDifference([1e308, 0], [0, 1e308]);
    expect(large.estimate, 0);
    expect(large.lower.isFinite, isTrue);
    expect(large.upper.isFinite, isTrue);
  });
  test('bootstrap rejects invalid or unpaired data and invalid simulation settings', () {
    for (final pair in <(List<double>, List<double>)>[
      ([], []),
      ([1], [1]),
      ([1, 2], [1]),
      ([double.nan, 1], [1, 2]),
      ([1, double.infinity], [1, 2]),
      ([-1, 0], [0, 0]),
    ]) {
      expect(
        () => PairedBootstrap.lossDifference(pair.$1, pair.$2),
        throwsArgumentError,
      );
    }
    expect(
      () => PairedBootstrap.lossDifference(a, b, repetitions: 99),
      throwsArgumentError,
    );
    expect(
      () => PairedBootstrap.lossDifference(a, b, repetitions: 5001),
      throwsArgumentError,
    );
    for (final confidence in [0.0, 1.0, double.nan]) {
      expect(
        () => PairedBootstrap.lossDifference(a, b, confidence: confidence),
        throwsArgumentError,
      );
    }
  });
}
