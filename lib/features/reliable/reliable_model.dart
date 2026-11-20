import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

List<double> vector(dynamic x) =>
    List<double>.unmodifiable((x as List).map((v) => (v as num).toDouble()));
List<List<double>> matrix(dynamic x) =>
    List<List<double>>.unmodifiable((x as List).map(vector));
void finite(List<double> x) {
  if (x.isEmpty || x.any((v) => !v.isFinite)) {
    throw ArgumentError('Nonempty finite vector');
  }
}

class OptimizerReplay {
  final List<List<double>> values;
  OptimizerReplay._(List<List<double>> rows)
    : values = List.unmodifiable(rows.map((r) => List<double>.unmodifiable(r)));
  factory OptimizerReplay.compute(
    List<double> initial,
    List<double> gradient,
    String kind, {
    int steps = 3,
    double lr = .01,
    double decay = .1,
  }) {
    finite(initial);
    finite(gradient);
    if (initial.length != gradient.length ||
        steps < 0 ||
        steps > 100 ||
        !['sgd', 'momentum', 'adam', 'adamw'].contains(kind) ||
        !lr.isFinite ||
        lr <= 0 ||
        !decay.isFinite ||
        decay < 0) {
      throw ArgumentError('Declared finite optimizer replay');
    }
    final p = [...initial],
        m = List.filled(pLength(initial), 0.0),
        v = List.filled(pLength(initial), 0.0),
        rows = <List<double>>[
          [...initial],
        ];
    for (var t = 1; t <= steps; t++) {
      for (var i = 0; i < p.length; i++) {
        final g = gradient[i] + (kind == 'adamw' ? 0 : decay * p[i]);
        if (kind == 'sgd') {
          p[i] -= lr * g;
        } else if (kind == 'momentum') {
          m[i] = .9 * m[i] + g;
          p[i] -= lr * m[i];
        } else {
          m[i] = .9 * m[i] + .1 * g;
          v[i] = .999 * v[i] + .001 * g * g;
          if (kind == 'adamw') p[i] *= 1 - lr * decay;
          p[i] -=
              lr *
              (m[i] / (1 - pow(.9, t))) /
              (sqrt(v[i] / (1 - pow(.999, t))) + 1e-8);
        }
      }
      finite(p);
      rows.add([...p]);
    }
    return OptimizerReplay._(rows);
  }
  static int pLength(List<double> p) => p.length;
}

class NormalizedBatch {
  final List<List<double>> values;
  final List<double> mean, variance;
  NormalizedBatch._(List<List<double>> x, List<double> m, List<double> v)
    : values = List.unmodifiable(x.map((r) => List<double>.unmodifiable(r))),
      mean = List.unmodifiable(m),
      variance = List.unmodifiable(v);
  factory NormalizedBatch.compute(
    List<List<double>> X,
    String mode, {
    List<double>? runningMean,
    List<double>? runningVariance,
    double eps = 1e-5,
  }) {
    if (X.isEmpty ||
        X.first.isEmpty ||
        !['batch_train', 'batch_eval', 'layer'].contains(mode) ||
        !eps.isFinite ||
        eps <= 0) {
      throw ArgumentError('Normalization contract');
    }
    final d = X.first.length;
    for (final r in X) {
      finite(r);
      if (r.length != d) throw ArgumentError('Rectangular values');
    }
    if (mode == 'batch_train' && X.length < 2) {
      throw ArgumentError('BatchNorm training needs multiple values/channel');
    }
    final means = <double>[], variances = <double>[];
    if (mode == 'layer') {
      for (final r in X) {
        final m = r.reduce((a, b) => a + b) / d;
        means.add(m);
        variances.add(r.fold(0.0, (s, v) => s + (v - m) * (v - m)) / d);
      }
    } else if (mode == 'batch_train') {
      for (var j = 0; j < d; j++) {
        final m = X.fold(0.0, (s, r) => s + r[j]) / X.length;
        means.add(m);
        variances.add(
          X.fold(0.0, (s, r) => s + (r[j] - m) * (r[j] - m)) / X.length,
        );
      }
    } else {
      if (runningMean == null ||
          runningVariance == null ||
          runningMean.length != d ||
          runningVariance.length != d) {
        throw ArgumentError('Running channel statistics');
      }
      finite(runningMean);
      finite(runningVariance);
      if (runningVariance.any((v) => v < 0)) {
        throw ArgumentError('Nonnegative variance');
      }
      means.addAll(runningMean);
      variances.addAll(runningVariance);
    }
    final result = [
      for (var i = 0; i < X.length; i++)
        [
          for (var j = 0; j < d; j++)
            (X[i][j] - means[mode == 'layer' ? i : j]) /
                sqrt(variances[mode == 'layer' ? i : j] + eps),
        ],
    ];
    finite([...means, ...variances, ...result.expand((r) => r)]);
    return NormalizedBatch._(result, means, variances);
  }
}

class ReliableEpoch {
  final int epoch;
  final double train, validation, nextLr;
  ReliableEpoch.fromJson(Map<String, dynamic> j)
    : epoch = j['epoch'],
      train = (j['train_bce'] as num).toDouble(),
      validation = (j['validation_bce'] as num).toDouble(),
      nextLr = (j['next_lr'] as num).toDouble() {
    finite([train, validation, nextLr]);
    if (epoch < 0 || train < 0 || validation < 0 || nextLr <= 0) {
      throw const FormatException('Epoch evidence');
    }
  }
}

class ReliableAssets {
  final List<double> initial, gradient, runningMean, runningVariance;
  final List<List<double>> activations;
  final List<int> sourceRows;
  final List<ReliableEpoch> continuous, resumed, weightsOnly;
  final double resumeError, weightsOnlyError;
  ReliableAssets.fromJson(Map<String, dynamic> j)
    : initial = vector(j['optimizers']['initial']),
      gradient = vector(j['optimizers']['gradient']),
      activations = matrix(j['normalization']['input']),
      runningMean = vector(j['normalization']['running_mean']),
      runningVariance = vector(j['normalization']['running_var']),
      sourceRows = List.unmodifiable(List<int>.from(j['source_rows_1based'])),
      continuous = List.unmodifiable(
        (j['continuous_history'] as List).map((v) => ReliableEpoch.fromJson(v)),
      ),
      resumed = List.unmodifiable(
        (j['resumed_history'] as List).map((v) => ReliableEpoch.fromJson(v)),
      ),
      weightsOnly = List.unmodifiable(
        (j['weights_only_history'] as List).map(
          (v) => ReliableEpoch.fromJson(v),
        ),
      ),
      resumeError = (j['resume_parameter_max_abs'] as num).toDouble(),
      weightsOnlyError = (j['weights_only_parameter_max_abs'] as num)
          .toDouble() {
    for (final v in [
      initial,
      gradient,
      runningMean,
      runningVariance,
      ...activations,
    ]) {
      finite(v);
    }
    final c = j['config'];
    const features = [
      'fixed acidity',
      'volatile acidity',
      'citric acid',
      'residual sugar',
      'chlorides',
      'free sulfur dioxide',
      'total sulfur dioxide',
      'density',
      'pH',
      'sulphates',
      'alcohol',
    ];
    final sourceMean = vector(j['mean']), sourceScale = vector(j['scale']);
    finite(sourceMean);
    finite(sourceScale);
    if (jsonEncode(j['feature_names']) != jsonEncode(features) ||
        sourceMean.length != 11 ||
        sourceScale.length != 11 ||
        sourceScale.any((v) => v <= 0) ||
        j['optimizers']['lr'] != .01 ||
        j['optimizers']['decay'] != .1 ||
        j['optimizers']['beta1'] != .9 ||
        j['optimizers']['beta2'] != .999 ||
        j['optimizers']['eps'] != 1e-8 ||
        j['normalization']['eps'] != 1e-5 ||
        j['normalization']['momentum'] != .1) {
      throw const FormatException('Source schema or numerical recipe mismatch');
    }
    if (initial.length != 3 ||
        gradient.length != 3 ||
        activations.length != 8 ||
        activations.any((r) => r.length != 4) ||
        runningMean.length != 4 ||
        runningVariance.length != 4 ||
        runningVariance.any((v) => v < 0) ||
        sourceRows.length != 8 ||
        sourceRows.toSet().length != 8 ||
        sourceRows.any((r) => r < 1 || r > 1599) ||
        j['inner_train_rows'] != 776 ||
        j['inner_validation_rows'] != 190 ||
        j['inner_train_groups'] != 652 ||
        j['inner_validation_groups'] != 163 ||
        c['epochs'] != 40 ||
        c['resume_epoch'] != 20 ||
        c['seed'] != 17 ||
        c['batch_size'] != 64 ||
        c['learning_rate'] != .01 ||
        c['weight_decay'] != .01 ||
        c['dropout'] != .2 ||
        c['clip_norm'] != 1 ||
        c['step_size'] != 20 ||
        c['gamma'] != .5 ||
        resumeError != 0 ||
        !weightsOnlyError.isFinite ||
        weightsOnlyError <= 0) {
      throw const FormatException('Training-state evidence contract');
    }
    for (final history in [continuous, resumed, weightsOnly]) {
      if (history.length != 41) {
        throw const FormatException('Complete epoch history');
      }
      for (var i = 0; i < 41; i++) {
        if (history[i].epoch != i) {
          throw const FormatException('Ordered epoch history');
        }
        if (i <= 20 &&
            (history[i].train != continuous[i].train ||
                history[i].validation != continuous[i].validation)) {
          throw const FormatException('Shared prefix mismatch');
        }
      }
    }
    for (var i = 0; i < 41; i++) {
      if (continuous[i].train != resumed[i].train ||
          continuous[i].validation != resumed[i].validation ||
          continuous[i].nextLr != resumed[i].nextLr) {
        throw const FormatException('Exact resume reference mismatch');
      }
    }
    final mean = NormalizedBatch.compute(activations, 'batch_train');
    for (var k = 0; k < 4; k++) {
      if ((runningMean[k] - .1 * mean.mean[k]).abs() > 1e-10 ||
          (runningVariance[k] - (.9 + .1 * mean.variance[k] * 8 / 7)).abs() >
              1e-10) {
        throw const FormatException(
          'One-batch BatchNorm running-stat contract',
        );
      }
    }
  }
  static ReliableAssets? _cached;
  static Future<ReliableAssets> load() async {
    if (_cached != null) return _cached!;
    final parsed = ReliableAssets.fromJson(
      jsonDecode(
        await rootBundle.loadString(
          'assets/datasets/wine_quality/reliable_lab.json',
        ),
      ),
    );
    _cached = parsed;
    return parsed;
  }
}
