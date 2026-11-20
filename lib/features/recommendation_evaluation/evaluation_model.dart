import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

import '../recommendation/recommendation_model.dart';

const evaluationMethods = [
  'neural50',
  'neural100',
  'hybrid50',
  'popularity',
  'user_cf',
  'mmr1',
  'mmr0.75',
  'mmr0.5',
];
double evaluationQuantile(List<double> values, double probability) {
  if (values.isEmpty) throw ArgumentError('Empty distribution');
  final sorted = [...values]..sort();
  final h = (sorted.length - 1) * probability, lo = h.floor(), hi = h.ceil();
  return sorted[lo] + (sorted[hi] - sorted[lo]) * (h - lo);
}

Map<String, num?> evaluationMetrics(
  List<int> ranked,
  Iterable<int> gold, {
  int k = 10,
}) {
  final m = recommendationMetrics(ranked, gold, k: k), g = gold.toSet();
  double? reciprocal = g.isEmpty ? null : 0;
  for (var j = 0; j < math.min(k, ranked.length); j++) {
    if (g.contains(ranked[j])) {
      reciprocal = 1 / (j + 1);
      break;
    }
  }
  return {...m, 'mrr': reciprocal};
}

List<dynamic> evaluationCohort(List<dynamic> rows, String scope) => rows
    .where(
      (r) => switch (scope) {
        'warm' => r['train_count'] > 0 && (r['eligible'] as List).isNotEmpty,
        'cold' => r['train_count'] == 0 && (r['positive'] as List).isNotEmpty,
        'broad' => (r['positive'] as List).isNotEmpty,
        _ => throw ArgumentError.value(scope),
      },
    )
    .toList();
Map<String, num?> evaluationScore(
  List<dynamic> rows,
  String method, {
  String scope = 'warm',
  int k = 10,
}) {
  final cohort = evaluationCohort(rows, scope),
      sum = {'precision': 0.0, 'recall': 0.0, 'ndcg': 0.0, 'mrr': 0.0};
  if (cohort.isEmpty) {
    return {'users': 0, for (final key in sum.keys) key: null};
  }
  for (final row in cohort) {
    final m = evaluationMetrics(
      List<int>.from(row['rankings'][method]),
      List<int>.from(row[scope == 'warm' ? 'eligible' : 'positive']),
      k: k,
    );
    for (final key in sum.keys) {
      sum[key] = sum[key]! + (m[key] as num).toDouble();
    }
  }
  return {
    'users': cohort.length,
    for (final key in sum.keys) key: sum[key]! / cohort.length,
  };
}

Map<String, dynamic> evaluationPropensity({double? clip}) {
  const rows = [
    ('A', .8, 1.0, 'A'),
    ('B', .2, 1.0, 'B'),
    ('A', .8, 0.0, 'B'),
    ('B', .2, 0.0, 'A'),
  ];
  final weights = [
        for (final r in rows)
          r.$1 == r.$4 ? math.min(1 / r.$2, clip ?? double.infinity) : 0.0,
      ],
      sum = weights.reduce((a, b) => a + b),
      weighted = List.generate(
        4,
        (j) => weights[j] * rows[j].$3,
      ).reduce((a, b) => a + b),
      squares = weights.fold(0.0, (s, v) => s + v * v);
  return {
    'weights': weights,
    'naive': .5,
    'ips': weighted / 4,
    'snips': sum > 0 ? weighted / sum : null,
    'ess': squares > 0 ? sum * sum / squares : null,
  };
}

int evaluationSampleSize({double baseline = .1, double mde = .01}) =>
    (2 * math.pow(1.96 + .84, 2) * baseline * (1 - baseline) / (mde * mde))
        .ceil();

class EvaluationMMR {
  final List<int> ranked;
  final List<Map<String, dynamic>> trace;
  const EvaluationMMR(this.ranked, this.trace);
}

class RecommendationEvaluationAssets {
  final Map<String, dynamic> data;
  final RecommendationAssets base;
  late final Map<int, List<double>> genres;
  late final Map<int, int> popularity;
  late final int totalPositive;
  static RecommendationEvaluationAssets? _cached;
  static Future<RecommendationEvaluationAssets>? _pending;
  static Future<RecommendationEvaluationAssets> load() async =>
      _cached ??= await (_pending ??= _load());
  static Future<RecommendationEvaluationAssets> _load() async =>
      RecommendationEvaluationAssets(
        jsonDecode(
          await rootBundle.loadString(
            'assets/datasets/movielens/recommendation_evaluation_lab.json',
          ),
        ),
        await RecommendationAssets.load(),
      );
  RecommendationEvaluationAssets(this.data, this.base) {
    genres = {};
    for (final m in base.movies.values) {
      final x = [for (final g in base.genres) m.genres.contains(g) ? 1.0 : 0.0],
          norm = math.sqrt(x.fold(0.0, (s, v) => s + v * v));
      genres[m.id] = x.map((v) => norm > 0 ? v / norm : 0.0).toList();
    }
    popularity = {
      for (final row in data['popularity']) row[0] as int: row[1] as int,
    };
    totalPositive = popularity.values.reduce((a, b) => a + b);
  }
  double cosine(int a, int b) {
    var s = 0.0;
    for (var j = 0; j < genres[a]!.length; j++) {
      s += genres[a]![j] * genres[b]![j];
    }
    return s;
  }

  EvaluationMMR mmr(
    List<int> ids,
    List<double> scores, {
    double strength = 1,
    int k = 10,
  }) {
    if (ids.isEmpty) return const EvaluationMMR([], []);
    final lo = scores.reduce(math.min),
        hi = scores.reduce(math.max),
        relevance = scores
            .map((v) => hi > lo ? (v - lo) / (hi - lo) : 0.0)
            .toList(),
        chosen = <int>[],
        trace = <Map<String, dynamic>>[];
    for (var step = 0; step < math.min(k, ids.length); step++) {
      final remaining = List.generate(
            ids.length,
            (j) => j,
          ).where((j) => !chosen.contains(j)).toList(),
          penalty = <int, double>{},
          utility = <int, double>{};
      for (final j in remaining) {
        penalty[j] = chosen.isEmpty
            ? 0
            : chosen.map((s) => cosine(ids[j], ids[s])).reduce(math.max);
        utility[j] = strength * relevance[j] - (1 - strength) * penalty[j]!;
      }
      remaining.sort((a, b) {
        final c = (utility[b]! * 1e12).round().compareTo(
          (utility[a]! * 1e12).round(),
        );
        return c != 0 ? c : ids[a].compareTo(ids[b]);
      });
      final best = remaining.first;
      chosen.add(best);
      trace.add({
        'item': ids[best],
        'raw': scores[best],
        'relevance': relevance[best],
        'redundancy': penalty[best],
        'utility': utility[best],
      });
    }
    return EvaluationMMR(chosen.map((j) => ids[j]).toList(), trace);
  }

  Map<String, double?> listQuality(List<int> ranked) {
    var pairs = 0, sum = 0.0, novelty = 0.0;
    for (var j = 0; j < ranked.length; j++) {
      novelty -=
          math.log(
            ((popularity[ranked[j]] ?? 0) + 1) /
                (totalPositive + base.movies.length),
          ) /
          math.ln2;
      for (var k = j + 1; k < ranked.length; k++) {
        pairs++;
        sum += 1 - cosine(ranked[j], ranked[k]);
      }
    }
    return {
      'ild': pairs > 0 ? sum / pairs : null,
      'novelty_bits': ranked.isNotEmpty ? novelty / ranked.length : null,
    };
  }

  Map<String, num?> diversity(String method) {
    final rows = evaluationCohort(data['rows'], 'warm'), counts = <int, int>{};
    var ild = 0.0, novel = 0.0;
    for (final r in rows) {
      final ranked = List<int>.from(r['rankings'][method]),
          q = listQuality(ranked);
      ild += q['ild']!;
      novel += q['novelty_bits']!;
      for (final i in ranked) {
        counts[i] = (counts[i] ?? 0) + 1;
      }
    }
    final total = counts.values.fold(0, (s, v) => s + v);
    var entropy = 0.0;
    for (final n in counts.values) {
      final p = n / total;
      entropy -= p * math.log(p) / math.ln2;
    }
    return {
      'users': rows.length,
      'ild': rows.isEmpty ? null : ild / rows.length,
      'novelty_bits': rows.isEmpty ? null : novel / rows.length,
      'catalog_coverage': counts.length / base.movies.length,
      'recommendation_entropy_bits': total > 0 ? entropy : null,
      'distinct_recommended': counts.length,
    };
  }

  Map<String, num> interval(String key, {double confidence = .95}) {
    final b = data['paired'][key]['bootstrap'],
        values = (b['replicates'] as List)
            .map((v) => (v as num).toDouble())
            .toList(),
        tail = (1 - confidence) / 2;
    return {
      'mean': b['mean'],
      'low': evaluationQuantile(values, tail),
      'high': evaluationQuantile(values, 1 - tail),
      'users': b['users'],
    };
  }
}
