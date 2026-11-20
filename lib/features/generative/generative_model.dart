import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

double sigmoid(double x) =>
    x >= 0 ? 1 / (1 + math.exp(-x)) : math.exp(x) / (1 + math.exp(x));
double softplus(double x) => math.max(x, 0) + math.log(1 + math.exp(-x.abs()));
void _vector(List<double> x, int n) {
  if (x.length != n || x.any((v) => !v.isFinite)) {
    throw ArgumentError('Expected $n finite values');
  }
}

double gaussianKL(List<double> mu, List<double> logvar) {
  if (mu.isEmpty) throw ArgumentError('Nonempty latent');
  _vector(mu, mu.length);
  _vector(logvar, mu.length);
  final k = List.generate(
    mu.length,
    (i) => .5 * (mu[i] * mu[i] + math.exp(logvar[i]) - 1 - logvar[i]),
  ).reduce((a, b) => a + b);
  if (!k.isFinite) throw ArgumentError('KL overflow');
  return k;
}

List<double> reparameterize(
  List<double> mu,
  List<double> logvar,
  List<double> epsilon,
) {
  gaussianKL(mu, logvar);
  _vector(epsilon, mu.length);
  final z = List.generate(
    mu.length,
    (i) => mu[i] + math.exp(.5 * logvar[i]) * epsilon[i],
  );
  _vector(z, mu.length);
  return List.unmodifiable(z);
}

double reconstructionBCE(List<double> logits, List<double> target) {
  if (logits.isEmpty) throw ArgumentError('Nonempty pixels');
  _vector(logits, logits.length);
  _vector(target, logits.length);
  if (target.any((v) => v < 0 || v > 1)) throw ArgumentError('Target 0..1');
  return List.generate(
    logits.length,
    (i) => softplus(logits[i]) - target[i] * logits[i],
  ).reduce((a, b) => a + b);
}

dynamic _freeze(dynamic x) => x is Map
    ? Map<String, dynamic>.unmodifiable(
        x.map((k, v) => MapEntry(k as String, _freeze(v))),
      )
    : x is List
    ? List<dynamic>.unmodifiable(x.map(_freeze))
    : x;
List<double> _numbers(dynamic x) =>
    (x as List).map((v) => (v as num).toDouble()).toList();

class GenerativeAssets {
  static GenerativeAssets? _cached;
  static Future<GenerativeAssets>? _pending;
  final Map<String, dynamic> data;
  GenerativeAssets.fromJson(Map<String, dynamic> json) : data = _freeze(json) {
    for (final spec in [
      ('vae', 'enc', 64, 32),
      ('vae', 'mu', 32, 2),
      ('vae', 'logvar', 32, 2),
      ('vae', 'dec', 2, 32),
      ('vae', 'out', 32, 64),
      ('generator', 'hidden', 2, 32),
      ('generator', 'out', 32, 64),
      ('discriminator', 'hidden', 64, 32),
      ('discriminator', 'out', 32, 1),
    ]) {
      final w = data['weights'][spec.$1];
      final matrix = w['${spec.$2}.weight'] as List;
      if (matrix.length != spec.$4) throw const FormatException('Weight rows');
      for (final row in matrix) {
        _vector(_numbers(row), spec.$3);
      }
      _vector(_numbers(w['${spec.$2}.bias']), spec.$4);
    }
    if (images.length != 10 || samples.length != 16) {
      throw const FormatException('Reference counts');
    }
    for (final image in images) {
      final p = _numbers(image['pixels']);
      _vector(p, 64);
      if (p.any((v) => v < 0 || v > 1)) {
        throw const FormatException('Pixel range');
      }
      _vector(_numbers(image['mu']), 2);
      _vector(_numbers(image['logvar']), 2);
      _vector(_numbers(image['reconstruction']), 64);
    }
    for (final sample in samples) {
      _vector(_numbers(sample['z']), 2);
      _vector(_numbers(sample['vae']), 64);
      _vector(_numbers(sample['gan']), 64);
    }
  }
  static Future<GenerativeAssets> load() async =>
      _cached ??= await (_pending ??= _load());
  static Future<GenerativeAssets> _load() async => GenerativeAssets.fromJson(
    jsonDecode(
      await rootBundle.loadString('assets/datasets/digits/generative_lab.json'),
    ),
  );
  List<dynamic> get images => data['images'];
  List<dynamic> get samples => data['samples'];
  Map<String, dynamic> get report => data['report'];
  List<double> linear(String model, String layer, List<double> x) {
    final w = data['weights'][model];
    final matrix = w['$layer.weight'] as List;
    final bias = _numbers(w['$layer.bias']);
    _vector(x, (matrix.first as List).length);
    final result = List.generate(matrix.length, (i) {
      final row = _numbers(matrix[i]);
      var v = bias[i];
      for (var j = 0; j < x.length; j++) {
        v += row[j] * x[j];
      }
      return v;
    });
    _vector(result, matrix.length);
    return List.unmodifiable(result);
  }

  (List<double>, List<double>) encode(List<double> x) {
    _vector(x, 64);
    if (x.any((v) => v < 0 || v > 1)) throw ArgumentError('Pixel 0..1');
    final h = linear('vae', 'enc', x).map((v) => math.max(0.0, v)).toList();
    return (linear('vae', 'mu', h), linear('vae', 'logvar', h));
  }

  List<double> decodeLogits(List<double> z) => linear(
    'vae',
    'out',
    linear('vae', 'dec', z).map((v) => math.max(0.0, v)).toList(),
  );
  List<double> decode(List<double> z) =>
      List.unmodifiable(decodeLogits(z).map(sigmoid));
  List<double> generate(List<double> z) => List.unmodifiable(
    linear(
      'generator',
      'out',
      linear('generator', 'hidden', z).map((v) => math.max(0.0, v)).toList(),
    ).map(sigmoid),
  );
  double discriminate(List<double> x) => sigmoid(
    linear(
      'discriminator',
      'out',
      linear(
        'discriminator',
        'hidden',
        x,
      ).map((v) => v < 0 ? .2 * v : v).toList(),
    ).single,
  );
  static List<double> vector(dynamic x) => _numbers(x);
}
