import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

List<double> _v(dynamic x) =>
    List<double>.unmodifiable((x as List).map((v) => (v as num).toDouble()));
List<List<double>> _m(dynamic x) =>
    List<List<double>>.unmodifiable((x as List).map(_v));
List<List<List<double>>> _cube(dynamic x) =>
    List<List<List<double>>>.unmodifiable((x as List).map(_m));
List<List<List<List<double>>>> _filters(dynamic x) =>
    List<List<List<List<double>>>>.unmodifiable((x as List).map(_cube));
void _finite(List<double> x) {
  if (x.isEmpty || x.any((v) => !v.isFinite)) {
    throw ArgumentError('Nonempty finite values');
  }
}

void _rect(List<List<double>> x) {
  if (x.isEmpty || x.first.isEmpty) throw ArgumentError('Nonempty matrix');
  for (final r in x) {
    _finite(r);
    if (r.length != x.first.length) throw ArgumentError('Rectangular image');
  }
}

class CorrelationResult {
  final List<List<double>> output;
  final int stride, padding;
  CorrelationResult._(List<List<double>> x, this.stride, this.padding)
    : output = List.unmodifiable(x.map((r) => List<double>.unmodifiable(r)));
  factory CorrelationResult.compute(
    List<List<double>> image,
    List<List<double>> kernel, {
    int stride = 1,
    int padding = 0,
  }) {
    _rect(image);
    _rect(kernel);
    if (stride < 1 || padding < 0 || padding > 4) {
      throw ArgumentError('Bounded positive stride/nonnegative padding');
    }
    final h = (image.length + 2 * padding - kernel.length) ~/ stride + 1,
        w =
            (image.first.length + 2 * padding - kernel.first.length) ~/ stride +
            1;
    if (image.length + 2 * padding < kernel.length ||
        image.first.length + 2 * padding < kernel.first.length ||
        h < 1 ||
        w < 1) {
      throw ArgumentError('Kernel must fit padded input');
    }
    final result = List.generate(h, (_) => List.filled(w, 0.0));
    for (var i = 0; i < h; i++) {
      for (var j = 0; j < w; j++) {
        for (var u = 0; u < kernel.length; u++) {
          for (var v = 0; v < kernel.first.length; v++) {
            final y = i * stride - padding + u, x = j * stride - padding + v;
            if (y >= 0 &&
                y < image.length &&
                x >= 0 &&
                x < image.first.length) {
              result[i][j] += image[y][x] * kernel[u][v];
            }
          }
        }
      }
    }
    _finite(result.expand((r) => r).toList());
    return CorrelationResult._(result, stride, padding);
  }
}

List<List<double>> pool2(List<List<double>> image, {bool average = false}) {
  _rect(image);
  if (image.length < 2 || image.first.length < 2) {
    throw ArgumentError('2x2 pooling window must fit');
  }
  return List.unmodifiable(
    List.generate(
      image.length ~/ 2,
      (i) => List<double>.unmodifiable(
        List.generate(image.first.length ~/ 2, (j) {
          final values = [
            image[2 * i][2 * j],
            image[2 * i][2 * j + 1],
            image[2 * i + 1][2 * j],
            image[2 * i + 1][2 * j + 1],
          ];
          return average
              ? values.reduce((a, b) => a + b) / 4
              : values.reduce(max);
        }),
      ),
    ),
  );
}

List<List<double>> shiftRight(List<List<double>> image) {
  _rect(image);
  return List.unmodifiable(
    image.map((r) => List<double>.unmodifiable([0.0, ...r.take(r.length - 1)])),
  );
}

class VisionSample {
  final int sourceRow, digit;
  final List<List<double>> pixels;
  VisionSample.fromJson(Map<String, dynamic> j)
    : sourceRow = j['source_row_1based'],
      digit = j['digit'],
      pixels = _m(j['pixels']) {
    _rect(pixels);
    if (sourceRow < 1 ||
        sourceRow > 1797 ||
        ![5, 6, 9].contains(digit) ||
        pixels.length != 8 ||
        pixels.any(
          (r) =>
              r.length != 8 ||
              r.any((v) => v < 0 || v > 16 || v != v.roundToDouble()),
        )) {
      throw const FormatException('Actual target-training 8x8 observation');
    }
  }
  List<List<double>> get normalized => List.unmodifiable(
    pixels.map((r) => List<double>.unmodifiable(r.map((v) => v / 16))),
  );
}

class VisionPrediction {
  final List<double> logits, probability, features;
  VisionPrediction(List<double> z, List<double> h)
    : logits = List.unmodifiable(z),
      features = List.unmodifiable(h),
      probability = _softmax(z);
  static List<double> _softmax(List<double> x) {
    _finite(x);
    final m = x.reduce(max),
        e = x.map((v) => exp(v - m)).toList(),
        sum = e.reduce((a, b) => a + b);
    return List.unmodifiable(e.map((v) => v / sum));
  }

  int get digit => 5 + probability.indexOf(probability.reduce(max));
}

class VisionWeights {
  final List<List<List<List<double>>>> conv1, conv2;
  final List<List<double>> head;
  final List<double> bias1, bias2, headBias;
  VisionWeights.fromJson(Map<String, dynamic> j)
    : conv1 = _filters(j['conv1_weight']),
      conv2 = _filters(j['conv2_weight']),
      head = _m(j['head_weight']),
      bias1 = _v(j['conv1_bias']),
      bias2 = _v(j['conv2_bias']),
      headBias = _v(j['head_bias']) {
    void check(List<List<List<List<double>>>> w, int out, int input) {
      if (w.length != out ||
          w.any(
            (f) =>
                f.length != input ||
                f.any((k) => k.length != 3 || k.any((r) => r.length != 3)),
          )) {
        throw const FormatException('CNN filter dimensions');
      }
      for (final f in w) {
        for (final k in f) {
          _rect(k);
        }
      }
    }

    check(conv1, 4, 1);
    check(conv2, 8, 4);
    for (final b in [bias1, bias2, headBias]) {
      _finite(b);
    }
    if (bias1.length != 4 ||
        bias2.length != 8 ||
        headBias.length != 5 ||
        head.length != 5 ||
        head.any((r) => r.length != 32)) {
      throw const FormatException('CNN parameter count/layout');
    }
    _rect(head);
  }
  List<List<List<double>>> _layer(
    List<List<List<double>>> input,
    List<List<List<List<double>>>> weights,
    List<double> bias,
  ) {
    return List.unmodifiable(
      List.generate(weights.length, (c) {
        final channels = [
          for (var k = 0; k < input.length; k++)
            CorrelationResult.compute(
              input[k],
              weights[c][k],
              padding: 1,
            ).output,
        ];
        final activated = [
          for (var i = 0; i < channels.first.length; i++)
            [
              for (var j = 0; j < channels.first.first.length; j++)
                max(0.0, bias[c] + channels.fold(0.0, (s, k) => s + k[i][j])),
            ],
        ];
        return pool2(activated);
      }),
    );
  }

  VisionPrediction predict(List<List<double>> image) {
    _rect(image);
    if (image.length != 8 ||
        image.any((r) => r.length != 8 || r.any((v) => v < 0 || v > 1))) {
      throw ArgumentError('Normalized [1,8,8] image');
    }
    final h1 = _layer([image], conv1, bias1),
        h2 = _layer(h1, conv2, bias2),
        flat = h2.expand((c) => c.expand((r) => r)).toList();
    final z = [
      for (var c = 0; c < 5; c++)
        headBias[c] +
            List.generate(
              32,
              (k) => head[c][k] * flat[k],
            ).fold(0.0, (s, v) => s + v),
    ];
    return VisionPrediction(z, flat);
  }
}

class VisionAssets {
  final List<VisionSample> samples;
  final Map<String, List<List<double>>> kernels;
  final Map<String, VisionWeights> branches;
  final double frozenChange, fineChange;
  final Map<String, int> roles;
  VisionAssets.fromJson(Map<String, dynamic> j)
    : samples = List.unmodifiable(
        (j['samples'] as List).map((s) => VisionSample.fromJson(s)),
      ),
      kernels = Map.unmodifiable(
        (j['kernels'] as Map<String, dynamic>).map(
          (k, v) => MapEntry(k, _m(v)),
        ),
      ),
      branches = Map.unmodifiable({
        for (final b in j['branches'] as List)
          b['name'] as String: VisionWeights.fromJson(b['weights']),
      }),
      frozenChange = (j['frozen_backbone_max_abs'] as num).toDouble(),
      fineChange = (j['finetune_backbone_max_abs'] as num).toDouble(),
      roles = Map.unmodifiable(Map<String, int>.from(j['roles'])) {
    if (samples.length != 3 ||
        samples.map((s) => s.sourceRow).toSet().length != 3 ||
        jsonEncode(samples.map((s) => s.digit).toList()) != '[5,6,9]' ||
        branches.length != 3 ||
        !['initial', 'frozen', 'finetune'].every(branches.containsKey) ||
        kernels.length != 2 ||
        !kernels.containsKey('sobel') ||
        !kernels.containsKey('average') ||
        j['dtype'] != 'float64' ||
        j['pixel_divisor'] != 16 ||
        j['parameter_count'] != 501 ||
        jsonEncode(j['target_labels']) != '[5,6,7,8,9]' ||
        frozenChange != 0 ||
        !fineChange.isFinite ||
        fineChange <= 0 ||
        roles.length != 4 ||
        roles.values.any((v) => v < 1) ||
        roles.values.reduce((a, b) => a + b) != 1797) {
      throw const FormatException('Vision source/model contract');
    }
    if (roles['source_train'] != 721 ||
        roles['source_validation'] != 180 ||
        roles['target_train'] != 717 ||
        roles['target_validation'] != 179) {
      throw const FormatException('Declared diagnostic role counts');
    }
    List<double> backbone(VisionWeights w) => [
      ...w.conv1.expand((o) => o.expand((c) => c.expand((r) => r))),
      ...w.bias1,
      ...w.conv2.expand((o) => o.expand((c) => c.expand((r) => r))),
      ...w.bias2,
    ];
    final initial = backbone(branches['initial']!),
        frozen = backbone(branches['frozen']!),
        fine = backbone(branches['finetune']!);
    var measured = 0.0;
    for (var i = 0; i < initial.length; i++) {
      if (initial[i] != frozen[i]) {
        throw const FormatException('Frozen backbone changed');
      }
      measured = max(measured, (initial[i] - fine[i]).abs());
    }
    if ((measured - fineChange).abs() > 1e-12) {
      throw const FormatException('Fine-tune change evidence mismatch');
    }
    for (final k in kernels.values) {
      _rect(k);
      if (k.length != 3 || k.any((r) => r.length != 3)) {
        throw const FormatException('3x3 kernel');
      }
    }
    final sobel = [
      [-1.0, 0, 1],
      [-2.0, 0, 2],
      [-1.0, 0, 1],
    ];
    for (var i = 0; i < 3; i++) {
      for (var k = 0; k < 3; k++) {
        if (kernels['sobel']![i][k] != sobel[i][k] ||
            (kernels['average']![i][k] - 1 / 9).abs() > 1e-14) {
          throw const FormatException('Declared kernel values');
        }
      }
    }
  }
  static VisionAssets? _cached;
  static Future<VisionAssets> load() async {
    if (_cached != null) return _cached!;
    final a = VisionAssets.fromJson(
      jsonDecode(
        await rootBundle.loadString('assets/datasets/digits/vision_lab.json'),
      ),
    );
    _cached = a;
    return a;
  }
}
