import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

import '../capstone/capstone_model.dart'
    show ValidationPrediction, PolicyResult, bestPolicyThreshold, stableSigmoid;

const whiteFeatures = [
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
List<double> _v(dynamic x) =>
    List<double>.unmodifiable((x as List).map((v) => (v as num).toDouble()));
List<List<double>> _m(dynamic x) =>
    List<List<double>>.unmodifiable((x as List).map(_v));
void _finite(List<double> x) {
  if (x.isEmpty || x.any((v) => !v.isFinite)) {
    throw ArgumentError('Finite nonempty capstone values');
  }
}

bool _schema(List<String> names) =>
    names.length == 11 &&
    List.generate(11, (i) => names[i] == whiteFeatures[i]).every((v) => v);

class DeepTrace {
  final List<double> standardized, pre, hidden;
  final double logit, probability;
  DeepTrace(List<double> x, List<double> p, List<double> h, this.logit)
    : standardized = List.unmodifiable(x),
      pre = List.unmodifiable(p),
      hidden = List.unmodifiable(h),
      probability = stableSigmoid(logit);
}

class DeepPipeline {
  final String id;
  final List<double> mean, scale, b1, w2, loss;
  final List<List<double>> w1;
  final double b2;
  DeepPipeline.fromJson(Map<String, dynamic> j)
    : id = j['id'],
      mean = _v(j['mean']),
      scale = _v(j['scale']),
      w1 = _m(j['weights']['w1']),
      b1 = _v(j['weights']['b1']),
      w2 = _v(j['weights']['w2']),
      b2 = (j['weights']['b2'] as num).toDouble(),
      loss = List<double>.unmodifiable(
        (j['history'] as List).map((r) => (r['train_bce'] as num).toDouble()),
      ) {
    if (!['scaled', 'no_scale'].contains(id) ||
        mean.length != 11 ||
        scale.length != 11 ||
        w1.length != 8 ||
        w1.any((r) => r.length != 11) ||
        b1.length != 8 ||
        w2.length != 8 ||
        scale.any((v) => v <= 0) ||
        loss.length != 81 ||
        loss.any((v) => v < 0)) {
      throw const FormatException('White-wine 11→8→1 pipeline');
    }
    for (final r in [
      ...w1,
      mean,
      scale,
      b1,
      w2,
      loss,
      [b2],
    ]) {
      _finite(r);
    }
    for (var i = 0; i < 81; i++) {
      if (j['history'][i]['epoch'] != i) {
        throw const FormatException('Fixed80-update training history');
      }
    }
    if (id == 'no_scale' &&
        (mean.any((v) => v != 0) || scale.any((v) => v != 1))) {
      throw const FormatException('No-scale ablation transform');
    }
  }
  DeepTrace forward(List<double> raw, {List<String> names = whiteFeatures}) {
    if (!_schema(names) || raw.length != 11) {
      throw const FormatException('Exact ordered11-feature contract');
    }
    _finite(raw);
    final x = List.generate(11, (i) => (raw[i] - mean[i]) / scale[i]);
    _finite(x);
    final pre = List.generate(
      8,
      (i) =>
          b1[i] +
          List.generate(11, (j) => w1[i][j] * x[j]).fold(0.0, (a, b) => a + b),
    );
    _finite(pre);
    final h = pre.map((v) => max(0.0, v)).toList(),
        z =
            b2 +
            List.generate(8, (i) => h[i] * w2[i]).fold(0.0, (a, b) => a + b);
    _finite([z]);
    return DeepTrace(x, pre, h, z);
  }
}

class DeepCandidate {
  final String id;
  final int order;
  final List<double> foldAp;
  final double meanAp;
  DeepCandidate.fromJson(Map<String, dynamic> j)
    : id = j['id'],
      order = j['declared_order'],
      foldAp = _v(j['fold_ap']),
      meanAp = (j['mean_ap'] as num).toDouble() {
    _finite([...foldAp, meanAp]);
    if (!['prior', 'logistic', 'mlp'].contains(id) ||
        order != ['prior', 'logistic', 'mlp'].indexOf(id) ||
        foldAp.length != 3 ||
        foldAp.any((v) => v < 0 || v > 1) ||
        (foldAp.reduce((a, b) => a + b) / 3 - meanAp).abs() > 1e-12) {
      throw const FormatException('Grouped fit-only CV evidence');
    }
  }
}

String selectDeepWinner(List<DeepCandidate> candidates) {
  if (candidates.length != 3 ||
      candidates.map((c) => c.id).toSet().length != 3) {
    throw const FormatException('Three declared candidates');
  }
  final sorted = [...candidates]
    ..sort((a, b) {
      final score = b.meanAp.compareTo(a.meanAp);
      return score == 0 ? a.order.compareTo(b.order) : score;
    });
  return sorted.first.id;
}

class DeepSample {
  final int sourceRow, quality;
  final List<double> raw;
  DeepSample.fromJson(Map<String, dynamic> j)
    : sourceRow = j['source_row_1based'],
      quality = j['quality'],
      raw = _v(j['raw']) {
    _finite(raw);
    if (sourceRow < 1 ||
        sourceRow > 4898 ||
        quality < 0 ||
        quality > 10 ||
        raw.length != 11) {
      throw const FormatException('Actual white-wine sample');
    }
  }
}

class DeepCapstoneAssets {
  final List<String> features;
  final Map<String, DeepPipeline> pipelines;
  final List<DeepCandidate> candidates;
  final List<DeepSample> samples;
  final List<ValidationPrediction> decisions;
  final List<int> fitIds, decisionIds;
  final Map<String, int> roleRows;
  final String winner;
  final double threshold, mlpDecisionAp, noScaleDecisionAp;
  DeepCapstoneAssets.fromJson(Map<String, dynamic> j)
    : features = List.unmodifiable(List<String>.from(j['features'])),
      pipelines = Map.unmodifiable({
        for (final p in j['pipelines'] as List)
          p['id'] as String: DeepPipeline.fromJson(p),
      }),
      candidates = List.unmodifiable(
        (j['selection']['candidates'] as List).map(
          (c) => DeepCandidate.fromJson(c),
        ),
      ),
      samples = List.unmodifiable(
        (j['samples'] as List).map((s) => DeepSample.fromJson(s)),
      ),
      decisions = List.unmodifiable(
        (j['decision_rows'] as List).map(
          (r) => ValidationPrediction.fromJson(r),
        ),
      ),
      fitIds = List.unmodifiable(List<int>.from(j['fit_rows_1based'])),
      decisionIds = List.unmodifiable(
        List<int>.from(j['decision_rows_1based']),
      ),
      roleRows = Map.unmodifiable({
        for (final k in ['fit', 'decision', 'test'])
          k: j['roles'][k]['rows'] as int,
      }),
      winner = j['selection']['winner'],
      threshold = (j['selection']['threshold'] as num).toDouble(),
      mlpDecisionAp = (j['decision_metrics']['mlp']['ap'] as num).toDouble(),
      noScaleDecisionAp = (j['no_scale_metrics']['ap'] as num).toDouble() {
    _finite([mlpDecisionAp, noScaleDecisionAp]);
    if ([mlpDecisionAp, noScaleDecisionAp].any((v) => v < 0 || v > 1)) {
      throw const FormatException('Diagnostic AP range');
    }
    if (!_schema(features) ||
        j['dtype'] != 'float64' ||
        j['parameter_count'] != 105 ||
        j['selection']['test_rows_in_labs'] != 0 ||
        pipelines.length != 2 ||
        !pipelines.containsKey('scaled') ||
        !pipelines.containsKey('no_scale') ||
        selectDeepWinner(candidates) != winner ||
        !threshold.isFinite ||
        threshold < .05 ||
        threshold > .95 ||
        (threshold * 20 - (threshold * 20).round()).abs() > 1e-10 ||
        roleRows.values.reduce((a, b) => a + b) != 4898 ||
        roleRows.values.any((n) => n < 1)) {
      throw const FormatException('Locked deep capstone evidence');
    }
    if (fitIds.length != roleRows['fit'] ||
        decisionIds.length != roleRows['decision'] ||
        fitIds.toSet().length != fitIds.length ||
        decisionIds.toSet().length != decisionIds.length ||
        fitIds.toSet().intersection(decisionIds.toSet()).isNotEmpty ||
        [...fitIds, ...decisionIds].any((i) => i < 1 || i > 4898)) {
      throw const FormatException('Distinct source roles');
    }
    if (decisions.length != decisionIds.length ||
        decisions.map((d) => d.sourceRow).toSet().length !=
            decisionIds.length ||
        decisions.any((d) => !decisionIds.contains(d.sourceRow)) ||
        samples.length != 3 ||
        samples.map((s) => s.sourceRow).toSet().length != 3 ||
        samples.any((s) => !decisionIds.contains(s.sourceRow)) ||
        (bestPolicyThreshold(decisions) - threshold).abs() > 1e-12) {
      throw const FormatException('Decision-only rows and locked policy');
    }
  }
  PolicyResult policy(double t, {double costFn = 4}) =>
      PolicyResult.compute(decisions, t, costFn: costFn);
  double inspectBestThreshold({double costFn = 4}) =>
      bestPolicyThreshold(decisions, costFn: costFn);
  static DeepCapstoneAssets? _cache;
  static Future<DeepCapstoneAssets> load() async =>
      _cache ??= DeepCapstoneAssets.fromJson(
        jsonDecode(
          await rootBundle.loadString(
            'assets/datasets/wine_quality/deep_capstone_lab.json',
          ),
        ),
      );
}
