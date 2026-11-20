import 'dart:math' as math;

import 'regression_model.dart';

class RegressionMetrics {
  final double mae, mse, rmse;
  final double? r2;
  RegressionMetrics._(this.mae, this.mse, this.rmse, this.r2);
  factory RegressionMetrics.evaluate(
    List<double> actual,
    List<double> predicted,
  ) {
    if (actual.isEmpty ||
        actual.length != predicted.length ||
        [...actual, ...predicted].any((v) => !v.isFinite)) {
      throw ArgumentError('Equal, non-empty, finite inputs required');
    }
    final mean = actual.reduce((a, b) => a + b) / actual.length;
    double absolute = 0, sse = 0, sst = 0;
    for (var i = 0; i < actual.length; i++) {
      final error = predicted[i] - actual[i];
      absolute += error.abs();
      sse += error * error;
      sst += (actual[i] - mean) * (actual[i] - mean);
    }
    final mse = sse / actual.length;
    return RegressionMetrics._(
      absolute / actual.length,
      mse,
      math.sqrt(mse),
      sst == 0 ? null : 1 - sse / sst,
    );
  }
}

class MultipleRegression {
  static double predict(
    List<double> features,
    List<double> weights,
    double bias,
  ) {
    if (features.length != weights.length ||
        !bias.isFinite ||
        [...features, ...weights].any((v) => !v.isFinite)) {
      throw ArgumentError('Finite values and matching dimensions required');
    }
    var value = bias;
    for (var j = 0; j < features.length; j++) {
      value += features[j] * weights[j];
    }
    return value;
  }
}

/// Deterministic batch-gradient experiment on six synthetic training examples.
class OptimizationRun {
  static final rawX = RegressionModel.points.map((p) => p.$1 * 100).toList();
  static final targets = RegressionModel.points.map((p) => p.$2).toList();
  static final mean = rawX.reduce((a, b) => a + b) / rawX.length;
  static final scale = math.sqrt(
    rawX.fold<double>(0, (s, x) => s + (x - mean) * (x - mean)) / rawX.length,
  );
  final bool standardized;
  final double learningRate;
  final List<double> history = [];
  double weight = 0, bias = 0;
  bool stopped = false;
  OptimizationRun({this.standardized = true, this.learningRate = .05}) {
    if (!learningRate.isFinite || learningRate <= 0) {
      throw ArgumentError('Positive finite learning rate required');
    }
    history.add(loss);
  }
  List<double> get inputs =>
      standardized ? rawX.map((x) => (x - mean) / scale).toList() : rawX;
  int get steps => history.length - 1;
  double _loss(double w, double b) => RegressionMetrics.evaluate(
    targets,
    inputs.map((x) => w * x + b).toList(),
  ).mse;
  double get loss => _loss(weight, bias);
  (double, double) get gradient {
    var dw = 0.0, db = 0.0;
    final xs = inputs;
    for (var i = 0; i < xs.length; i++) {
      final e = weight * xs[i] + bias - targets[i];
      dw += 2 * xs[i] * e / xs.length;
      db += 2 * e / xs.length;
    }
    return (dw, db);
  }

  /// Stop before committing an unstable/non-finite update.
  bool step() {
    if (stopped || steps >= 1000) return false;
    final g = gradient;
    final w = weight - learningRate * g.$1, b = bias - learningRate * g.$2;
    if (!w.isFinite || !b.isFinite) {
      stopped = true;
      return false;
    }
    final next = _loss(w, b);
    if (!next.isFinite || next > 1e10) {
      stopped = true;
      return false;
    }
    weight = w;
    bias = b;
    history.add(next);
    return true;
  }

  (double, double) get rawParameters => standardized
      ? (weight / scale, bias - weight * mean / scale)
      : (weight, bias);
}
