import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

List<double> _vector(dynamic raw) =>
    List.unmodifiable((raw as List).map((x) => (x as num).toDouble()));
List<List<double>> _matrix(dynamic raw) =>
    List.unmodifiable((raw as List).map(_vector));
void _pair(List<double> x) {
  if (x.length != 2 || x.any((v) => !v.isFinite)) {
    throw ArgumentError('Finite two-feature vector required');
  }
}

double squaredDistance(List<double> a, List<double> b) {
  _pair(a);
  _pair(b);
  final d = pow(a[0] - b[0], 2).toDouble() + pow(a[1] - b[1], 2).toDouble();
  if (!d.isFinite) throw ArgumentError('Distance overflow');
  return d;
}

int nearestCenter(List<double> x, List<List<double>> centers) {
  if (centers.isEmpty) throw ArgumentError('At least one center');
  var best = 0, distance = squaredDistance(x, centers[0]);
  for (var i = 1; i < centers.length; i++) {
    final d = squaredDistance(x, centers[i]);
    if (d < distance) {
      best = i;
      distance = d;
    }
  }
  return best;
}

double clusteringInertia(
  List<List<double>> points,
  List<List<double>> centers,
) {
  if (points.isEmpty) throw ArgumentError('Nonempty observations');
  return points.fold(
    0.0,
    (sum, x) => sum + squaredDistance(x, centers[nearestCenter(x, centers)]),
  );
}

class UnsupervisedPoint {
  final int sourceRow;
  final List<double> values, coordinates;
  UnsupervisedPoint.fromJson(Map<String, dynamic> j)
    : sourceRow = j['source_row_1based'],
      values = _vector(j['values']),
      coordinates = _vector(j['coordinates']) {
    _pair(values);
    _pair(coordinates);
    if (sourceRow < 1) throw const FormatException('Source row');
  }
}

class LloydSnapshot {
  final int step;
  final double inertia;
  final List<List<double>> centers;
  final List<int> labels, emptyBeforeUpdate;
  LloydSnapshot.fromJson(Map<String, dynamic> j)
    : step = j['step'],
      inertia = (j['inertia'] as num).toDouble(),
      centers = _matrix(j['centers']),
      labels = List.unmodifiable(List<int>.from(j['labels'])),
      emptyBeforeUpdate = List.unmodifiable(
        List<int>.from(j['empty_before_update']),
      ) {
    for (final c in centers) {
      _pair(c);
    }
    if (step < 0 ||
        !inertia.isFinite ||
        inertia < 0 ||
        centers.isEmpty ||
        labels.any((l) => l < 0 || l >= centers.length) ||
        emptyBeforeUpdate.any((l) => l < 0 || l >= centers.length)) {
      throw const FormatException('Invalid Lloyd state');
    }
  }
}

class LloydRun {
  final int k, seed;
  final List<LloydSnapshot> states;
  LloydRun.fromJson(Map<String, dynamic> j)
    : k = j['k'],
      seed = j['seed'],
      states = List.unmodifiable(
        (j['states'] as List).map((s) => LloydSnapshot.fromJson(s)),
      ) {
    if (k < 1 || states.isEmpty) throw const FormatException('Empty Lloyd run');
    for (var i = 0; i < states.length; i++) {
      if (states[i].step != i ||
          states[i].centers.length != k ||
          (i > 0 && states[i].inertia > states[i - 1].inertia + 1e-8)) {
        throw const FormatException('Inconsistent Lloyd steps');
      }
    }
  }
}

class DensityResult {
  final List<int> labels, counts;
  final List<bool> core;
  DensityResult._(List<int> l, List<int> n, List<bool> c)
    : labels = List.unmodifiable(l),
      counts = List.unmodifiable(n),
      core = List.unmodifiable(c);
  factory DensityResult.compute(
    List<List<double>> points, {
    required double eps,
    required int minSamples,
  }) {
    if (points.isEmpty ||
        !eps.isFinite ||
        eps < 0 ||
        !((eps * eps).isFinite) ||
        minSamples < 1) {
      throw ArgumentError(
        'Nonempty points, finite radius and positive minSamples',
      );
    }
    final neighbors = [
      for (final a in points)
        [
          for (var j = 0; j < points.length; j++)
            if (squaredDistance(a, points[j]) <= eps * eps) j,
        ],
    ];
    final counts = neighbors.map((n) => n.length).toList(),
        core = neighbors.map((n) => n.length >= minSamples).toList();
    final labels = List.filled(points.length, -1);
    var cluster = 0;
    for (var i = 0; i < points.length; i++) {
      if (!core[i] || labels[i] >= 0) continue;
      labels[i] = cluster;
      final queue = [i];
      for (var q = 0; q < queue.length; q++) {
        for (final j in neighbors[queue[q]]) {
          if (core[j] && labels[j] < 0) {
            labels[j] = cluster;
            queue.add(j);
          }
        }
      }
      cluster++;
    }
    for (var i = 0; i < points.length; i++) {
      if (core[i]) continue;
      final adjacent = neighbors[i].where((j) => core[j]).map((j) => labels[j]);
      if (adjacent.isNotEmpty) labels[i] = adjacent.reduce(min);
    }
    return DensityResult._(labels, counts, core);
  }
  int get clusters => labels.where((l) => l >= 0).toSet().length;
  int get noise => labels.where((l) => l < 0).length;
  int get borders => [
    for (var i = 0; i < labels.length; i++)
      if (labels[i] >= 0 && !core[i]) i,
  ].length;
}

class PcaFit {
  final String space;
  final List<List<double>> data, components;
  final List<double> mean, ratio, singular;
  PcaFit.fromJson(Map<String, dynamic> j)
    : space = j['space'],
      data = _matrix(j['data']),
      components = _matrix(j['components']),
      mean = _vector(j['mean']),
      ratio = _vector(j['variance_ratio']),
      singular = _vector(j['singular']) {
    _pair(mean);
    _pair(ratio);
    _pair(singular);
    for (final x in [...data, ...components]) {
      _pair(x);
    }
    if (data.length < 2 ||
        components.length != 2 ||
        ratio.any((v) => v < 0) ||
        singular.any((v) => v < 0) ||
        ((ratio[0] + ratio[1]) - 1).abs() > 1e-8) {
      throw const FormatException('Invalid PCA fit');
    }
    for (var i = 0; i < 2; i++) {
      for (var j = 0; j < 2; j++) {
        final dot =
            components[i][0] * components[j][0] +
            components[i][1] * components[j][1];
        if ((dot - (i == j ? 1 : 0)).abs() > 1e-8) {
          throw const FormatException('Non-orthonormal PCA basis');
        }
      }
    }
  }
  void _rank(int q) {
    if (q < 0 || q > 2) throw ArgumentError('q in 0..2');
  }

  List<double> project(List<double> x, int q) {
    _pair(x);
    _rank(q);
    return List.unmodifiable([
      for (var j = 0; j < q; j++)
        (x[0] - mean[0]) * components[j][0] +
            (x[1] - mean[1]) * components[j][1],
    ]);
  }

  List<double> reconstruct(List<double> x, int q) {
    final scores = project(x, q);
    return List.unmodifiable([
      for (var d = 0; d < 2; d++)
        mean[d] +
            [for (var j = 0; j < q; j++) scores[j] * components[j][d]]
                .fold(0.0, (a, b) => a + b),
    ]);
  }

  double kept(int q) {
    _rank(q);
    return ratio.take(q).fold(0.0, (a, b) => a + b);
  }

  double mse(int q) =>
      data.fold(0.0, (sum, x) => sum + squaredDistance(x, reconstruct(x, q))) /
      (data.length * 2);
}

class UnsupervisedAssets {
  final List<UnsupervisedPoint> points;
  final List<LloydRun> runs;
  final List<PcaFit> pca;
  UnsupervisedAssets.fromJson(Map<String, dynamic> km, Map<String, dynamic> pc)
    : points = List.unmodifiable(
        (km['points'] as List).map((j) => UnsupervisedPoint.fromJson(j)),
      ),
      runs = List.unmodifiable(
        (km['runs'] as List).map((j) => LloydRun.fromJson(j)),
      ),
      pca = List.unmodifiable(
        (pc['runs'] as List).map((j) => PcaFit.fromJson(j)),
      ) {
    if (points.isEmpty ||
        runs.isEmpty ||
        pca.length != 2 ||
        points.map((p) => p.sourceRow).toSet().length != points.length) {
      throw const FormatException('Invalid lab pool');
    }
    final sourceRows = List<int>.from(pc['source_rows']);
    if (sourceRows.length != points.length ||
        pca.any((p) => p.data.length != points.length)) {
      throw const FormatException('Unaligned PCA rows');
    }
    for (var i = 0; i < points.length; i++) {
      if (sourceRows[i] != points[i].sourceRow ||
          squaredDistance(points[i].values, pca[0].data[i]) > 1e-12 ||
          squaredDistance(points[i].coordinates, pca[1].data[i]) > 1e-12) {
        throw const FormatException('Unaligned source observations');
      }
    }
    final coords = points.map((p) => p.coordinates).toList();
    for (final r in runs) {
      for (final s in r.states) {
        if (s.labels.length != points.length ||
            (clusteringInertia(coords, s.centers) - s.inertia).abs() > 1e-7) {
          throw const FormatException('Lloyd objective mismatch');
        }
        for (var i = 0; i < points.length; i++) {
          if (nearestCenter(coords[i], s.centers) != s.labels[i]) {
            throw const FormatException('Lloyd assignment mismatch');
          }
        }
      }
    }
  }
  static UnsupervisedAssets? _cached;
  static Future<UnsupervisedAssets> load() async {
    if (_cached != null) return _cached!;
    final km = jsonDecode(
      await rootBundle.loadString(
        'assets/datasets/adult/unsupervised_kmeans_lab.json',
      ),
    ) as Map<String, dynamic>;
    final pc = jsonDecode(
      await rootBundle.loadString(
        'assets/datasets/adult/unsupervised_pca_lab.json',
      ),
    ) as Map<String, dynamic>;
    final parsed = UnsupervisedAssets.fromJson(km, pc);
    _cached = parsed;
    return parsed;
  }
}
