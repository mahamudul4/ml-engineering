import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

List<double> vector(List<dynamic> raw) =>
    List.unmodifiable(raw.map((x) => (x as num).toDouble()));
List<List<double>> matrix(List<dynamic> raw) =>
    List.unmodifiable(raw.map((row) => vector(row)));
void finitePair(List<double> x) {
  if (x.length != 2 || x.any((v) => !v.isFinite)) {
    throw ArgumentError('Finite two-feature vector required.');
  }
}

class ClassicalPoint {
  final int sourceRow, positive;
  final List<double> values;
  ClassicalPoint.fromJson(Map<String, dynamic> j)
    : sourceRow = j['source_row_1based'],
      positive = j['positive'],
      values = vector(j['values']) {
    finitePair(values);
    if (sourceRow < 1 || ![0, 1].contains(positive)) {
      throw FormatException('Invalid source observation.');
    }
  }
}

class SvmSnapshot {
  final double c, bias, norm;
  final int supportCount;
  final List<double> weights;
  final List<bool> supportFlags;
  SvmSnapshot.fromJson(Map<String, dynamic> j)
    : c = (j['C'] as num).toDouble(),
      bias = (j['bias'] as num).toDouble(),
      norm = (j['norm'] as num).toDouble(),
      supportCount = j['support_count'],
      weights = vector(j['weights']),
      supportFlags = List.unmodifiable(List<bool>.from(j['support_flags'])) {
    finitePair(weights);
    final actual = sqrt(weights.fold(0.0, (a, b) => a + b * b));
    if (!c.isFinite ||
        c <= 0 ||
        !bias.isFinite ||
        !norm.isFinite ||
        norm <= 1e-8 ||
        (norm - actual).abs() > 1e-8 ||
        supportCount < 1) {
      throw FormatException('Invalid fitted margin.');
    }
  }
  double score(List<double> z) {
    finitePair(z);
    return weights[0] * z[0] + weights[1] * z[1] + bias;
  }

  double signedMargin(List<double> z, int label) {
    if (![0, 1].contains(label)) throw ArgumentError('Binary label');
    return (2 * label - 1) * score(z);
  }

  double get width => 2 / norm;
}

class Neighbor {
  final ClassicalPoint point;
  final double distance, weight;
  Neighbor(this.point, this.distance, this.weight);
}

class NeighborResult {
  final List<Neighbor> neighbors;
  final double probability;
  final bool exactOnly;
  NeighborResult._(List<Neighbor> n, this.probability, this.exactOnly)
    : neighbors = List.unmodifiable(n);
  factory NeighborResult.compute(
    List<ClassicalPoint> pool,
    List<double> query, {
    required int k,
    required List<double> scale,
    bool standardized = true,
    bool weighted = false,
    int p = 2,
  }) {
    finitePair(query);
    finitePair(scale);
    if (pool.isEmpty ||
        k < 1 ||
        k > pool.length ||
        ![1, 2].contains(p) ||
        scale.any((v) => v <= 0)) {
      throw ArgumentError(
        'Valid k, metric and positive training scales required.',
      );
    }
    final ranked = <({ClassicalPoint point, double distance, int order})>[];
    for (var i = 0; i < pool.length; i++) {
      final point = pool[i];
      final dx =
              (point.values[0] - query[0]).abs() /
              (standardized ? scale[0] : 1),
          dy =
              (point.values[1] - query[1]).abs() /
              (standardized ? scale[1] : 1);
      final distance = p == 1 ? dx + dy : sqrt(dx * dx + dy * dy);
      if (!distance.isFinite) throw ArgumentError('Distance overflow');
      ranked.add((point: point, distance: distance, order: i));
    }
    ranked.sort((a, b) {
      final c = a.distance.compareTo(b.distance);
      return c == 0 ? a.order.compareTo(b.order) : c;
    });
    final selected = ranked.take(k).toList();
    final zero = weighted && selected.first.distance == 0;
    final minimum = selected.first.distance;
    final neighbors = [
      for (final n in selected)
        Neighbor(
          n.point,
          n.distance,
          !weighted
              ? 1
              : zero
              ? (n.distance == 0 ? 1 : 0)
              : minimum / n.distance,
        ),
    ];
    final total = neighbors.fold(0.0, (a, b) => a + b.weight);
    final positive = neighbors.fold(
      0.0,
      (a, b) => a + b.weight * b.point.positive,
    );
    return NeighborResult._(neighbors, positive / total, zero);
  }
}

class GaussianResult {
  final List<double> joint, logProbability;
  final List<List<double>> contributions;
  GaussianResult._(this.joint, this.logProbability, this.contributions);
  double get positiveProbability => exp(logProbability[1]);
  factory GaussianResult.compute(
    List<double> query,
    List<List<double>> means,
    List<List<double>> variances,
    double positivePrior, {
    int mode = 0,
  }) {
    finitePair(query);
    if (means.length != 2 ||
        variances.length != 2 ||
        !positivePrior.isFinite ||
        positivePrior <= 0 ||
        positivePrior >= 1 ||
        mode < 0 ||
        mode > 2) {
      throw ArgumentError('Gaussian shape/prior/feature mode');
    }
    for (final row in [...means, ...variances]) {
      finitePair(row);
    }
    if (variances.expand((v) => v).any((x) => x <= 0)) {
      throw ArgumentError('Positive Gaussian variance required.');
    }
    final contributions = [
      for (var c = 0; c < 2; c++)
        [
          for (var j = 0; j < 2; j++)
            -.5 *
                (log(2 * pi * variances[c][j]) +
                    pow(query[j] - means[c][j], 2) / variances[c][j]),
        ],
    ];
    final joint = [
      for (var c = 0; c < 2; c++)
        log(c == 1 ? positivePrior : 1 - positivePrior) +
            (mode == 2 ? 0 : contributions[c][0]) +
            (mode == 1 ? 0 : contributions[c][1]),
    ];
    if (joint.any((v) => !v.isFinite)) {
      throw ArgumentError('Nonfinite Gaussian score');
    }
    final maximum = joint.reduce(max);
    final normalizer =
        maximum + log(exp(joint[0] - maximum) + exp(joint[1] - maximum));
    return GaussianResult._(
      List.unmodifiable(joint),
      List.unmodifiable(joint.map((s) => s - normalizer)),
      List.unmodifiable(contributions.map((r) => List<double>.unmodifiable(r))),
    );
  }
}

class ClassicalAssets {
  static ClassicalAssets? _loaded;
  final List<ClassicalPoint> svmPoints, svmQueries, pool, knnQueries, nbQueries;
  final List<SvmSnapshot> snapshots;
  final List<double> svmMean, svmScale, knnScale, priors;
  final List<List<double>> means, variances;
  final double epsilon;
  final int svmTrainingRows;
  ClassicalAssets._(
    this.svmPoints,
    this.svmQueries,
    this.pool,
    this.knnQueries,
    this.nbQueries,
    this.snapshots,
    this.svmMean,
    this.svmScale,
    this.knnScale,
    this.priors,
    this.means,
    this.variances,
    this.epsilon,
    this.svmTrainingRows,
  );
  List<double> standardize(List<double> x) =>
      List.generate(2, (j) => (x[j] - svmMean[j]) / svmScale[j]);
  static Future<ClassicalAssets> load() async {
    if (_loaded != null) return _loaded!;
    final raw = await Future.wait([
      for (final name in ['svm', 'knn', 'nb'])
        rootBundle.loadString(
          'assets/datasets/adult/classical_${name}_lab.json',
        ),
    ]);
    final assets = ClassicalAssets.fromJson(
      jsonDecode(raw[0]),
      jsonDecode(raw[1]),
      jsonDecode(raw[2]),
    );
    _loaded = assets;
    return assets;
  }

  factory ClassicalAssets.fromJson(
    Map<String, dynamic> svm,
    Map<String, dynamic> knn,
    Map<String, dynamic> nb,
  ) {
    const hash =
        '5b00264637dbfec36bdeaab5676b0b309ff9eb788d63554ca0a249491c86603d';
    if ([svm, knn, nb].any((j) => j['sha256'] != hash)) {
      throw FormatException('Expected original Adult source.');
    }
    List<ClassicalPoint> points(List raw) =>
        List.unmodifiable(raw.map((j) => ClassicalPoint.fromJson(j)));
    final sPoints = points(svm['points']),
        sQueries = points(svm['queries']),
        pool = points(knn['pool']),
        kQueries = points(knn['queries']),
        nQueries = points(nb['queries']);
    final snapshots = List<SvmSnapshot>.unmodifiable([
      for (final j in svm['snapshots']) SvmSnapshot.fromJson(j),
    ]);
    final sMean = vector(svm['mean']),
        sScale = vector(svm['scale']),
        kScale = vector(knn['scale']),
        priors = vector(nb['priors']);
    final means = matrix(nb['means']), vars = matrix(nb['variances']);
    final epsilon = (nb['epsilon'] as num).toDouble();
    final int n = svm['training_rows'];
    for (final v in [sMean, sScale, kScale, priors]) {
      finitePair(v);
    }
    if ([sPoints, sQueries, pool, kQueries, nQueries].any(
          (p) =>
              p.isEmpty || p.map((v) => v.sourceRow).toSet().length != p.length,
        ) ||
        snapshots.length < 2 ||
        n < sPoints.length ||
        sScale.any((x) => x <= 0) ||
        kScale.any((x) => x <= 0) ||
        priors.any((x) => x <= 0) ||
        (priors[0] + priors[1] - 1).abs() > 1e-9 ||
        !epsilon.isFinite ||
        epsilon < 0 ||
        snapshots.any(
          (s) => s.supportFlags.length != sPoints.length || s.supportCount > n,
        )) {
      throw FormatException('Invalid classical lab data.');
    }
    for (final point in nQueries) {
      GaussianResult.compute(point.values, means, vars, priors[1]);
    }
    return ClassicalAssets._(
      sPoints,
      sQueries,
      pool,
      kQueries,
      nQueries,
      snapshots,
      sMean,
      sScale,
      kScale,
      priors,
      means,
      vars,
      epsilon,
      n,
    );
  }
}
