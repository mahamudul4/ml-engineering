import 'dart:math';

enum IntervalMethod { wilson, wald }

enum ConfidenceLevel { ninety, ninetyFive, ninetyNine }

extension ConfidenceSettings on ConfidenceLevel {
  String get label => switch (this) {
    ConfidenceLevel.ninety => '90%',
    ConfidenceLevel.ninetyFive => '95%',
    ConfidenceLevel.ninetyNine => '99%',
  };
  double get z => switch (this) {
    ConfidenceLevel.ninety => 1.6448536269514722,
    ConfidenceLevel.ninetyFive => 1.959963984540054,
    ConfidenceLevel.ninetyNine => 2.5758293035489004,
  };
}

class FlagProbabilities {
  final double truePositive, falsePositive, falseNegative, trueNegative;
  FlagProbabilities._(
    this.truePositive,
    this.falsePositive,
    this.falseNegative,
    this.trueNegative,
  );
  factory FlagProbabilities.compute({
    required double prevalence,
    required double sensitivity,
    required double falsePositiveRate,
  }) {
    if ([
      prevalence,
      sensitivity,
      falsePositiveRate,
    ].any((v) => !v.isFinite || v < 0 || v > 1)) {
      throw ArgumentError('Probabilities must be finite and in [0,1].');
    }
    return FlagProbabilities._(
      prevalence * sensitivity,
      (1 - prevalence) * falsePositiveRate,
      prevalence * (1 - sensitivity),
      (1 - prevalence) * (1 - falsePositiveRate),
    );
  }
  double get flagProbability => truePositive + falsePositive;
  double? get eventGivenFlag =>
      flagProbability == 0 ? null : truePositive / flagProbability;
}

class ProportionInterval {
  final double lower, upper;
  ProportionInterval._(this.lower, this.upper);
  factory ProportionInterval.compute(
    int successes,
    int n, {
    ConfidenceLevel confidence = ConfidenceLevel.ninetyFive,
    IntervalMethod method = IntervalMethod.wilson,
  }) {
    if (n < 1 || n > 1000000 || successes < 0 || successes > n) {
      throw ArgumentError('Need 0 <= successes <= n and positive bounded n.');
    }
    final p = successes / n, z = confidence.z;
    if (method == IntervalMethod.wald) {
      final half = z * sqrt(p * (1 - p) / n);
      return ProportionInterval._(
        (p - half).clamp(0.0, 1.0),
        (p + half).clamp(0.0, 1.0),
      );
    }
    final denominator = 1 + z * z / n;
    final center = (p + z * z / (2 * n)) / denominator;
    final half = z / denominator * sqrt(p * (1 - p) / n + z * z / (4 * n * n));
    return ProportionInterval._(
      successes == 0 ? 0 : (center - half).clamp(0.0, 1.0),
      successes == n ? 1 : (center + half).clamp(0.0, 1.0),
    );
  }
  bool contains(double p) => p >= lower && p <= upper;
}

class BinomialCoverage {
  final List<double> probabilities;
  final List<ProportionInterval> intervals;
  final double coverage;
  BinomialCoverage._(
    List<double> probabilities,
    List<ProportionInterval> intervals,
    this.coverage,
  ) : probabilities = List.unmodifiable(probabilities),
      intervals = List.unmodifiable(intervals);
  factory BinomialCoverage.compute(
    int n,
    double p, {
    ConfidenceLevel confidence = ConfidenceLevel.ninetyFive,
    IntervalMethod method = IntervalMethod.wilson,
  }) {
    if (n < 1 || n > 200 || !p.isFinite || p < 0 || p > 1) {
      throw ArgumentError('Enumerate n in 1..200 and probability in [0,1].');
    }
    final logFactorial = [0.0];
    for (var i = 1; i <= n; i++) {
      logFactorial.add(logFactorial.last + log(i));
    }
    final masses = <double>[];
    for (var k = 0; k <= n; k++) {
      if (p == 0) {
        masses.add(k == 0 ? 1 : 0);
      } else if (p == 1) {
        masses.add(k == n ? 1 : 0);
      } else {
        masses.add(
          exp(
            logFactorial[n] -
                logFactorial[k] -
                logFactorial[n - k] +
                k * log(p) +
                (n - k) * log(1 - p),
          ),
        );
      }
    }
    final total = masses.fold(0.0, (a, b) => a + b);
    final probabilities = [for (final mass in masses) mass / total];
    final intervals = [
      for (var k = 0; k <= n; k++)
        ProportionInterval.compute(
          k,
          n,
          confidence: confidence,
          method: method,
        ),
    ];
    var covered = 0.0;
    for (var k = 0; k <= n; k++) {
      if (intervals[k].contains(p)) covered += probabilities[k];
    }
    return BinomialCoverage._(
      probabilities,
      intervals,
      covered.clamp(0.0, 1.0),
    );
  }
}
