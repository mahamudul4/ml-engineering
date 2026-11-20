import 'dart:math' as math;

class ClassificationModel {
  static double sigmoid(double z) {
    if (!z.isFinite) throw ArgumentError('Finite logit required');
    if (z >= 0) return 1 / (1 + math.exp(-z));
    final e = math.exp(z);
    return e / (1 + e);
  }

  static double logLoss(double z, int label) {
    if (!z.isFinite || (label != 0 && label != 1)) {
      throw ArgumentError('Finite logit and binary label required');
    }
    return math.max(z, 0) - label * z + math.log(1 + math.exp(-z.abs()));
  }

  static List<double> softmax(List<double> logits) {
    if (logits.isEmpty || logits.any((v) => !v.isFinite)) {
      throw ArgumentError('Finite non-empty logits required');
    }
    final top = logits.reduce(math.max);
    final terms = logits.map((z) => math.exp(z - top)).toList();
    final sum = terms.reduce((a, b) => a + b);
    return terms.map((v) => v / sum).toList();
  }

  /// Intersections of the z=0 line with [0,4]²; safe for vertical/zero weights.
  static List<(double, double)> boundary(double w1, double w2, double bias) {
    if ([w1, w2, bias].any((v) => !v.isFinite)) {
      throw ArgumentError('Finite parameters required');
    }
    if (w1 == 0 && w2 == 0) return [];
    const corners = [(0.0, 0.0), (4.0, 0.0), (4.0, 4.0), (0.0, 4.0)];
    final result = <(double, double)>[];
    void add((double, double) p) {
      if (!result.any(
        (q) => (p.$1 - q.$1).abs() < 1e-9 && (p.$2 - q.$2).abs() < 1e-9,
      )) {
        result.add(p);
      }
    }

    for (var i = 0; i < 4; i++) {
      final a = corners[i], b = corners[(i + 1) % 4];
      final za = w1 * a.$1 + w2 * a.$2 + bias,
          zb = w1 * b.$1 + w2 * b.$2 + bias;
      if (za == 0) add(a);
      if (zb == 0) add(b);
      if ((za < 0 && zb > 0) || (za > 0 && zb < 0)) {
        final t = -za / (zb - za);
        add((a.$1 + t * (b.$1 - a.$1), a.$2 + t * (b.$2 - a.$2)));
      }
    }
    return result;
  }
}

class ConfusionMetrics {
  final int tp, fp, fn, tn;
  const ConfusionMetrics._(this.tp, this.fp, this.fn, this.tn);
  int get total => tp + fp + fn + tn;
  int get predictedPositive => tp + fp;
  double get accuracy => (tp + tn) / total;
  double? get precision => tp + fp == 0 ? null : tp / (tp + fp);
  double? get recall => tp + fn == 0 ? null : tp / (tp + fn);
  double? get f1 => 2 * tp + fp + fn == 0 ? null : 2 * tp / (2 * tp + fp + fn);
  factory ConfusionMetrics.evaluate(
    List<int> labels,
    List<double> scores,
    double threshold,
  ) {
    if (labels.isEmpty ||
        labels.length != scores.length ||
        labels.any((v) => v != 0 && v != 1) ||
        scores.any((v) => !v.isFinite || v < 0 || v > 1) ||
        !threshold.isFinite ||
        threshold < 0 ||
        threshold > 1) {
      throw ArgumentError(
        'Binary labels, probabilities and a threshold in [0,1] required',
      );
    }
    int tp = 0, fp = 0, fn = 0, tn = 0;
    for (var i = 0; i < labels.length; i++) {
      final positive = scores[i] >= threshold;
      if (labels[i] == 1) {
        if (positive) {
          tp++;
        } else {
          fn++;
        }
      } else {
        if (positive) {
          fp++;
        } else {
          tn++;
        }
      }
    }
    return ConfusionMetrics._(tp, fp, fn, tn);
  }
}

class ThresholdDemo {
  static const labels = [0, 0, 1, 0, 1, 0, 1, 1, 0, 1];
  static const scores = [.05, .15, .25, .35, .45, .55, .65, .75, .85, .95];
}
