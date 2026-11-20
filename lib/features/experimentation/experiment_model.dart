import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

const experimentOutcomes = ['earnings', 'positive'];
const experimentConfidences = [.9, .95, .99];
Map<String, dynamic> experimentSummary(List<double> values) {
  if (values.length < 2 || values.any((x) => !x.isFinite)) {
    throw ArgumentError('At least two finite units required');
  }
  final n = values.length, mean = values.reduce((a, b) => a + b) / n;
  return {
    'n': n,
    'mean': mean,
    'variance':
        values.fold(0.0, (s, v) => s + (v - mean) * (v - mean)) / (n - 1),
  };
}

List<double> experimentValues(List<dynamic> rows, String outcome) {
  if (!experimentOutcomes.contains(outcome)) {
    throw ArgumentError('Unknown outcome');
  }
  return [
    for (final r in rows)
      outcome == 'earnings'
          ? (r['re78'] as num).toDouble()
          : (r['re78'] > 0 ? 1.0 : 0.0),
  ];
}

Map<String, dynamic> experimentWelch(
  List<double> treated,
  List<double> control, {
  required double critical,
  required double confidence,
}) {
  if (!critical.isFinite ||
      critical <= 0 ||
      confidence <= 0 ||
      confidence >= 1) {
    throw ArgumentError('Invalid interval');
  }
  final t = experimentSummary(treated),
      c = experimentSummary(control),
      a = t['variance'] / t['n'],
      b = c['variance'] / c['n'],
      se = math.sqrt(a + b),
      delta = t['mean'] - c['mean'];
  if (se == 0) {
    throw ArgumentError('No sampling variance');
  }
  final df = (a + b) * (a + b) / (a * a / (t['n'] - 1) + b * b / (c['n'] - 1));
  return {
    'treated': t,
    'control': c,
    'delta': delta,
    'se': se,
    'df': df,
    'critical': critical,
    'confidence': confidence,
    'lower': delta - critical * se,
    'upper': delta + critical * se,
    'relative': c['mean'] == 0 ? null : delta / c['mean'],
  };
}

List<double> experimentHolm(List<double> values) {
  if (values.any((p) => !p.isFinite || p < 0 || p > 1)) {
    throw ArgumentError('Invalid p-value');
  }
  final order = List<int>.generate(values.length, (i) => i)
    ..sort((a, b) {
      final c = values[a].compareTo(values[b]);
      return c == 0 ? a.compareTo(b) : c;
    });
  final adjusted = List<double>.filled(values.length, 0);
  var running = 0.0;
  for (var rank = 0; rank < order.length; rank++) {
    final j = order[rank];
    running = math.max(running, math.min(1, (order.length - rank) * values[j]));
    adjusted[j] = running;
  }
  return adjusted;
}

double experimentNormalCdf(double x) {
  final a = x.abs(),
      t = 1 / (1 + .2316419 * a),
      density = math.exp(-a * a / 2) / math.sqrt(2 * math.pi),
      tail =
          density *
          t *
          (.319381530 +
              t *
                  (-.356563782 +
                      t *
                          (1.781477937 +
                              t * (-1.821255978 + t * 1.330274429))));
  return x >= 0 ? 1 - tail : tail;
}

int experimentBucket(String key) {
  var h = 2166136261;
  for (final b in utf8.encode(key)) {
    h = ((h ^ b) * 16777619) & 0xffffffff;
  }
  return h % 10000;
}

Map<String, dynamic> experimentLogging(
  List<dynamic> rows, {
  bool loss = false,
}) {
  final counts = [0, 0];
  var dropped = 0;
  for (var j = 0; j < rows.length; j++) {
    final arm = experimentBucket('ch37-assignment:${rows[j]['key']}') < 5000
        ? 1
        : 0;
    if (loss && arm == 1 && j % 3 == 0) {
      dropped++;
    } else {
      counts[arm]++;
    }
  }
  final total = counts[0] + counts[1];
  if (total == 0) {
    throw ArgumentError('No logged units');
  }
  final expected = total / 2,
      chi = counts.fold(
        0.0,
        (s, n) => s + (n - expected) * (n - expected) / expected,
      ),
      p = 2 * experimentNormalCdf(-math.sqrt(chi));
  return {
    'source_units': rows.length,
    'observed_units': total,
    'control': counts[0],
    'treated': counts[1],
    'dropped': dropped,
    'chi_square': chi,
    'p_value': p,
    'expected_treated': .5,
    'threshold': .001,
    'flag': p < .001,
  };
}

Map<String, dynamic> experimentRandomization(
  List<double> bank,
  double observed,
  int draws,
) {
  if (draws < 1 || draws > bank.length) {
    throw ArgumentError('Invalid draw count');
  }
  final selected = bank.take(draws).toList(),
      tol = 1e-10 * math.max(1, observed.abs()),
      extreme = selected.where((v) => v.abs() >= observed.abs() - tol).length,
      p = (extreme + 1) / (draws + 1),
      lo = math.min(selected.reduce(math.min), observed),
      hi = math.max(selected.reduce(math.max), observed),
      width = hi > lo ? (hi - lo) / 12 : 1.0,
      bins = List<int>.filled(12, 0);
  for (final v in selected) {
    bins[((v - lo) / width).floor().clamp(0, 11)]++;
  }
  return {
    'draws': draws,
    'extreme': extreme,
    'p_value': p,
    'mc_se': math.sqrt(p * (1 - p) / (draws + 1)),
    'minimum': lo,
    'maximum': hi,
    'bins': bins,
  };
}

double? experimentSmd(List<double> a, List<double> b) {
  final ta = experimentSummary(a),
      cb = experimentSummary(b),
      denom = math.sqrt((ta['variance'] + cb['variance']) / 2);
  return denom == 0 ? null : (ta['mean'] - cb['mean']) / denom;
}

class ExperimentAssets {
  final Map<String, dynamic> data;
  final _nullCache = <String, List<double>>{};
  ExperimentAssets(this.data);
  static ExperimentAssets? _cached;
  static Future<ExperimentAssets>? _pending;
  static Future<ExperimentAssets> load() async =>
      _cached ??= await (_pending ??= _load());
  static Future<ExperimentAssets> _load() async => ExperimentAssets(
    jsonDecode(
      await rootBundle.loadString('assets/datasets/nsw/experiment_lab.json'),
    ),
  );
  List<dynamic> get trialRows => [
    ...data['cohorts']['treated'],
    ...data['cohorts']['experimental'],
  ];
  Map<String, dynamic> trial(String outcome, double confidence) {
    final ref = data['trial'][outcome]['$confidence'];
    return {
      ...experimentWelch(
        experimentValues(data['cohorts']['treated'], outcome),
        experimentValues(data['cohorts']['experimental'], outcome),
        critical: ref['critical'],
        confidence: confidence,
      ),
      'p_value': ref['p_value'],
    };
  }

  List<double> nullValues(String outcome) =>
      _nullCache.putIfAbsent(outcome, () {
        final y = experimentValues(trialRows, outcome),
            total = y.reduce((a, b) => a + b);
        return [
          for (final r in data['permutation_bank'])
            _permuted(r['treated_indices'], y, total),
        ];
      });
  double _permuted(List<dynamic> indices, List<double> y, double total) {
    final sum = indices.fold(0.0, (s, i) => s + y[i as int]);
    return sum / indices.length - (total - sum) / (y.length - indices.length);
  }

  Map<String, dynamic> randomization(String outcome, int draws) =>
      experimentRandomization(
        nullValues(outcome),
        trial(outcome, .95)['delta'],
        draws,
      );
  Map<String, dynamic> plan({
    int delta = 2000,
    double allocation = .5,
    double alpha = .05,
    double power = .8,
    int clusterSize = 1,
    double icc = 0,
  }) {
    if (![1000, 2000, 4000].contains(delta) ||
        ![.4, .5, .7].contains(allocation) ||
        ![.05, .01].contains(alpha) ||
        ![.8, .9].contains(power) ||
        clusterSize < 1 ||
        icc < 0 ||
        icc >= 1) {
      throw ArgumentError('Unknown design assumptions');
    }
    final sigma = (data['planning_sigma'] as num).toDouble(),
        za = (data['normal_quantiles'][alpha == .05 ? '0.975' : '0.995'] as num)
            .toDouble(),
        zb = (data['normal_quantiles']['$power'] as num).toDouble(),
        total =
            sigma *
            sigma *
            (za + zb) *
            (za + zb) /
            (delta * delta * allocation * (1 - allocation)),
        de = 1 + (clusterSize - 1) * icc,
        n1 = math.max(2, (total * allocation).ceil()),
        n0 = math.max(2, (total * (1 - allocation)).ceil()),
        adjusted = ((n1 + n0) * de).ceil(),
        mu = delta / (sigma * math.sqrt(1 / n1 + 1 / n0));
    return {
      'sigma': sigma,
      'delta': delta,
      'allocation': allocation,
      'alpha': alpha,
      'power_target': power,
      'z_alpha': za,
      'z_power': zb,
      'unrounded_total': total,
      'treated': n1,
      'control': n0,
      'total': n1 + n0,
      'achieved_normal_power':
          experimentNormalCdf(mu - za) + experimentNormalCdf(-mu - za),
      'cluster_size': clusterSize,
      'icc': icc,
      'design_effect': de,
      'adjusted_units': adjusted,
      'clusters': (adjusted / clusterSize).ceil(),
    };
  }

  Map<String, dynamic> observational({
    String comparison = 'psid',
    String outcome = 'earnings',
    bool adjust = false,
  }) {
    if (!['experimental', 'psid'].contains(comparison)) {
      throw ArgumentError('Unknown comparison');
    }
    final t = data['cohorts']['treated'] as List,
        c = data['cohorts'][comparison] as List,
        ty = experimentValues(t, outcome),
        cy = experimentValues(c, outcome),
        raw =
            ty.reduce((a, b) => a + b) / ty.length -
            cy.reduce((a, b) => a + b) / cy.length,
        strata = <Map<String, dynamic>>[];
    var adjusted = 0.0, overlap = true;
    for (final positive in [false, true]) {
      final tr = t.where((r) => (r['re74'] > 0) == positive).toList(),
          cr = c.where((r) => (r['re74'] > 0) == positive).toList(),
          weight = tr.length / t.length,
          tm = tr.isEmpty
              ? null
              : experimentValues(tr, outcome).reduce((a, b) => a + b) /
                    tr.length,
          cm = cr.isEmpty
              ? null
              : experimentValues(cr, outcome).reduce((a, b) => a + b) /
                    cr.length,
          gap = tm == null || cm == null ? null : tm - cm;
      if (weight > 0 && gap == null) {
        overlap = false;
      }
      if (gap != null) {
        adjusted += weight * gap;
      }
      strata.add({
        'prior_positive': positive,
        'treated': tr.length,
        'control': cr.length,
        'weight': weight,
        'treated_mean': tm,
        'control_mean': cm,
        'gap': gap,
      });
    }
    return {
      'comparison': comparison,
      'outcome': outcome,
      'treated': t.length,
      'control': c.length,
      'raw_gap': raw,
      'adjusted_gap': overlap ? adjusted : null,
      'shown_gap': adjust ? (overlap ? adjusted : null) : raw,
      'adjusted': adjust,
      'empirical_overlap': overlap,
      'strata': strata,
      'smd': {
        for (final k in ['age', 'education', 're74', 're75'])
          k: experimentSmd(
            [for (final r in t) (r[k] as num).toDouble()],
            [for (final r in c) (r[k] as num).toDouble()],
          ),
      },
    };
  }
}
