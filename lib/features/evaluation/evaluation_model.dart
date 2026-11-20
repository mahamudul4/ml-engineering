import 'dart:math';

enum FoldPolicy { interleaved, grouped, forward }

/// Twelve ordered illustrative records; every adjacent pair shares a group.
class FoldPlan {
  final List<int> train, validation, unused;
  FoldPlan._(List<int> training, List<int> heldout)
    : train = List.unmodifiable(training),
      validation = List.unmodifiable(heldout),
      unused = List.unmodifiable([
        for (var i = 0; i < 12; i++)
          if (!training.contains(i) && !heldout.contains(i)) i,
      ]);

  factory FoldPlan.make(FoldPolicy policy, int fold, {int gap = 0}) {
    if (fold < 0 || fold > 2 || gap < 0 || gap > 1) {
      throw ArgumentError('Three folds and gap 0 or 1 are supported.');
    }
    final validation = switch (policy) {
      FoldPolicy.interleaved => [for (var i = fold; i < 12; i += 3) i],
      FoldPolicy.grouped => [
        for (var i = 0; i < 12; i++)
          if ((i ~/ 2) % 3 == fold) i,
      ],
      FoldPolicy.forward => [
        for (var i = 3 + fold * 3; i < 6 + fold * 3; i++) i,
      ],
    };
    final training = [
      for (var i = 0; i < 12; i++)
        if (policy == FoldPolicy.forward
            ? i < validation.first - gap
            : !validation.contains(i))
          i,
    ];
    return FoldPlan._(training, validation);
  }

  Set<int> get sharedGroups => train
      .map((i) => i ~/ 2)
      .toSet()
      .intersection(validation.map((i) => i ~/ 2).toSet());
  bool get trainsOnFuture => train.any((i) => i > validation.first);
}

class PairedBootstrap {
  final double estimate, lower, upper;
  final List<double> draws;
  PairedBootstrap._(this.estimate, this.lower, this.upper, List<double> values)
    : draws = List.unmodifiable(values);

  /// Same row is selected for both fixed models. Positive = B has lower loss.
  factory PairedBootstrap.lossDifference(
    List<double> a,
    List<double> b, {
    int repetitions = 1000,
    double confidence = .95,
    int seed = 42,
  }) {
    if (a.length != b.length ||
        a.length < 2 ||
        repetitions < 100 ||
        repetitions > 5000 ||
        !confidence.isFinite ||
        confidence <= 0 ||
        confidence >= 1 ||
        [...a, ...b].any((x) => !x.isFinite || x < 0)) {
      throw ArgumentError(
        'Use paired finite losses, n >= 2, and valid settings.',
      );
    }
    final differences = [for (var i = 0; i < a.length; i++) a[i] - b[i]];
    if (differences.any((x) => !x.isFinite)) {
      throw ArgumentError('Loss differences must be finite.');
    }
    double average(Iterable<double> xs) =>
        xs.fold(0.0, (sum, x) => sum + x / a.length);
    final random = Random(seed);
    final draws = [
      for (var r = 0; r < repetitions; r++)
        average([
          for (var i = 0; i < a.length; i++)
            differences[random.nextInt(a.length)],
        ]),
    ]..sort();
    double quantile(double p) {
      final position = (draws.length - 1) * p;
      final lo = position.floor(), hi = position.ceil();
      final weight = position - lo;
      return draws[lo] * (1 - weight) + draws[hi] * weight;
    }

    final alpha = (1 - confidence) / 2;
    return PairedBootstrap._(
      average(differences),
      quantile(alpha),
      quantile(1 - alpha),
      draws,
    );
  }
}
