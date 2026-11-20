import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/features/statistics/statistics_model.dart';

void main() {
  test(
    'Bayes normalizes joint masses and distinguishes posterior from TPR',
    () {
      final r = FlagProbabilities.compute(
        prevalence: .01,
        sensitivity: .9,
        falsePositiveRate: .05,
      );
      expect(r.eventGivenFlag, closeTo(2 / 13, 1e-14));
      expect(r.flagProbability, closeTo(.0585, 1e-14));
      expect(
        r.truePositive + r.falsePositive + r.falseNegative + r.trueNegative,
        closeTo(1, 1e-14),
      );
      expect(r.eventGivenFlag, isNot(closeTo(.9, .01)));
    },
  );
  test('Bayes handles no flags, zero base rate and perfect specificity', () {
    FlagProbabilities compute(double p, double t, double f) =>
        FlagProbabilities.compute(
          prevalence: p,
          sensitivity: t,
          falsePositiveRate: f,
        );
    expect(compute(.01, .9, 0).eventGivenFlag, 1);
    expect(compute(0, .9, .05).eventGivenFlag, 0);
    expect(compute(.01, 0, 0).eventGivenFlag, isNull);
    for (final p in [double.nan, double.infinity, -.1, 1.1]) {
      expect(() => compute(p, .9, .05), throwsArgumentError);
      expect(() => compute(.1, p, .05), throwsArgumentError);
      expect(() => compute(.1, .9, p), throwsArgumentError);
    }
  });
  test('Wilson agrees with independent score reference at both boundaries', () {
    final zero = ProportionInterval.compute(0, 10);
    final all = ProportionInterval.compute(10, 10);
    expect(zero.lower, 0);
    expect(zero.upper, closeTo(.2775327998628892, 1e-12));
    expect(all.upper, 1);
    expect(all.lower, closeTo(1 - zero.upper, 1e-12));
    final middle = ProportionInterval.compute(5, 10);
    expect(middle.lower, closeTo(.236593090512564, 1e-12));
    expect(middle.upper, closeTo(.763406909487436, 1e-12));
  });
  test(
    'Higher confidence nests intervals and Wald remains degenerate at zero',
    () {
      final lower = ProportionInterval.compute(
        4,
        20,
        confidence: ConfidenceLevel.ninety,
      );
      final higher = ProportionInterval.compute(
        4,
        20,
        confidence: ConfidenceLevel.ninetyNine,
      );
      expect(higher.lower, lessThan(lower.lower));
      expect(higher.upper, greaterThan(lower.upper));
      final zero = ProportionInterval.compute(
        0,
        20,
        method: IntervalMethod.wald,
      );
      expect(zero.lower, 0);
      expect(zero.upper, 0);
      expect(
        zero.contains(1e-14),
        isFalse,
        reason: 'No tolerance may create spurious boundary coverage',
      );
      for (var k = 0; k <= 20; k++) {
        final ci = ProportionInterval.compute(
          k,
          20,
          method: IntervalMethod.wald,
        );
        expect(ci.lower, inInclusiveRange(0, 1));
        expect(ci.upper, inInclusiveRange(ci.lower, 1));
      }
    },
  );
  test(
    'Exact coverage uses all binomial probabilities with immutable results',
    () {
      final r = BinomialCoverage.compute(20, .2);
      expect(r.probabilities.length, 21);
      expect(r.probabilities.fold(0.0, (a, b) => a + b), closeTo(1, 1e-14));
      expect(r.probabilities[0], closeTo(.011529215046068483, 1e-14));
      // Independent SciPy PMF + Wilson inversion sum, not Monte Carlo.
      expect(r.coverage, closeTo(.9563281218730577, 1e-12));
      final wald = BinomialCoverage.compute(
        20,
        .2,
        method: IntervalMethod.wald,
      );
      expect(wald.coverage, closeTo(.9208429234028657, 1e-12));
      expect(() => r.probabilities[0] = 0, throwsUnsupportedError);
      expect(() => r.intervals.clear(), throwsUnsupportedError);
    },
  );
  test('Binomial symmetry and endpoint point masses preserve coverage', () {
    for (final method in IntervalMethod.values) {
      final a = BinomialCoverage.compute(50, .17, method: method);
      final b = BinomialCoverage.compute(50, .83, method: method);
      expect(a.coverage, closeTo(b.coverage, 1e-12));
      for (var k = 0; k <= 50; k++) {
        expect(a.probabilities[k], closeTo(b.probabilities[50 - k], 1e-12));
      }
      expect(BinomialCoverage.compute(20, 0, method: method).coverage, 1);
      expect(BinomialCoverage.compute(20, 1, method: method).coverage, 1);
    }
    expect(
      BinomialCoverage.compute(20, 1e-14, method: IntervalMethod.wald).coverage,
      lessThan(1e-10),
    );
  });
  test('Invalid interval and enumeration sizes fail explicitly', () {
    expect(() => ProportionInterval.compute(1, 0), throwsArgumentError);
    expect(() => ProportionInterval.compute(-1, 10), throwsArgumentError);
    expect(() => ProportionInterval.compute(11, 10), throwsArgumentError);
    expect(() => BinomialCoverage.compute(201, .2), throwsArgumentError);
    expect(() => BinomialCoverage.compute(20, double.nan), throwsArgumentError);
    expect(() => BinomialCoverage.compute(20, -1), throwsArgumentError);
  });
}
