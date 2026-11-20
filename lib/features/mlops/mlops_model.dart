import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

import '../feature_systems/feature_model.dart';

const mlopsPeriods = {
  'early': (365, 455),
  'late': (456, 546),
  'full': (365, 546),
};
const mlopsInputFields = ['lag1', 'lag7', 'mean7'];
int mlopsBucket(String requestId) {
  var value = 2166136261;
  for (final byte in utf8.encode(requestId)) {
    value = ((value ^ byte) * 16777619) & 0xffffffff;
  }
  return value % 10000;
}

bool mlopsValidModel(Map<String, dynamic> model) {
  if (model['model_version'] is! String ||
      (model['model_version'] as String).isEmpty) {
    return false;
  }
  final fields = model['input_fields'];
  if (model['kind'] == 'seasonal7') {
    return fields is List && fields.length == 1 && fields.first == 'lag7';
  }
  if (model['kind'] != 'ridge' ||
      fields is! List ||
      fields.join('|') != mlopsInputFields.join('|')) {
    return false;
  }
  for (final key in ['weights', 'mean', 'scale']) {
    final values = model[key];
    if (values is! List ||
        values.length != 3 ||
        values.any((v) => v is! num || !v.isFinite)) {
      return false;
    }
  }
  return (model['scale'] as List).every((v) => v > 0) &&
      model['intercept'] is num &&
      (model['intercept'] as num).isFinite;
}

double? mlopsPredict(
  Map<String, dynamic> model,
  Map<String, dynamic> features,
) {
  if (!mlopsValidModel(model)) {
    return null;
  }
  final fields = List<String>.from(model['input_fields']);
  if (fields.any(
    (k) => features[k] is! num || !(features[k] as num).isFinite,
  )) {
    return null;
  }
  if (model['kind'] == 'seasonal7') {
    return (features['lag7'] as num).toDouble();
  }
  var raw = (model['intercept'] as num).toDouble();
  for (var j = 0; j < fields.length; j++) {
    raw +=
        (model['weights'][j] as num) *
        ((features[fields[j]] as num) - (model['mean'][j] as num)) /
        (model['scale'][j] as num);
  }
  return math.max(0, raw);
}

List<String> mlopsContractErrors(
  Map<String, dynamic> expected,
  Map<String, dynamic> loaded,
) => [
  for (final key in [
    'model_version',
    'model_sha256',
    'feature_definition_sha256',
    'source_sha256',
    'input_schema',
  ])
    if (expected[key] != loaded[key]) key,
];
double? mlopsQuantile(List<double> values, double p) {
  if (values.isEmpty) {
    return null;
  }
  final x = [...values]..sort();
  final h = (x.length - 1) * p, lo = h.floor(), hi = h.ceil();
  return x[lo] + (x[hi] - x[lo]) * (h - lo);
}

Map<String, dynamic> mlopsSlo(
  List<dynamic> rows, {
  int threshold = 100,
  double target = .99,
}) {
  if (threshold < 0 || target <= 0 || target >= 1) {
    throw ArgumentError('Invalid SLO');
  }
  final n = rows.length,
      good = rows
          .where((r) => r['ok'] == true && r['duration_ms'] <= threshold)
          .length,
      bad = n - good,
      allowed = n * (1 - target),
      durations = [for (final r in rows) (r['duration_ms'] as num).toDouble()];
  return {
    'requests': n,
    'good': good,
    'bad': bad,
    'availability': n == 0
        ? null
        : rows.where((r) => r['ok'] == true).length / n,
    'composite_sli': n == 0 ? null : good / n,
    'allowed_bad': allowed,
    'remaining_bad': allowed - bad,
    'burn_rate': n == 0 ? null : (bad / n) / (1 - target),
    'p95_all': mlopsQuantile(durations, .95),
    'p95_success': mlopsQuantile([
      for (final r in rows)
        if (r['ok'] == true) (r['duration_ms'] as num).toDouble(),
    ], .95),
    'histogram': [
      for (final b in [25, 50, 100, 200])
        {'le': b, 'count': rows.where((r) => r['duration_ms'] <= b).length},
    ],
    'threshold_ms': threshold,
    'target': target,
  };
}

Map<String, dynamic> mlopsPsi(
  List<double> reference,
  List<double> observed,
  List<double> edges,
) {
  final k = edges.length + 1,
      ref = List<int>.filled(k, 0),
      obs = List<int>.filled(k, 0);
  int bin(double value) {
    var j = 0;
    while (j < edges.length && value >= edges[j]) {
      j++;
    }
    return j;
  }

  for (final v in reference) {
    ref[bin(v)]++;
  }
  for (final v in observed) {
    obs[bin(v)]++;
  }
  final p = [for (final n in ref) (n + .5) / (reference.length + .5 * k)],
      q = [for (final n in obs) (n + .5) / (observed.length + .5 * k)],
      parts = [
        for (var j = 0; j < k; j++) (q[j] - p[j]) * math.log(q[j] / p[j]),
      ];
  return {
    'reference_count': reference.length,
    'observed_count': observed.length,
    'edges': edges,
    'reference_bins': ref,
    'observed_bins': obs,
    'reference_mass': p,
    'observed_mass': q,
    'contributions': parts,
    'psi': parts.fold(0.0, (a, b) => a + b),
    'smoothing': .5,
  };
}

class MLOpsAssets {
  final Map<String, dynamic> data;
  final _featureCache = <String, Map<String, num?>>{};
  static MLOpsAssets? _cached;
  static Future<MLOpsAssets>? _pending;
  static Future<MLOpsAssets> load() async =>
      _cached ??= await (_pending ??= _load());
  static Future<MLOpsAssets> _load() async => MLOpsAssets(
    jsonDecode(
      await rootBundle.loadString(
        'assets/datasets/bike_sharing/serving_lab.json',
      ),
    ),
  );
  MLOpsAssets(this.data);
  Map<String, num?> features(int target, String scenario) =>
      _featureCache.putIfAbsent(
        '$scenario:$target',
        () => Map.unmodifiable(
          pointInTimeFeatures(data['events'][scenario], target),
        ),
      );
  Map<String, dynamic> serve(
    int target, {
    String scenario = 'on_time',
    int canaryBp = 10000,
    bool rollback = false,
    bool candidateFault = false,
    bool baselineFault = false,
  }) {
    final response = _serve(
      target,
      scenario: scenario,
      canaryBp: canaryBp,
      rollback: rollback,
      candidateFault: candidateFault,
      baselineFault: baselineFault,
    );
    final key = response['served'] == 'candidate' ? 'candidate' : 'baseline';
    response['model_version'] = response['status'] == 'OK'
        ? data['models'][key]['model_version']
        : null;
    response['feature_version'] = data['feature_definition']['feature_version'];
    return response;
  }

  Map<String, dynamic> _serve(
    int target, {
    String scenario = 'on_time',
    int canaryBp = 10000,
    bool rollback = false,
    bool candidateFault = false,
    bool baselineFault = false,
  }) {
    if (target < 365 ||
        target > 546 ||
        !featureScenarios.contains(scenario) ||
        ![0, 1000, 5000, 10000].contains(canaryBp)) {
      throw ArgumentError('Unknown request');
    }
    final requestId = 'bike-global:${featureDate(target)}',
        bucket = mlopsBucket(requestId),
        baselineExpected = Map<String, dynamic>.from(
          data['manifests']['baseline'],
        ),
        baselineLoaded = {...baselineExpected};
    if (!mlopsValidModel(
      Map<String, dynamic>.from(data['models']['baseline']),
    )) {
      return {
        'request_id': requestId,
        'bucket': bucket,
        'status': 'BLOCKED',
        'served': 'none',
        'prediction': null,
        'reason': 'baseline_contract',
      };
    }
    if (baselineFault) {
      baselineLoaded['model_sha256'] = 'declared-incompatible-fixture';
    }
    if (mlopsContractErrors(baselineExpected, baselineLoaded).isNotEmpty) {
      return {
        'request_id': requestId,
        'bucket': bucket,
        'status': 'BLOCKED',
        'served': 'none',
        'prediction': null,
        'reason': 'baseline_contract',
      };
    }
    final f = features(target, scenario),
        baseline = mlopsPredict(
          Map<String, dynamic>.from(data['models']['baseline']),
          f,
        );
    if (baseline == null) {
      return {
        'request_id': requestId,
        'bucket': bucket,
        'status': 'BLOCKED',
        'served': 'none',
        'prediction': null,
        'reason': 'missing_baseline_feature',
      };
    }
    if (rollback || bucket >= canaryBp) {
      return {
        'request_id': requestId,
        'bucket': bucket,
        'status': 'OK',
        'served': 'baseline',
        'prediction': baseline,
        'reason': rollback ? 'rollback' : 'routed_baseline',
        'features': f,
      };
    }
    if (!mlopsValidModel(
      Map<String, dynamic>.from(data['models']['candidate']),
    )) {
      return {
        'request_id': requestId,
        'bucket': bucket,
        'status': 'OK',
        'served': 'fallback',
        'prediction': baseline,
        'reason': 'candidate_contract',
        'features': f,
      };
    }
    final expected = Map<String, dynamic>.from(data['manifests']['candidate']),
        loaded = {...expected};
    if (candidateFault) {
      loaded['model_sha256'] = 'declared-incompatible-fixture';
    }
    if (mlopsContractErrors(expected, loaded).isNotEmpty) {
      return {
        'request_id': requestId,
        'bucket': bucket,
        'status': 'OK',
        'served': 'fallback',
        'prediction': baseline,
        'reason': 'candidate_contract',
        'features': f,
      };
    }
    final candidate = mlopsPredict(
      Map<String, dynamic>.from(data['models']['candidate']),
      f,
    );
    return {
      'request_id': requestId,
      'bucket': bucket,
      'status': 'OK',
      'served': candidate == null ? 'fallback' : 'candidate',
      'prediction': candidate ?? baseline,
      'reason': candidate == null
          ? 'missing_candidate_features'
          : 'validated_candidate',
      'features': f,
    };
  }

  Map<String, int> replay({
    String scenario = 'on_time',
    int canaryBp = 10000,
    bool rollback = false,
    bool candidateFault = false,
  }) {
    final counts = {
      'requests': 182,
      'candidate': 0,
      'baseline': 0,
      'fallback': 0,
      'blocked': 0,
    };
    for (var t = 365; t < 547; t++) {
      final r = serve(
            t,
            scenario: scenario,
            canaryBp: canaryBp,
            rollback: rollback,
            candidateFault: candidateFault,
          ),
          key = r['status'] == 'BLOCKED' ? 'blocked' : r['served'] as String;
      counts[key] = counts[key]! + 1;
    }
    return counts;
  }

  Map<String, dynamic> monitoring(String period, String feature) {
    final bounds = mlopsPeriods[period]!,
        reference = [
          for (final r in data['training'])
            (r['features'][feature] as num).toDouble(),
        ],
        observed = [
          for (final r in data['rows'])
            if (r['target'] >= bounds.$1 && r['target'] <= bounds.$2)
              (r['features'][feature] as num).toDouble(),
        ],
        edges = List<double>.from(data['monitoring']['full'][feature]['edges']);
    return mlopsPsi(reference, observed, edges);
  }

  Map<String, dynamic> quality(String period, {int delay = 0}) {
    final bounds = mlopsPeriods[period]!,
        rows = (data['rows'] as List)
            .where((r) => r['target'] >= bounds.$1 && r['target'] <= bounds.$2)
            .toList(),
        clock = bounds.$2 + 1,
        mature = rows.where((r) => r['target'] + 1 + delay <= clock).toList(),
        models = <String, dynamic>{};
    for (final name in ['naive1', 'baseline', 'candidate']) {
      final errors = <double>[];
      for (final r in mature) {
        final predicted = name == 'naive1'
            ? (r['features']['lag1'] as num).toDouble()
            : mlopsPredict(
                Map<String, dynamic>.from(data['models'][name]),
                Map<String, dynamic>.from(r['features']),
              )!;
        errors.add(predicted - (r['outcome'] as num).toDouble());
      }
      final n = errors.length;
      models[name] = {
        'labels': n,
        'mae': n == 0 ? null : errors.fold(0.0, (s, e) => s + e.abs()) / n,
        'rmse': n == 0
            ? null
            : math.sqrt(errors.fold(0.0, (s, e) => s + e * e) / n),
        'bias': n == 0 ? null : errors.fold(0.0, (s, e) => s + e) / n,
      };
    }
    return {
      'request_rows': rows.length,
      'mature_labels': mature.length,
      'clock': clock,
      'delay_days': delay,
      'models': models,
    };
  }
}
