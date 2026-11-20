import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

List<double> _v(dynamic x) =>
    List.unmodifiable((x as List).map((v) => (v as num).toDouble()));
List<List<double>> _m(dynamic x) => List.unmodifiable((x as List).map(_v));
void _finite(List<double> x) {
  if (x.isEmpty || x.any((v) => !v.isFinite)) {
    throw ArgumentError('Nonempty finite values');
  }
}

double sigmoid(double z) {
  if (z >= 0) return 1 / (1 + exp(-z));
  final v = exp(z);
  return v / (1 + v);
}

double _tanh(double z) => 2 * sigmoid(2 * z) - 1;
double _dot(List<double> a, List<double> b) =>
    List.generate(a.length, (i) => a[i] * b[i]).fold(0.0, (s, v) => s + v);

class NeuralParameters {
  final List<List<double>> w1;
  final List<double> b1, w2;
  final double b2;
  NeuralParameters.fromJson(Map<String, dynamic> j)
    : w1 = _m(j['w1']),
      b1 = _v(j['b1']),
      w2 = _v(j['w2']),
      b2 = (j['b2'] as num).toDouble() {
    if (w1.length != 4 ||
        w1.any((r) => r.length != 11) ||
        b1.length != 4 ||
        w2.length != 4 ||
        !b2.isFinite) {
      throw const FormatException('11 ->4 ->1 parameters');
    }
    for (final r in [...w1, b1, w2]) {
      _finite(r);
    }
  }
}

class NeuralTrace {
  final List<double> preactivation, hidden, gate, contributions;
  final double logit, probability, loss;
  NeuralTrace._(
    List<double> z,
    List<double> h,
    List<double> g,
    List<double> c,
    this.logit,
    this.probability,
    this.loss,
  ) : preactivation = List.unmodifiable(z),
      hidden = List.unmodifiable(h),
      gate = List.unmodifiable(g),
      contributions = List.unmodifiable(c);
  factory NeuralTrace.compute(
    List<double> x,
    double y,
    NeuralParameters p, {
    bool tanh = false,
  }) {
    _finite(x);
    if (x.length != 11 || (y != 0 && y != 1)) {
      throw ArgumentError('11 features and binary label');
    }
    final z = [for (var j = 0; j < 4; j++) _dot(x, p.w1[j]) + p.b1[j]];
    _finite(z);
    final h = [for (final v in z) tanh ? _tanh(v) : max(0.0, v)],
        g = [
          for (var j = 0; j < 4; j++)
            tanh ? 1 - h[j] * h[j] : (z[j] > 0 ? 1.0 : 0.0),
        ];
    final contributions = [for (var j = 0; j < 4; j++) h[j] * p.w2[j]],
        logit = contributions.fold(p.b2, (s, v) => s + v);
    if (!logit.isFinite) throw ArgumentError('Logit overflow');
    final loss = max(logit, 0) - y * logit + log(1 + exp(-logit.abs()));
    return NeuralTrace._(z, h, g, contributions, logit, sigmoid(logit), loss);
  }
}

class NeuralGradient {
  final double loss, db2;
  final List<List<double>> dw1;
  final List<double> db1, dw2, dlogit;
  NeuralGradient._(
    this.loss,
    List<List<double>> w,
    List<double> b,
    List<double> o,
    this.db2,
    List<double> d,
  ) : dw1 = List.unmodifiable(w.map((r) => List<double>.unmodifiable(r))),
      db1 = List.unmodifiable(b),
      dw2 = List.unmodifiable(o),
      dlogit = List.unmodifiable(d);
  factory NeuralGradient.compute(
    List<List<double>> X,
    List<double> y,
    NeuralParameters p, {
    bool sum = false,
    bool tanh = false,
  }) {
    _finite(y);
    if (X.length != y.length) throw ArgumentError('Aligned nonempty batch');
    final dw1 = List.generate(4, (_) => List.filled(11, 0.0)),
        db1 = List.filled(4, 0.0),
        dw2 = List.filled(4, 0.0),
        dlogit = <double>[];
    var db2 = 0.0, loss = 0.0;
    final denominator = sum ? 1 : y.length;
    for (var i = 0; i < y.length; i++) {
      final r = NeuralTrace.compute(X[i], y[i], p, tanh: tanh),
          d = (r.probability - y[i]) / denominator;
      loss += r.loss / denominator;
      dlogit.add(d);
      db2 += d;
      for (var j = 0; j < 4; j++) {
        dw2[j] += r.hidden[j] * d;
        final delta = d * p.w2[j] * r.gate[j];
        db1[j] += delta;
        for (var k = 0; k < 11; k++) {
          dw1[j][k] += delta * X[i][k];
        }
      }
    }
    _finite([loss, db2, ...db1, ...dw2, ...dw1.expand((r) => r)]);
    return NeuralGradient._(loss, dw1, db1, dw2, db2, dlogit);
  }
}

class NeuralSample {
  final int sourceRow, positive, quality;
  final List<double> raw, x;
  NeuralSample.fromJson(Map<String, dynamic> j)
    : sourceRow = j['source_row_1based'],
      positive = j['positive'],
      quality = j['quality'],
      raw = _v(j['raw']),
      x = _v(j['standardized']) {
    _finite(raw);
    _finite(x);
    if (sourceRow < 1 ||
        sourceRow > 1599 ||
        raw.length != 11 ||
        x.length != 11 ||
        quality < 0 ||
        quality > 10 ||
        positive != (quality >= 6 ? 1 : 0)) {
      throw const FormatException('Real training observation');
    }
  }
}

class NeuralEpoch {
  final int epoch;
  final double trainLoss, validationLoss, trainAccuracy, validationAccuracy;
  NeuralEpoch.fromJson(Map<String, dynamic> j)
    : epoch = j['epoch'],
      trainLoss = (j['train_bce'] as num).toDouble(),
      validationLoss = (j['validation_bce'] as num).toDouble(),
      trainAccuracy = (j['train_accuracy'] as num).toDouble(),
      validationAccuracy = (j['validation_accuracy'] as num).toDouble() {
    _finite([trainLoss, validationLoss, trainAccuracy, validationAccuracy]);
    if (epoch < 0 ||
        trainLoss < 0 ||
        validationLoss < 0 ||
        trainAccuracy < 0 ||
        trainAccuracy > 1 ||
        validationAccuracy < 0 ||
        validationAccuracy > 1) {
      throw const FormatException('Finite epoch evidence');
    }
  }
}

class NeuralCheckpoint {
  final NeuralEpoch evidence;
  final NeuralParameters parameters;
  NeuralCheckpoint.fromJson(Map<String, dynamic> j)
    : evidence = NeuralEpoch.fromJson(j),
      parameters = NeuralParameters.fromJson(j['parameters']);
}

class NeuralAssets {
  final List<String> features;
  final List<double> mean, scale;
  final List<NeuralSample> samples;
  final List<NeuralEpoch> history;
  final List<NeuralCheckpoint> checkpoints;
  final int trainRows, validationRows, trainGroups, validationGroups;
  NeuralAssets.fromJson(Map<String, dynamic> j)
    : features = List.unmodifiable(List<String>.from(j['feature_names'])),
      mean = _v(j['mean']),
      scale = _v(j['scale']),
      samples = List.unmodifiable(
        (j['samples'] as List).map((r) => NeuralSample.fromJson(r)),
      ),
      history = List.unmodifiable(
        (j['history'] as List).map((r) => NeuralEpoch.fromJson(r)),
      ),
      checkpoints = List.unmodifiable(
        (j['checkpoints'] as List).map((r) => NeuralCheckpoint.fromJson(r)),
      ),
      trainRows = j['inner_train_rows'],
      validationRows = j['inner_validation_rows'],
      trainGroups = j['inner_train_groups'],
      validationGroups = j['inner_validation_groups'] {
    const names = [
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
    _finite(mean);
    _finite(scale);
    if (jsonEncode(features) != jsonEncode(names) ||
        mean.length != 11 ||
        scale.length != 11 ||
        scale.any((v) => v <= 0) ||
        samples.length != 8 ||
        samples.map((r) => r.sourceRow).toSet().length != 8 ||
        history.length != 121 ||
        checkpoints.length != 8 ||
        trainRows + validationRows != 966 ||
        trainRows < 8 ||
        validationRows < 1 ||
        trainGroups < 1 ||
        validationGroups < 1 ||
        trainGroups + validationGroups != 815 ||
        trainGroups > trainRows ||
        validationGroups > validationRows ||
        j['outer_fit_rows'] != 966 ||
        j['activation'] != 'relu' ||
        j['seed'] != 16 ||
        j['learning_rate'] != .05 ||
        j['dtype'] != 'float64' ||
        j['parameter_count'] != 53 ||
        jsonEncode(j['architecture']) != '[11,4,1]') {
      throw const FormatException('Neural evidence schema');
    }
    const epochs = [0, 1, 5, 10, 20, 40, 80, 120];
    for (var i = 0; i < history.length; i++) {
      if (history[i].epoch != i) throw const FormatException('Ordered history');
    }
    for (var i = 0; i < 8; i++) {
      if (checkpoints[i].evidence.epoch != epochs[i] ||
          checkpoints[i].evidence.trainLoss != history[epochs[i]].trainLoss ||
          checkpoints[i].evidence.validationLoss !=
              history[epochs[i]].validationLoss ||
          checkpoints[i].evidence.trainAccuracy !=
              history[epochs[i]].trainAccuracy ||
          checkpoints[i].evidence.validationAccuracy !=
              history[epochs[i]].validationAccuracy) {
        throw const FormatException('Checkpoint evidence mismatch');
      }
      for (var d = 0; d < 11; d++) {
        if (((samples[i].raw[d] - mean[d]) / scale[d] - samples[i].x[d]).abs() >
            1e-9) {
          throw const FormatException('Inner-training transform mismatch');
        }
      }
    }
  }
  List<List<double>> get X => List.unmodifiable(samples.map((r) => r.x));
  List<double> get y =>
      List.unmodifiable(samples.map((r) => r.positive.toDouble()));
  static NeuralAssets? _cached;
  static Future<NeuralAssets> load() async {
    if (_cached != null) return _cached!;
    final parsed = NeuralAssets.fromJson(
      jsonDecode(
        await rootBundle.loadString(
          'assets/datasets/wine_quality/neural_lab.json',
        ),
      ),
    );
    _cached = parsed;
    return parsed;
  }
}
