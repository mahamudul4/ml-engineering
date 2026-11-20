import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/features/regression/advanced_regression_model.dart';

void main() {
  test('metrics match worked example, including negative and undefined R2', () {
    final m = RegressionMetrics.evaluate([3, 6, 9], [2, 4, 8]);
    expect(m.mae, closeTo(4 / 3, 1e-12));
    expect(m.mse, 2);
    expect(m.rmse, closeTo(math.sqrt(2), 1e-12));
    expect(m.r2, closeTo(2 / 3, 1e-12));
    expect(RegressionMetrics.evaluate([1, 2], [10, 10]).r2, lessThan(0));
    expect(RegressionMetrics.evaluate([3, 3], [3, 3]).r2, isNull);
    expect(() => RegressionMetrics.evaluate([], []), throwsArgumentError);
    expect(
      () => RegressionMetrics.evaluate([1], [double.nan]),
      throwsArgumentError,
    );
  });
  test('multiple feature prediction checks dimensions and feature order', () {
    expect(MultipleRegression.predict([1000, 2], [.04, 5], 8), 58);
    expect(MultipleRegression.predict([1500, 3], [.04, 5], 8), 83);
    expect(
      () => MultipleRegression.predict([1], [1, 2], 0),
      throwsArgumentError,
    );
  });
  test('standardized gradient descent converges to the OLS solution', () {
    final run = OptimizationRun();
    final start = run.loss;
    for (var i = 0; i < 200; i++) {
      expect(run.step(), isTrue);
    }
    expect(run.loss, lessThan(start));
    expect(run.loss, closeTo(2 / 15, 1e-8));
    expect(run.rawParameters.$1, closeTo(.012, 1e-8));
    expect(run.rawParameters.$2, closeTo(.8, 1e-6));
    expect(run.history.length, 201);
  });
  test('large raw-input updates stop safely; normalized gradients match finite differences', () {
    final unstable = OptimizationRun(standardized: false);
    for (var i = 0; i < 25; i++) {
      unstable.step();
    }
    expect(unstable.stopped, isTrue);
    expect(unstable.loss.isFinite, isTrue);
    expect(unstable.step(), isFalse);
    final run = OptimizationRun();
    final xs = run.inputs;
    double lossAt(double w, double b) => RegressionMetrics.evaluate(
      OptimizationRun.targets,
      xs.map((x) => w * x + b).toList(),
    ).mse;
    const epsilon = 1e-5;
    expect(
      run.gradient.$1,
      closeTo((lossAt(epsilon, 0) - lossAt(-epsilon, 0)) / (2 * epsilon), 1e-7),
    );
    expect(
      run.gradient.$2,
      closeTo((lossAt(0, epsilon) - lossAt(0, -epsilon)) / (2 * epsilon), 1e-7),
    );
  });
}
