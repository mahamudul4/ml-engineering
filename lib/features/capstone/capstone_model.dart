import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

List<double> _vector(dynamic values) =>
    List.unmodifiable((values as List).map((v) => (v as num).toDouble()));
void _finite(List<double> values) {
  if (values.isEmpty || values.any((v) => !v.isFinite)) {
    throw ArgumentError('Finite nonempty vector');
  }
}

double stableSigmoid(double score) {
  if (!score.isFinite) throw ArgumentError('Finite logit required');
  if (score >= 0) return 1 / (1 + exp(-score));
  final z = exp(score);
  return z / (1 + z);
}

class ValidationPrediction {
  final int sourceRow, quality, positive;
  final double probability;
  ValidationPrediction.fromJson(Map<String, dynamic> j)
    : sourceRow = j['source_row_1based'],
      quality = j['quality'],
      positive = j['positive'],
      probability = (j['probability'] as num).toDouble() {
    if (sourceRow < 1 ||
        quality < 0 ||
        quality > 10 ||
        positive != (quality >= 6 ? 1 : 0) ||
        !probability.isFinite ||
        probability < 0 ||
        probability > 1) {
      throw const FormatException('Invalid source prediction');
    }
  }
}

class PolicyResult {
  final int tn, fp, fn, tp;
  final double meanCost;
  const PolicyResult._(this.tn, this.fp, this.fn, this.tp, this.meanCost);
  factory PolicyResult.compute(
    List<ValidationPrediction> rows,
    double threshold, {
    double costFp = 1,
    double costFn = 4,
  }) {
    if (rows.isEmpty ||
        !threshold.isFinite ||
        threshold < 0 ||
        threshold > 1 ||
        !costFp.isFinite ||
        !costFn.isFinite ||
        min(costFp, costFn) < 0) {
      throw ArgumentError(
        'Valid probabilities, threshold and nonnegative costs',
      );
    }
    var tn = 0, fp = 0, fn = 0, tp = 0;
    for (final r in rows) {
      final predicted = r.probability >= threshold;
      if (r.positive == 1) {
        if (predicted) {
          tp++;
        } else {
          fn++;
        }
      } else {
        if (predicted) {
          fp++;
        } else {
          tn++;
        }
      }
    }
    final cost = (costFp * fp + costFn * fn) / rows.length;
    if (!cost.isFinite) throw ArgumentError('Cost overflow');
    return PolicyResult._(tn, fp, fn, tp, cost);
  }
  int get n => tn + fp + fn + tp;
  double? get precision => tp + fp == 0 ? null : tp / (tp + fp);
  double? get recall => tp + fn == 0 ? null : tp / (tp + fn);
  double? get specificity => tn + fp == 0 ? null : tn / (tn + fp);
  double get accuracy => (tp + tn) / n;
}

double bestPolicyThreshold(
  List<ValidationPrediction> rows, {
  double costFn = 4,
}) {
  var threshold = .05, best = double.infinity;
  for (var i = 1; i < 20; i++) {
    final tau = i / 20,
        cost = PolicyResult.compute(rows, tau, costFn: costFn).meanCost;
    // Ascending candidates: <= implements the declared highest-threshold tie.
    if (cost <= best) {
      best = cost;
      threshold = tau;
    }
  }
  return threshold;
}

class CandidateResult {
  final String id, label;
  final List<double> foldAp;
  final double meanAp, foldSd;
  CandidateResult.fromJson(Map<String, dynamic> j)
    : id = j['id'],
      label = j['label'],
      foldAp = _vector(j['fold_ap']),
      meanAp = (j['mean_ap'] as num).toDouble(),
      foldSd = (j['fold_sd'] as num).toDouble() {
    _finite(foldAp);
    if (foldAp.length != 3 ||
        foldAp.any((v) => v < 0 || v > 1) ||
        !meanAp.isFinite ||
        !foldSd.isFinite ||
        foldSd < 0 ||
        (foldAp.reduce((a, b) => a + b) / 3 - meanAp).abs() > 1e-10) {
      throw const FormatException('Invalid grouped CV result');
    }
  }
}

class PipelineObservation {
  final int sourceRow, quality, positive;
  final List<double> values;
  final double referenceLogit, referenceProbability;
  PipelineObservation.fromJson(Map<String, dynamic> j)
    : sourceRow = j['source_row_1based'],
      quality = j['quality'],
      positive = j['positive'],
      values = _vector(j['values']),
      referenceLogit = (j['logit'] as num).toDouble(),
      referenceProbability = (j['probability'] as num).toDouble() {
    _finite(values);
    if (sourceRow < 1 ||
        quality < 0 ||
        quality > 10 ||
        positive != (quality >= 6 ? 1 : 0) ||
        !referenceLogit.isFinite ||
        !referenceProbability.isFinite ||
        referenceProbability < 0 ||
        referenceProbability > 1) {
      throw const FormatException('Invalid pipeline observation');
    }
  }
}

class LogisticReference {
  final String modelId;
  final List<String> features;
  final List<double> mean, scale, weights;
  final double bias;
  final List<PipelineObservation> queries;
  LogisticReference.fromJson(Map<String, dynamic> j)
    : modelId = j['model_id'],
      features = List.unmodifiable(List<String>.from(j['feature_names'])),
      mean = _vector(j['mean']),
      scale = _vector(j['scale']),
      weights = _vector(j['weights']),
      bias = (j['bias'] as num).toDouble(),
      queries = List.unmodifiable(
        (j['queries'] as List).map((q) => PipelineObservation.fromJson(q)),
      ) {
    _finite(mean);
    _finite(scale);
    _finite(weights);
    if (!bias.isFinite ||
        features.isEmpty ||
        features.toSet().length != features.length ||
        [
          mean.length,
          scale.length,
          weights.length,
        ].any((n) => n != features.length) ||
        scale.any((v) => v <= 0) ||
        queries.isEmpty) {
      throw const FormatException('Invalid fitted feature contract');
    }
    for (final q in queries) {
      if ((logit(q.values) - q.referenceLogit).abs() > 1e-9 ||
          (probability(q.values) - q.referenceProbability).abs() > 1e-10) {
        throw const FormatException('Pipeline reference mismatch');
      }
    }
  }
  List<double> standardize(List<double> x) {
    _finite(x);
    if (x.length != features.length) {
      throw ArgumentError('Ordered feature schema mismatch');
    }
    final z = [for (var i = 0; i < x.length; i++) (x[i] - mean[i]) / scale[i]];
    _finite(z);
    return List.unmodifiable(z);
  }

  List<double> contributions(List<double> x) {
    final z = standardize(x),
        terms = [for (var i = 0; i < z.length; i++) z[i] * weights[i]];
    _finite(terms);
    return List.unmodifiable(terms);
  }

  double logit(List<double> x) {
    final s = bias + contributions(x).fold(0.0, (a, b) => a + b);
    if (!s.isFinite) throw ArgumentError('Logit overflow');
    return s;
  }

  double probability(List<double> x) => stableSigmoid(logit(x));
}

class CapstoneAssets {
  final List<CandidateResult> candidates;
  final List<ValidationPrediction> rows;
  final String selectedId;
  final double lockedThreshold;
  final LogisticReference pipeline;
  CapstoneAssets.fromJson(Map<String, dynamic> j)
    : candidates = List.unmodifiable(
        (j['candidates'] as List).map((v) => CandidateResult.fromJson(v)),
      ),
      rows = List.unmodifiable(
        (j['decision_predictions'] as List).map(
          (v) => ValidationPrediction.fromJson(v),
        ),
      ),
      selectedId = j['selected_id'],
      lockedThreshold = (j['locked_threshold'] as num).toDouble(),
      pipeline = LogisticReference.fromJson(j['logistic_reference']) {
    if (candidates.isEmpty ||
        candidates.map((c) => c.id).toSet().length != candidates.length ||
        rows.isEmpty ||
        rows.map((r) => r.sourceRow).toSet().length != rows.length ||
        !lockedThreshold.isFinite ||
        lockedThreshold < 0 ||
        lockedThreshold > 1 ||
        !candidates.any((c) => c.id == selectedId)) {
      throw const FormatException('Invalid capstone manifest');
    }
    final highest = candidates.map((c) => c.meanAp).reduce(max);
    if ((candidates[selectedIndex].meanAp - highest).abs() > 1e-10 ||
        (bestPolicyThreshold(rows) - lockedThreshold).abs() > 1e-10) {
      throw const FormatException('Selection or policy contract mismatch');
    }
    final byRow = {for (final r in rows) r.sourceRow: r};
    for (final q in pipeline.queries) {
      final original = byRow[q.sourceRow];
      if (original == null ||
          original.quality != q.quality ||
          original.positive != q.positive) {
        throw const FormatException('Query outside decision role');
      }
    }
  }
  int get selectedIndex => candidates.indexWhere((c) => c.id == selectedId);
  static CapstoneAssets? _cached;
  static Future<CapstoneAssets> load() async {
    if (_cached != null) return _cached!;
    final j = jsonDecode(
      await rootBundle.loadString(
        'assets/datasets/wine_quality/capstone_lab.json',
      ),
    ) as Map<String, dynamic>;
    final parsed = CapstoneAssets.fromJson(j);
    _cached = parsed;
    return parsed;
  }
}
