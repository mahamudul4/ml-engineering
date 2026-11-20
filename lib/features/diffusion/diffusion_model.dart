import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

void _finite(List<double> x, int n) {
  if (x.length != n || x.any((v) => !v.isFinite)) {
    throw ArgumentError('Expected $n finite values');
  }
}

List<double> _v(dynamic x) =>
    (x as List).map((v) => (v as num).toDouble()).toList();
dynamic _freeze(dynamic x) => x is Map
    ? Map<String, dynamic>.unmodifiable(
        x.map((k, v) => MapEntry(k as String, _freeze(v))),
      )
    : x is List
    ? List<dynamic>.unmodifiable(x.map(_freeze))
    : x;
List<double> noiseForward(
  List<double> clean,
  List<double> epsilon,
  double alphaBar,
) {
  _finite(clean, 64);
  _finite(epsilon, 64);
  if (!alphaBar.isFinite || alphaBar <= 0 || alphaBar > 1) {
    throw ArgumentError('alpha bar in (0,1]');
  }
  return List.unmodifiable(
    List.generate(
      64,
      (i) =>
          math.sqrt(alphaBar) * clean[i] + math.sqrt(1 - alphaBar) * epsilon[i],
    ),
  );
}

List<double> cleanEstimate(
  List<double> noisy,
  List<double> epsilon,
  double alphaBar, {
  bool clip = true,
}) {
  _finite(noisy, 64);
  _finite(epsilon, 64);
  if (!alphaBar.isFinite || alphaBar <= 0 || alphaBar > 1) {
    throw ArgumentError('alpha bar in (0,1]');
  }
  final x = List.generate(
    64,
    (i) =>
        (noisy[i] - math.sqrt(1 - alphaBar) * epsilon[i]) / math.sqrt(alphaBar),
  );
  _finite(x, 64);
  return List.unmodifiable(
    clip ? x.map((v) => v.clamp(-1.0, 1.0).toDouble()) : x,
  );
}

List<double> ddimStep(
  List<double> noisy,
  List<double> epsilon,
  double alphaBar,
  double previous,
) {
  if (!previous.isFinite || previous < alphaBar || previous > 1) {
    throw ArgumentError('Reverse alpha bar increases up to1');
  }
  final x = cleanEstimate(noisy, epsilon, alphaBar);
  return List.unmodifiable(
    List.generate(
      64,
      (i) => math.sqrt(previous) * x[i] + math.sqrt(1 - previous) * epsilon[i],
    ),
  );
}

List<double> guidedNoise(
  List<double> unconditional,
  List<double> conditional,
  double scale,
) {
  _finite(unconditional, 64);
  _finite(conditional, 64);
  if (!scale.isFinite || scale < 0 || scale > 4) {
    throw ArgumentError('Guidance0..4');
  }
  return List.unmodifiable(
    List.generate(
      64,
      (i) => unconditional[i] + scale * (conditional[i] - unconditional[i]),
    ),
  );
}

List<double> probabilities(List<double> scores, double temperature) {
  if (scores.isEmpty || !temperature.isFinite || temperature <= 0) {
    throw ArgumentError('Nonempty scores,positive finite temperature');
  }
  _finite(scores, scores.length);
  final peak = scores.reduce(math.max);
  final e = scores.map((s) => math.exp((s - peak) / temperature)).toList();
  final sum = e.reduce((a, b) => a + b);
  return List.unmodifiable(e.map((v) => v / sum));
}

class DiffusionFrame {
  final int t;
  final List<double> pixels;
  DiffusionFrame(this.t, List<double> pixels)
    : pixels = List.unmodifiable(pixels);
}

class DiffusionAssets {
  static DiffusionAssets? _cached;
  static Future<DiffusionAssets>? _pending;
  final Map<String, dynamic> data;
  DiffusionAssets.fromJson(Map<String, dynamic> j) : data = _freeze(j) {
    final bar = alphaBar;
    if (bar.length != 33 ||
        bar.first != 1 ||
        bar.any((a) => !a.isFinite || a <= 0 || a > 1)) {
      throw const FormatException('alpha bar schema');
    }
    for (var t = 1; t < bar.length; t++) {
      if (bar[t] >= bar[t - 1]) {
        throw const FormatException('Noise schedule must decrease');
      }
    }
    for (final spec in [
      ('denoiser', 'first', 79, 64),
      ('denoiser', 'hidden', 64, 64),
      ('denoiser', 'out', 64, 64),
      ('alignment', 'image', 64, 32),
      ('alignment', 'project', 32, 8),
    ]) {
      final w = data['weights'][spec.$1];
      final matrix = w['${spec.$2}.weight'] as List;
      if (matrix.length != spec.$4) {
        throw const FormatException('Weight rows');
      }
      for (final row in matrix) {
        _finite(_v(row), spec.$3);
      }
      _finite(_v(w['${spec.$2}.bias']), spec.$4);
    }
    final names = data['weights']['alignment']['names.weight'] as List;
    if (names.length != 10) {
      throw const FormatException('Ten known class names');
    }
    for (final row in names) {
      _finite(_v(row), 8);
    }
    if (samples.length != 10) {
      throw const FormatException('Ten source examples');
    }
    for (final r in samples) {
      _finite(_v(r['unit_pixels']), 64);
      _finite(_v(r['epsilon']), 64);
      if (_v(r['unit_pixels']).any((v) => v < 0 || v > 1)) {
        throw const FormatException('Pixel0..1');
      }
    }
    _finite(initial, 64);
  }
  static Future<DiffusionAssets> load() async =>
      _cached ??= await (_pending ??= _load());
  static Future<DiffusionAssets> _load() async => DiffusionAssets.fromJson(
    jsonDecode(
      await rootBundle.loadString('assets/datasets/digits/diffusion_lab.json'),
    ),
  );
  List<double> get alphaBar => List.unmodifiable(_v(data['alpha_bar']));
  List<dynamic> get samples => data['samples'];
  List<double> get initial => List.unmodifiable(_v(data['initial']));
  Map<String, dynamic> get report => data['report'];
  List<String> get names =>
      List.unmodifiable((data['names'] as List).cast<String>());
  List<double> _linear(String model, String layer, List<double> x) {
    final w = data['weights'][model];
    final rows = w['$layer.weight'] as List;
    final bias = _v(w['$layer.bias']);
    _finite(x, (rows.first as List).length);
    final r = List.generate(rows.length, (i) {
      final row = _v(rows[i]);
      var sum = bias[i];
      for (var j = 0; j < x.length; j++) {
        sum += row[j] * x[j];
      }
      return sum;
    });
    _finite(r, r.length);
    return r;
  }

  double _silu(double v) =>
      v >= 0 ? v / (1 + math.exp(-v)) : v * math.exp(v) / (1 + math.exp(v));
  List<double> predict(List<double> x, int t, int label) {
    _finite(x, 64);
    if (t < 1 || t > 32 || label < 0 || label > 10) {
      throw ArgumentError('t1..32,label0..10(null)');
    }
    final angle = math.pi * t / 32;
    final input = [
      ...x,
      math.sin(angle),
      math.cos(angle),
      math.sin(2 * angle),
      math.cos(2 * angle),
      ...List.generate(11, (i) => i == label ? 1.0 : 0.0),
    ];
    return List.unmodifiable(
      _linear(
        'denoiser',
        'out',
        _linear(
          'denoiser',
          'hidden',
          _linear('denoiser', 'first', input).map(_silu).toList(),
        ).map(_silu).toList(),
      ),
    );
  }

  List<DiffusionFrame> sample({
    int label = 3,
    double guidance = 1,
    int steps = 8,
  }) {
    if (![8, 32].contains(steps) || label < 0 || label > 9) {
      throw ArgumentError('Steps8/32,label0..9');
    }
    guidedNoise(List.filled(64, 0), List.filled(64, 0), guidance);
    final times = List.generate(
      steps,
      (i) => (32 - i * 31 / (steps - 1)).round(),
    );
    final bar = alphaBar;
    var x = initial;
    final frames = [DiffusionFrame(32, x)];
    for (var i = 0; i < times.length; i++) {
      final t = times[i], prev = i + 1 < times.length ? times[i + 1] : 0;
      final epsilon = guidedNoise(
        predict(x, t, 10),
        predict(x, t, label),
        guidance,
      );
      x = ddimStep(x, epsilon, bar[t], bar[prev]);
      frames.add(DiffusionFrame(prev, x));
    }
    return List.unmodifiable(frames);
  }

  List<double> _normalize(List<double> x) {
    final norm = math.sqrt(x.fold<double>(0, (sum, v) => sum + v * v));
    final denominator = math.max(norm, 1e-12);
    return x.map((v) => v / denominator).toList();
  }

  List<double> imageEmbedding(List<double> pixels) {
    _finite(pixels, 64);
    if (pixels.any((p) => p < 0 || p > 1)) {
      throw ArgumentError('Unit pixels');
    }
    return List.unmodifiable(
      _normalize(
        _linear(
          'alignment',
          'project',
          _linear(
            'alignment',
            'image',
            pixels,
          ).map((v) => math.max(0.0, v)).toList(),
        ),
      ),
    );
  }

  List<double> textEmbedding(int label) {
    if (label < 0 || label > 9) {
      throw ArgumentError('Known class name0..9');
    }
    return List.unmodifiable(
      _normalize(_v(data['weights']['alignment']['names.weight'][label])),
    );
  }

  List<double> similarities(List<double> pixels) {
    final image = imageEmbedding(pixels);
    return List.unmodifiable(
      List.generate(10, (i) {
        final text = textEmbedding(i);
        return List.generate(
          8,
          (j) => image[j] * text[j],
        ).reduce((a, b) => a + b);
      }),
    );
  }

  static List<double> vector(dynamic x) => _v(x);
}
