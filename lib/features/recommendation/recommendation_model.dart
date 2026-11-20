import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

const recommendationMethods = ['popularity', 'bayesian', 'content', 'user_cf'];
double _sum(Iterable<double> x) => x.fold(0.0, (a, b) => a + b);
double _norm(Iterable<double> x) => math.sqrt(_sum(x.map((v) => v * v)));
double _dot(List<double> a, List<double> b) =>
    _sum(List.generate(a.length, (i) => a[i] * b[i]));
double _rankKey(double x) => (x * 1e12).roundToDouble() / 1e12;

class RecommendationMovie {
  final int id;
  final String title;
  final List<String> genres;
  RecommendationMovie(List<dynamic> row)
    : id = row[0],
      title = row[1],
      genres = List<String>.from(row[2]);
}

class RecommendationNeighbour {
  final int user, overlap;
  final double similarity;
  const RecommendationNeighbour(this.user, this.similarity, this.overlap);
}

class RecommendationResult {
  final int movie;
  final double score;
  const RecommendationResult(this.movie, this.score);
}

class RecommendationAssets {
  final Map<String, dynamic> data;
  late final Map<int, RecommendationMovie> movies;
  late final Map<int, Map<int, double>> history;
  late final Map<int, Set<int>> likes;
  late final List<String> genres;
  late final List<double> idf;
  late final Map<int, List<double>> features;
  late final Map<int, int> counts, positiveCounts;
  late final Map<int, double> totals;
  late final double mean;
  static RecommendationAssets? _cached;
  static Future<RecommendationAssets>? _pending;
  static Future<RecommendationAssets> load() async =>
      _cached ??= await (_pending ??= _load());
  static Future<RecommendationAssets> _load() async => RecommendationAssets(
    jsonDecode(
      await rootBundle.loadString(
        'assets/datasets/movielens/recommendation_lab.json',
      ),
    ),
  );
  RecommendationAssets(this.data) {
    movies = {
      for (final r in data['movies']) r[0] as int: RecommendationMovie(r),
    };
    genres = List<String>.from(data['genres']);
    idf = (data['idf'] as List).map((v) => (v as num).toDouble()).toList();
    history = {};
    counts = {};
    positiveCounts = {};
    totals = {};
    var sum = 0.0;
    var n = 0;
    for (final row in data['train']) {
      final u = row[0] as int,
          i = row[1] as int,
          r = (row[2] as num).toDouble();
      history.putIfAbsent(u, () => {})[i] = r;
      counts[i] = (counts[i] ?? 0) + 1;
      totals[i] = (totals[i] ?? 0) + r;
      if (r >= 4) positiveCounts[i] = (positiveCounts[i] ?? 0) + 1;
      sum += r;
      n++;
    }
    mean = sum / n;
    likes = {
      for (final u in history.keys)
        u: history[u]!.entries
            .where((e) => e.value >= 4)
            .map((e) => e.key)
            .toSet(),
    };
    features = {};
    for (final m in movies.values) {
      final x = List.generate(
            genres.length,
            (j) => m.genres.contains(genres[j]) ? idf[j] : 0.0,
          ),
          norm = _norm(x);
      features[m.id] = x.map((v) => norm > 0 ? v / norm : 0.0).toList();
    }
  }
  double bayesian(int item, {double strength = 20}) =>
      ((totals[item] ?? 0) + strength * mean) /
      ((counts[item] ?? 0) + strength);
  List<RecommendationNeighbour> neighbours(
    int user, {
    double shrink = 10,
    int limit = 20,
  }) {
    final a = likes[user] ?? <int>{};
    if (a.isEmpty) return [];
    final result = <RecommendationNeighbour>[];
    for (final entry in likes.entries) {
      if (entry.key == user || entry.value.isEmpty) continue;
      final co = a.where(entry.value.contains).length;
      if (co < 2) continue;
      final sim =
          co / math.sqrt(a.length * entry.value.length) * co / (co + shrink);
      result.add(RecommendationNeighbour(entry.key, sim, co));
    }
    result.sort((a, b) {
      final c = _rankKey(b.similarity).compareTo(_rankKey(a.similarity));
      return c != 0 ? c : a.user.compareTo(b.user);
    });
    return result.take(limit).toList();
  }

  List<double> profile(int user) {
    final p = List.filled(genres.length, 0.0);
    for (final i in likes[user] ?? <int>{}) {
      final f = features[i]!;
      for (var j = 0; j < p.length; j++) {
        p[j] += f[j];
      }
    }
    final norm = _norm(p);
    return p.map((v) => norm > 0 ? v / norm : 0.0).toList();
  }

  Map<int, double> scores(
    int user,
    String method, {
    double shrink = 10,
    int neighbourLimit = 20,
    double strength = 20,
  }) {
    if (!recommendationMethods.contains(method)) {
      throw ArgumentError.value(method);
    }
    final popular = {
      for (final i in movies.keys) i: (positiveCounts[i] ?? 0).toDouble(),
    };
    if (method == 'popularity') return popular;
    if (method == 'bayesian') {
      return {for (final i in movies.keys) i: bayesian(i, strength: strength)};
    }
    if (method == 'content') {
      final p = profile(user);
      return _norm(p) == 0
          ? popular
          : {for (final i in movies.keys) i: _dot(features[i]!, p)};
    }
    final ns = neighbours(user, shrink: shrink, limit: neighbourLimit);
    if (ns.isEmpty) return popular;
    final s = {for (final i in movies.keys) i: 0.0},
        den = _sum(ns.map((n) => n.similarity));
    for (final n in ns) {
      for (final i in likes[n.user]!) {
        s[i] = s[i]! + n.similarity;
      }
    }
    return s.map((i, v) => MapEntry(i, v / den));
  }

  List<RecommendationResult> recommend(
    int user,
    String method, {
    int k = 10,
    bool excludeSeen = true,
    double shrink = 10,
    int neighbourLimit = 20,
    double strength = 20,
  }) {
    final s = scores(
          user,
          method,
          shrink: shrink,
          neighbourLimit: neighbourLimit,
          strength: strength,
        ),
        seen = history[user] ?? {};
    final items = s.keys
        .where((i) => !excludeSeen || !seen.containsKey(i))
        .toList();
    items.sort((a, b) {
      final c = _rankKey(s[b]!).compareTo(_rankKey(s[a]!));
      return c != 0 ? c : a.compareTo(b);
    });
    return items.take(k).map((i) => RecommendationResult(i, s[i]!)).toList();
  }

  Map<String, num> itemSimilarity(int a, int b, {double shrink = 10}) {
    var overlap = 0;
    for (final liked in likes.values) {
      if (liked.contains(a) && liked.contains(b)) overlap++;
    }
    final den = math.sqrt((positiveCounts[a] ?? 0) * (positiveCounts[b] ?? 0));
    final cosine = den > 0 ? overlap / den : 0.0;
    return {
      'overlap': overlap,
      'cosine': cosine,
      'shrunk': overlap + shrink > 0
          ? cosine * overlap / (overlap + shrink)
          : 0.0,
    };
  }
}

Map<String, num?> recommendationMetrics(
  List<int> ranked,
  Iterable<int> targets, {
  int k = 10,
}) {
  final gold = targets.toSet();
  var hits = 0;
  var dcg = 0.0;
  for (var j = 0; j < math.min(k, ranked.length); j++) {
    if (gold.contains(ranked[j])) {
      hits++;
      dcg += math.ln2 / math.log(j + 2);
    }
  }
  var ideal = 0.0;
  for (var j = 0; j < math.min(k, gold.length); j++) {
    ideal += math.ln2 / math.log(j + 2);
  }
  return {
    'hits': hits,
    'precision': hits / k,
    'recall': gold.isEmpty ? null : hits / gold.length,
    'ndcg': ideal == 0 ? null : dcg / ideal,
  };
}

Map<String, num?> recommendationScorecard(
  List<dynamic> rows,
  String method, {
  int k = 10,
  bool warmOnly = true,
  int? catalogSize,
}) {
  final cohort = rows
      .where(
        (r) => warmOnly
            ? (r['eligible'] as List).isNotEmpty && r['train_count'] > 0
            : (r['positive'] as List).isNotEmpty,
      )
      .toList();
  if (cohort.isEmpty) {
    return {
      'users': 0,
      'precision': null,
      'recall': null,
      'ndcg': null,
      'catalog_coverage': null,
    };
  }
  var precision = 0.0, recall = 0.0, ndcg = 0.0;
  final union = <int>{};
  for (final row in cohort) {
    final ranked = List<int>.from(row['rankings'][method]),
        m = recommendationMetrics(
          ranked,
          List<int>.from(row[warmOnly ? 'eligible' : 'positive']),
          k: k,
        );
    precision += (m['precision'] as num).toDouble();
    recall += (m['recall'] as num).toDouble();
    ndcg += (m['ndcg'] as num).toDouble();
    union.addAll(ranked.take(k));
  }
  return {
    'users': cohort.length,
    'precision': precision / cohort.length,
    'recall': recall / cohort.length,
    'ndcg': ndcg / cohort.length,
    'catalog_coverage': catalogSize == null ? null : union.length / catalogSize,
  };
}
