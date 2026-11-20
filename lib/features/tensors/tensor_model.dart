import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

List<double> _vector(dynamic x) =>
    List.unmodifiable((x as List).map((v) => (v as num).toDouble()));
void _finite(List<double> x) {
  if (x.isEmpty || x.any((v) => !v.isFinite)) {
    throw ArgumentError('Nonempty finite values');
  }
}

double _sigmoid(double x) {
  if (x >= 0) return 1 / (1 + exp(-x));
  final z = exp(x);
  return z / (1 + z);
}

class TensorLayout {
  final List<double> storage;
  final List<int> shape, stride;
  final int offset;
  TensorLayout({
    required List<double> storage,
    required List<int> shape,
    required List<int> stride,
    this.offset = 0,
  }) : storage = List.unmodifiable(storage),
       shape = List.unmodifiable(shape),
       stride = List.unmodifiable(stride) {
    _finite(storage);
    if (shape.length != 2 ||
        stride.length != 2 ||
        shape.any((n) => n < 1) ||
        stride.any((n) => n < 0) ||
        offset < 0 ||
        offset + (shape[0] - 1) * stride[0] + (shape[1] - 1) * stride[1] >=
            storage.length) {
      throw ArgumentError('Bounded nonnegative-stride 2D layout');
    }
  }
  int elementOffset(int row, int col) {
    if (row < 0 || col < 0 || row >= shape[0] || col >= shape[1]) {
      throw RangeError('Tensor coordinate');
    }
    return offset + row * stride[0] + col * stride[1];
  }

  double value(int row, int col) => storage[elementOffset(row, col)];
  bool get isContiguous {
    var expected = 1;
    for (var d = 1; d >= 0; d--) {
      if (shape[d] != 1) {
        if (stride[d] != expected) return false;
        expected *= shape[d];
      }
    }
    return true;
  }

  bool get overlaps {
    final addresses = {
      for (var i = 0; i < shape[0]; i++)
        for (var j = 0; j < shape[1]; j++) elementOffset(i, j),
    };
    return addresses.length < shape[0] * shape[1];
  }

  TensorLayout contiguous() {
    if (isContiguous) return this;
    return TensorLayout(
      storage: [
        for (var i = 0; i < shape[0]; i++)
          for (var j = 0; j < shape[1]; j++) value(i, j),
      ],
      shape: shape,
      stride: [shape[1], 1],
    );
  }
}

class BroadcastResult {
  final List<int> shape;
  final List<List<double>> residual;
  final double mse;
  BroadcastResult._(List<int> s, List<List<double>> r, this.mse)
    : shape = List.unmodifiable(s),
      residual = List.unmodifiable(r.map((v) => List<double>.unmodifiable(v)));
  factory BroadcastResult.compute(
    List<double> probability,
    List<double> labels, {
    required bool columnTarget,
  }) {
    _finite(probability);
    _finite(labels);
    if (probability.length != labels.length ||
        probability.any((p) => p < 0 || p > 1) ||
        labels.any((y) => y != 0 && y != 1)) {
      throw ArgumentError('Aligned binary batch vectors');
    }
    final n = labels.length,
        matrix = columnTarget
            ? [
                for (final y in labels) [for (final p in probability) p - y],
              ]
            : [
                [for (var i = 0; i < n; i++) probability[i] - labels[i]],
              ];
    final squared = matrix.expand((r) => r).fold(0.0, (s, v) => s + v * v);
    return BroadcastResult._(
      columnTarget ? [n, n] : [n],
      matrix,
      squared / (columnTarget ? n * n : n),
    );
  }
}

class GradientResult {
  final double loss;
  final List<double> gradient;
  GradientResult._(this.loss, List<double> g) : gradient = List.unmodifiable(g);
  factory GradientResult.compute(
    List<List<double>> X,
    List<double> y,
    List<double> theta,
  ) {
    _finite(theta);
    _finite(y);
    if (theta.length != 3 ||
        X.length != y.length ||
        y.any((v) => v != 0 && v != 1)) {
      throw ArgumentError('X[B,2], binary y[B], theta[w0,w1,b]');
    }
    var loss = 0.0;
    final g = [0.0, 0.0, 0.0];
    for (var i = 0; i < X.length; i++) {
      _finite(X[i]);
      if (X[i].length != 2) throw ArgumentError('Two selected features');
      final z = X[i][0] * theta[0] + X[i][1] * theta[1] + theta[2];
      if (!z.isFinite) throw ArgumentError('Logit overflow');
      loss += max(z, 0) - z * y[i] + log(1 + exp(-z.abs()));
      final d = _sigmoid(z) - y[i];
      g[0] += X[i][0] * d;
      g[1] += X[i][1] * d;
      g[2] += d;
    }
    if (!loss.isFinite || g.any((v) => !v.isFinite)) {
      throw ArgumentError('Objective or gradient overflow');
    }
    return GradientResult._(
      loss / y.length,
      g.map((v) => v / y.length).toList(),
    );
  }
  List<double> step(List<double> theta, double rate) {
    _finite(theta);
    if (theta.length != 3 || !rate.isFinite || rate <= 0) {
      throw ArgumentError('Finite positive rate');
    }
    final next = [for (var i = 0; i < 3; i++) theta[i] - rate * gradient[i]];
    _finite(next);
    return List.unmodifiable(next);
  }
}

class TensorSample {
  final int sourceRow, quality, positive;
  final List<double> raw, standardized;
  TensorSample.fromJson(Map<String, dynamic> j)
    : sourceRow = j['source_row_1based'],
      quality = j['quality'],
      positive = j['positive'],
      raw = _vector(j['raw']),
      standardized = _vector(j['standardized']) {
    _finite(raw);
    _finite(standardized);
    if (sourceRow < 1 ||
        quality < 0 ||
        quality > 10 ||
        positive != (quality >= 6 ? 1 : 0) ||
        raw.length != 11 ||
        standardized.length != 11) {
      throw const FormatException('Invalid real training sample');
    }
  }
}

class TensorAssets {
  final List<TensorSample> samples;
  final List<String> features;
  final List<double> mean, scale, weights, layoutStorage;
  final double bias;
  final String torchVersion;
  TensorAssets.fromJson(Map<String, dynamic> j)
    : samples = List.unmodifiable(
        (j['samples'] as List).map((s) => TensorSample.fromJson(s)),
      ),
      features = List.unmodifiable(List<String>.from(j['feature_names'])),
      mean = _vector(j['mean']),
      scale = _vector(j['scale']),
      weights = _vector(j['reference_weights']),
      bias = (j['reference_bias'] as num).toDouble(),
      layoutStorage = _vector(j['layout_storage']),
      torchVersion = j['torch_version'] {
    _finite(mean);
    _finite(scale);
    _finite(weights);
    _finite(layoutStorage);
    if (samples.length != 16 ||
        samples.map((s) => s.sourceRow).toSet().length != 16 ||
        features.length != 11 ||
        features.toSet().length != 11 ||
        [mean.length, scale.length, weights.length].any((n) => n != 11) ||
        scale.any((v) => v <= 0) ||
        !bias.isFinite ||
        layoutStorage.length != 12) {
      throw const FormatException('Invalid tensor asset schema');
    }
    const orderedFeatures = [
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
    if (j['dtype'] != 'float64' ||
        j['itemsize'] != 8 ||
        jsonEncode(j['layout_columns']) != '[10,1,9]' ||
        jsonEncode(j['gradient_columns']) != '[10,1]' ||
        List.generate(
          11,
          (i) => features[i] == orderedFeatures[i],
        ).contains(false)) {
      throw const FormatException('Ordered feature/dtype contract mismatch');
    }
    for (final s in samples) {
      for (var d = 0; d < 11; d++) {
        if (((s.raw[d] - mean[d]) / scale[d] - s.standardized[d]).abs() >
            1e-9) {
          throw const FormatException('Training transform mismatch');
        }
      }
    }
    const cols = [10, 1, 9];
    for (var i = 0; i < 4; i++) {
      for (var d = 0; d < 3; d++) {
        if (layoutStorage[i * 3 + d] != samples[i].raw[cols[d]]) {
          throw const FormatException('Source layout mismatch');
        }
      }
    }
  }
  TensorLayout layout(String mode) {
    final (shape, stride) = switch (mode) {
      'original' => ([4, 3], [3, 1]),
      'transpose' => ([3, 4], [1, 3]),
      'slice' => ([4, 2], [3, 2]),
      'expand' => ([4, 3], [3, 0]),
      _ => throw ArgumentError('Unknown layout'),
    };
    return TensorLayout(storage: layoutStorage, shape: shape, stride: stride);
  }

  List<double> probabilities(int batch) {
    if (batch < 1 || batch > 4) throw ArgumentError('Batch in 1..4');
    return List.unmodifiable([
      for (final s in samples.take(batch))
        _sigmoid(
          bias +
              [for (var d = 0; d < 11; d++) s.standardized[d] * weights[d]]
                  .fold(0.0, (a, b) => a + b),
        ),
    ]);
  }

  List<List<double>> get gradientX => List.unmodifiable(
    samples.map(
      (s) => List<double>.unmodifiable([s.standardized[10], s.standardized[1]]),
    ),
  );
  List<double> labels(int batch) {
    if (batch < 1 || batch > samples.length) {
      throw ArgumentError('Bounded batch');
    }
    return List.unmodifiable(
      samples.take(batch).map((s) => s.positive.toDouble()),
    );
  }

  static TensorAssets? _cached;
  static Future<TensorAssets> load() async {
    if (_cached != null) return _cached!;
    final j = jsonDecode(
      await rootBundle.loadString(
        'assets/datasets/wine_quality/tensor_lab.json',
      ),
    ) as Map<String, dynamic>;
    final parsed = TensorAssets.fromJson(j);
    _cached = parsed;
    return parsed;
  }
}
