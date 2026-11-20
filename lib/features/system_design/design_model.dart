import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

import '../recommender_capstone/capstone_model.dart';
import '../retrieval/retrieval_model.dart';
import '../mlops/mlops_model.dart';
import '../gen_capstone/gen_capstone_model.dart';
import '../rag/rag_model.dart';

const designCases = ['recommendation', 'search', 'spam', 'forecast', 'rag'];
const designFaults = ['none', 'model_mismatch', 'upstream'];
bool designValidSpam(Map<String, dynamic> model) {
  if (model['version'] != 'spam38-logreg-v1' ||
      model['schema'] != 'spambase57-v1') {
    return false;
  }
  for (final key in ['mean', 'scale', 'weights']) {
    final values = model[key];
    if (values is! List ||
        values.length != 57 ||
        values.any((v) => v is! num || !v.isFinite)) {
      return false;
    }
  }
  return (model['scale'] as List).every((v) => v > 0) &&
      model['intercept'] is num &&
      (model['intercept'] as num).isFinite;
}

double? designSpamPredict(Map<String, dynamic> model, List<dynamic> features) {
  if (!designValidSpam(model) ||
      features.length != 57 ||
      features.any((v) => v is! num || !v.isFinite || v < 0)) {
    return null;
  }
  var raw = (model['intercept'] as num).toDouble();
  for (var j = 0; j < 57; j++) {
    raw +=
        (model['weights'][j] as num) *
        ((features[j] as num) - (model['mean'][j] as num)) /
        (model['scale'][j] as num);
  }
  if (!raw.isFinite) {
    return null;
  }
  return raw >= 0
      ? 1 / (1 + math.exp(-raw))
      : math.exp(raw) / (1 + math.exp(raw));
}

Map<String, dynamic> designCapacity(
  Map<String, dynamic> system, {
  int qps = 1000,
  double hit = .5,
  int replicas = 4,
  double scale = 1,
  int deadline = 100,
}) {
  if (qps < 0 ||
      !hit.isFinite ||
      hit < 0 ||
      hit > 1 ||
      replicas < 1 ||
      !scale.isFinite ||
      scale <= 0 ||
      deadline <= 0) {
    throw ArgumentError('Invalid planning assumptions');
  }
  final stages = system['stages'] as List;
  var critical = 0.0, total = 0.0;
  for (final group in stages) {
    final times = [for (final s in group) (s['ms'] as num).toDouble()];
    critical += times.reduce(math.max) * scale;
    total += times.reduce((a, b) => a + b) * scale;
  }
  final backend = qps * (1 - hit),
      slots = 4 * replicas,
      limit = slots * 1000 / critical,
      rho = backend / limit;
  return {
    'qps': qps,
    'hit': hit,
    'replicas': replicas,
    'scale': scale,
    'deadline': deadline,
    'critical_ms': critical,
    'serial_work_ms': total,
    'parallel_saved_ms': total - critical,
    'backend_qps': backend,
    'concurrent_slots': slots,
    'ideal_capacity': limit,
    'utilization': rho,
    'stable': rho < 1,
    'in_service': rho < 1 ? backend * critical / 1000 : null,
    'deadline_slack': deadline - critical,
    'state': rho >= 1
        ? 'OVERLOAD'
        : rho > .7
        ? 'LOW HEADROOM'
        : 'WITHIN ASSUMPTION',
  };
}

Map<String, dynamic> designReviewPolicy(
  List<dynamic> rows, {
  double low = .2,
  double high = .8,
  int budget = 50,
  String overflow = 'defer',
  int fpCost = 100,
  bool fault = false,
}) {
  if (!low.isFinite ||
      !high.isFinite ||
      low < 0 ||
      low >= high ||
      high > 1 ||
      budget < 0 ||
      !['defer', 'allow', 'block'].contains(overflow) ||
      fpCost < 0) {
    throw ArgumentError('Invalid policy');
  }
  final n = rows.length,
      routes = List<String>.filled(n, 'defer'),
      uncertain = <int>[];
  if (!fault) {
    for (var j = 0; j < n; j++) {
      final p = (rows[j]['score'] as num).toDouble();
      if (!p.isFinite || p < 0 || p > 1) {
        throw ArgumentError('Invalid score');
      }
      if (p < low) {
        routes[j] = 'allow';
      } else if (p >= high) {
        routes[j] = 'block';
      } else {
        uncertain.add(j);
      }
    }
    uncertain.sort((a, b) {
      final c = (((rows[a]['score'] as num) - .5).abs() * 1e12)
          .round()
          .compareTo((((rows[b]['score'] as num) - .5).abs() * 1e12).round());
      return c != 0 ? c : (rows[a]['index'] as int).compareTo(rows[b]['index']);
    });
    for (var rank = 0; rank < uncertain.length; rank++) {
      routes[uncertain[rank]] = rank < budget ? 'review' : overflow;
    }
  }
  final counts = {
    for (final k in ['allow', 'block', 'review', 'defer'])
      k: routes.where((r) => r == k).length,
  };
  var fp = 0, fn = 0;
  for (var j = 0; j < n; j++) {
    if (routes[j] == 'block' && rows[j]['label'] == 0) {
      fp++;
    }
    if (routes[j] == 'allow' && rows[j]['label'] == 1) {
      fn++;
    }
  }
  final decided = counts['allow']! + counts['block']!,
      pending = counts['review']! + counts['defer']!;
  return {
    'n': n,
    'low': low,
    'high': high,
    'budget': budget,
    'overflow': overflow,
    'fp_cost': fpCost,
    'contract_blocked': fault ? n : 0,
    'uncertain': uncertain.length,
    'overflow_count': math.max(0, uncertain.length - budget),
    'review_ids': [for (final j in uncertain.take(budget)) rows[j]['index']],
    ...counts,
    'decided': decided,
    'pending': pending,
    'coverage': n == 0 ? null : decided / n,
    'false_blocks': fp,
    'missed_spam': fn,
    'conditional_accuracy': decided == 0 ? null : (decided - fp - fn) / decided,
    'automatic_cost': fpCost * fp + fn,
    'routes': routes,
  };
}

List<String> designContractErrors(
  Map<String, dynamic> expected,
  Map<String, dynamic> loaded,
) => [
  for (final k in [
    'case_version',
    'model_identity',
    'source_identity',
    'input_schema',
    'policy_identity',
  ])
    if (expected[k] != loaded[k]) k,
];

class DesignAssets {
  final Map<String, dynamic> data;
  final RecommenderCapstoneAssets? recommender;
  final RetrievalAssets? retrieval;
  final MLOpsAssets? forecast;
  final GenCapstoneAssets? generator;
  DesignAssets(
    this.data, {
    this.recommender,
    this.retrieval,
    this.forecast,
    this.generator,
  });
  static DesignAssets? _cached;
  static Future<DesignAssets>? _pending;
  static Future<DesignAssets> load() async =>
      _cached ??= await (_pending ??= _load());
  static Future<DesignAssets> _load() async {
    final r = await Future.wait<dynamic>([
      rootBundle.loadString('assets/datasets/system_design/design_lab.json'),
      RecommenderCapstoneAssets.load(),
      RetrievalAssets.load(),
      MLOpsAssets.load(),
      GenCapstoneAssets.load(),
    ]);
    return DesignAssets(
      jsonDecode(r[0] as String),
      recommender: r[1],
      retrieval: r[2],
      forecast: r[3],
      generator: r[4],
    );
  }

  List<dynamic>? _scores;
  List<dynamic> get scoredRows => _scores ??= [
    for (final row in data['spam']['validation'])
      {
        ...Map<String, dynamic>.from(row),
        'score': designSpamPredict(
          Map<String, dynamic>.from(data['spam']['model']),
          row['features'],
        ),
      },
  ];
  Map<String, dynamic> review({
    double low = .2,
    double high = .8,
    int budget = 50,
    String overflow = 'defer',
    int fpCost = 100,
    bool fault = false,
  }) {
    final blocked =
        fault ||
        !designValidSpam(Map<String, dynamic>.from(data['spam']['model']));
    return designReviewPolicy(
      blocked ? data['spam']['validation'] : scoredRows,
      low: low,
      high: high,
      budget: budget,
      overflow: overflow,
      fpCost: fpCost,
      fault: blocked,
    );
  }

  Map<String, dynamic> capacity(
    String system, {
    int qps = 1000,
    double hit = .5,
    int replicas = 4,
    double scale = 1,
    int deadline = 100,
  }) => designCapacity(
    Map<String, dynamic>.from(data['cases'][system]),
    qps: qps,
    hit: hit,
    replicas: replicas,
    scale: scale,
    deadline: deadline,
  );
  Map<String, dynamic> response(String system, {String fault = 'none'}) {
    if (!designCases.contains(system) || !designFaults.contains(fault)) {
      throw ArgumentError('Unknown case/fault');
    }
    final expected = Map<String, dynamic>.from(data['manifests'][system]),
        loaded = {...expected};
    if (fault == 'model_mismatch') {
      loaded['model_identity'] = 'explicit software mismatch';
    }
    final base = <String, dynamic>{
      'case': system,
      'request': data['cases'][system]['request'],
      'status': 'OK',
      'served': '',
      'reason': '',
      'output': null,
      'citations': <String>[],
    };
    if (designContractErrors(expected, loaded).isNotEmpty) {
      return {
        ...base,
        'status': 'BLOCKED',
        'served': 'none',
        'reason': 'artifact_contract',
      };
    }
    final upstream = fault == 'upstream';
    if (system == 'recommendation') {
      final row = recommender!.row(15);
      if (upstream) {
        return {
          ...base,
          'status': 'DEGRADED',
          'served': 'fit_popularity',
          'reason': 'personalization_missing_fixture',
          'output': {
            'items': (row['sources']['popularity'] as List).take(10).toList(),
          },
        };
      }
      final ranking = capstoneFuse(
        Map<String, dynamic>.from(row['sources']),
        policy: 'rrf_cf',
        budget: 50,
      );
      return {
        ...base,
        'served': 'weighted_rrf',
        'reason': 'validated_ranking',
        'output': {'items': ranking.ranked},
      };
    }
    if (system == 'search') {
      final a = retrieval!,
          sample = a.samples.first,
          hits = a.index.search(
            sample.text,
            method: upstream ? 'tfidf' : 'hybrid',
            k: 5,
            depth: 100,
          );
      return {
        ...base,
        'status': upstream ? 'DEGRADED' : 'OK',
        'served': upstream ? 'lexical_tfidf' : 'hybrid_rrf',
        'reason': upstream
            ? 'dense_candidates_ignored_fixture'
            : 'validated_retrieval',
        'output': {
          'documents': [for (final h in hits) h.id],
        },
      };
    }
    if (system == 'spam') {
      if (upstream) {
        return {
          ...base,
          'status': 'ABSTAIN',
          'served': 'defer',
          'reason': 'feature_source_missing_fixture',
        };
      }
      final p = designSpamPredict(
        Map<String, dynamic>.from(data['spam']['model']),
        data['spam']['validation'][0]['features'],
      );
      if (p == null) {
        return {
          ...base,
          'status': 'ABSTAIN',
          'served': 'defer',
          'reason': 'invalid_features',
        };
      }
      return {
        ...base,
        'served': 'logistic',
        'reason': 'validated_score',
        'output': {'probability': p, 'decision': p >= .5 ? 'block' : 'allow'},
      };
    }
    if (system == 'forecast') {
      final r = forecast!.serve(
        375,
        scenario: upstream ? 'late_fixture' : 'on_time',
      );
      return {
        ...base,
        'status': upstream ? 'DEGRADED' : 'OK',
        'served': upstream ? 'seasonal7' : 'ridge',
        'reason': upstream ? 'late_feature_fixture' : 'validated_point_in_time',
        'output': {'prediction': r['prediction']},
      };
    }
    if (upstream) {
      return {
        ...base,
        'status': 'ABSTAIN',
        'served': 'no_answer',
        'reason': 'empty_context_fixture',
      };
    }
    final a = generator!,
        sample = a.samples.first,
        pack = sample['cases']['retrieved']['pack'],
        selected = pack['selected'] as List,
        source = a.rag.system.source;
    final exact = selected.every(
      (c) =>
          ragAuditQuote(
            RAGChunk(c['doc_id'], c['start'], c['end'], c['text']),
            source,
          )['exact_quote'] ==
          true,
    );
    if (selected.isEmpty || !exact) {
      return {
        ...base,
        'status': 'ABSTAIN',
        'served': 'no_answer',
        'reason': 'provenance_or_format',
      };
    }
    final generated = a.generate(
      capstoneFeatures(sample['text'], sample['cases']['retrieved']['context']),
    );
    if (!generated.formatValid) {
      return {
        ...base,
        'status': 'ABSTAIN',
        'served': 'no_answer',
        'reason': 'provenance_or_format',
      };
    }
    return {
      ...base,
      'served': 'tiny_response_decoder',
      'reason': 'unverified_hypothesis',
      'output': {'hypothesis': generated.text},
      'citations': [
        for (final c in selected) '[${c['doc_id']}:${c['start']}-${c['end']}]',
      ],
    };
  }
}
