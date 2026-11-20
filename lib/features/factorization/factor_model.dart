import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

import '../recommendation/recommendation_model.dart';

const factorMethods = ['explicit_als', 'implicit_als', 'bpr', 'fm'];
List<double> _vector(dynamic r) =>
    (r as List).map((x) => (x as num).toDouble()).toList();
List<List<double>> _matrix(dynamic r) => (r as List).map(_vector).toList();
double factorDot(List<double> a, List<double> b) {
  var s = 0.0;
  for (var j = 0; j < a.length; j++) {
    s += a[j] * b[j];
  }
  return s;
}

double factorSoftplus(double x) =>
    math.max(x, 0) + math.log(1 + math.exp(-x.abs()));
double factorBprDerivative(double margin) => margin >= 0
    ? -math.exp(-margin) / (1 + math.exp(-margin))
    : -1 / (1 + math.exp(margin));
List<double> factorSolve(List<List<double>> a, List<double> b) {
  final n = b.length,
      l = List.generate(b.length, (_) => List.filled(b.length, 0.0));
  for (var i = 0; i < n; i++) {
    for (var j = 0; j <= i; j++) {
      var v = a[i][j];
      for (var k = 0; k < j; k++) {
        v -= l[i][k] * l[j][k];
      }
      if (i == j) {
        if (v <= 0) throw ArgumentError('Matrix must be positive definite');
        l[i][j] = math.sqrt(v);
      } else {
        l[i][j] = v / l[j][j];
      }
    }
  }
  final y = List.filled(n, 0.0), x = List.filled(n, 0.0);
  for (var i = 0; i < n; i++) {
    var v = b[i];
    for (var j = 0; j < i; j++) {
      v -= l[i][j] * y[j];
    }
    y[i] = v / l[i][i];
  }
  for (var i = n - 1; i >= 0; i--) {
    var v = y[i];
    for (var j = i + 1; j < n; j++) {
      v -= l[j][i] * x[j];
    }
    x[i] = v / l[i][i];
  }
  return x;
}

class FactorWeights {
  final Map<String, dynamic> raw;
  late final List<List<double>> p, q, v;
  late final List<double> bu, bi, linear;
  FactorWeights(this.raw) {
    p = raw.containsKey('p') ? _matrix(raw['p']) : [];
    q = raw.containsKey('q') ? _matrix(raw['q']) : [];
    v = raw.containsKey('v') ? _matrix(raw['v']) : [];
    bu = raw.containsKey('bu') ? _vector(raw['bu']) : [];
    bi = raw.containsKey('bi') ? _vector(raw['bi']) : [];
    linear = raw.containsKey('linear') ? _vector(raw['linear']) : [];
  }
}

class FactorALSUpdate {
  final List<List<double>> a;
  final List<double> b, before, after;
  final double beforeLoss, afterLoss;
  const FactorALSUpdate(
    this.a,
    this.b,
    this.before,
    this.after,
    this.beforeLoss,
    this.afterLoss,
  );
}

class FactorAssets {
  final Map<String, dynamic> data;
  final RecommendationAssets base;
  late final List<int> users, items;
  late final Map<int, int> userIndex, itemIndex;
  late final Map<String, FactorWeights> weights;
  late final List<List<double>> fmZ;
  late final List<double> fmItem;
  static FactorAssets? _cached;
  static Future<FactorAssets>? _pending;
  static Future<FactorAssets> load() async =>
      _cached ??= await (_pending ??= _load());
  static Future<FactorAssets> _load() async => FactorAssets(
    jsonDecode(
      await rootBundle.loadString('assets/datasets/movielens/factor_lab.json'),
    ),
    await RecommendationAssets.load(),
  );
  FactorAssets(this.data, this.base) {
    users = List<int>.from(data['users']);
    items = List<int>.from(data['items']);
    userIndex = {for (var j = 0; j < users.length; j++) users[j]: j};
    itemIndex = {for (var j = 0; j < items.length; j++) items[j]: j};
    weights = {
      for (final name in factorMethods)
        name: FactorWeights(Map<String, dynamic>.from(data['weights'][name])),
    };
    fmZ = [];
    fmItem = [];
    final w = weights['fm']!;
    for (final item in items) {
      final pair = active(users.first, item);
      final ids = pair.$1.skip(1).toList(), x = pair.$2.skip(1).toList();
      final z = List.filled(8, 0.0);
      var linear = 0.0, squares = 0.0;
      for (var j = 0; j < ids.length; j++) {
        linear += w.linear[ids[j]] * x[j];
        for (var f = 0; f < 8; f++) {
          final v = w.v[ids[j]][f] * x[j];
          z[f] += v;
          squares += v * v;
        }
      }
      fmZ.add(z);
      fmItem.add(linear + .5 * (factorDot(z, z) - squares));
    }
  }
  (List<int>, List<double>) active(int user, int item, {bool genres = true}) {
    final u = userIndex[user]!,
        i = itemIndex[item]!,
        gs = base.movies[item]!.genres;
    return (
      [
        u,
        users.length + i,
        if (genres)
          for (final g in gs)
            users.length + items.length + base.genres.indexOf(g),
      ],
      [
        1,
        1,
        if (genres)
          for (final _ in gs) 1 / math.sqrt(gs.length),
      ],
    );
  }

  String featureName(int index) => index < users.length
      ? 'User ${users[index]}'
      : index < users.length + items.length
      ? 'Movie ${items[index - users.length]}'
      : base.genres[index - users.length - items.length];
  Map<String, dynamic> fmExplain(int user, int item, {bool genres = true}) {
    final w = weights['fm']!,
        pair = active(user, item, genres: genres),
        ids = pair.$1,
        x = pair.$2,
        z = List.filled(8, 0.0),
        pairs = <Map<String, dynamic>>[];
    var linear = 0.0, squares = 0.0;
    for (var j = 0; j < ids.length; j++) {
      linear += w.linear[ids[j]] * x[j];
      for (var f = 0; f < 8; f++) {
        final v = w.v[ids[j]][f] * x[j];
        z[f] += v;
        squares += v * v;
      }
      for (var k = j + 1; k < ids.length; k++) {
        pairs.add({
          'a': featureName(ids[j]),
          'b': featureName(ids[k]),
          'value': factorDot(w.v[ids[j]], w.v[ids[k]]) * x[j] * x[k],
        });
      }
    }
    final interaction = .5 * (factorDot(z, z) - squares),
        bias = (w.raw['bias'] as num).toDouble();
    return {
      'bias': bias,
      'linear': linear,
      'interaction': interaction,
      'score': bias + linear + interaction,
      'pairs': pairs,
      'indices': ids,
      'values': x,
    };
  }

  bool fallback(int user, String method) =>
      !userIndex.containsKey(user) ||
      ((method == 'implicit_als' || method == 'bpr') &&
          (base.likes[user]?.isEmpty ?? true));
  double score(int user, int item, String method, {bool genres = true}) {
    if (fallback(user, method)) {
      return (base.positiveCounts[item] ?? 0).toDouble();
    }
    final u = userIndex[user]!, i = itemIndex[item]!, w = weights[method]!;
    if (method == 'fm') {
      if (!genres) return fmExplain(user, item, genres: false)['score'];
      return (w.raw['bias'] as num).toDouble() +
          w.linear[u] +
          fmItem[i] +
          factorDot(w.v[u], fmZ[i]);
    }
    final raw = factorDot(w.p[u], w.q[i]);
    return method == 'explicit_als'
        ? raw + (w.raw['mean'] as num).toDouble() + w.bu[u] + w.bi[i]
        : raw;
  }

  List<RecommendationResult> recommend(
    int user,
    String method, {
    int k = 10,
    bool genres = true,
  }) {
    final seen = base.history[user] ?? {},
        result = [
          for (final i in items)
            if (!seen.containsKey(i))
              RecommendationResult(i, score(user, i, method, genres: genres)),
        ];
    result.sort((a, b) {
      final c = (b.score * 1e12).round().compareTo((a.score * 1e12).round());
      return c != 0 ? c : a.movie.compareTo(b.movie);
    });
    return result.take(k).toList();
  }

  FactorALSUpdate updateUser(int user, {double reg = 10}) {
    final w = weights['explicit_als']!,
        u = userIndex[user]!,
        h = base.history[user]!,
        n = 9,
        a = List.generate(
          9,
          (j) => List.generate(9, (k) => j == k ? reg : 0.0),
        ),
        b = List.filled(9, 0.0),
        mu = (w.raw['mean'] as num).toDouble();
    for (final e in h.entries) {
      final i = itemIndex[e.key]!,
          x = [1.0, ...w.q[i]],
          target = e.value - mu - w.bi[i];
      for (var j = 0; j < n; j++) {
        b[j] += x[j] * target;
        for (var k = 0; k < n; k++) {
          a[j][k] += x[j] * x[k];
        }
      }
    }
    final before = [w.bu[u], ...w.p[u]], after = factorSolve(a, b);
    double objective(List<double> vector) {
      var total = reg * factorDot(vector, vector);
      for (final e in h.entries) {
        final i = itemIndex[e.key]!,
            x = [1.0, ...w.q[i]],
            error = e.value - mu - w.bi[i] - factorDot(x, vector);
        total += error * error;
      }
      return total;
    }

    return FactorALSUpdate(
      a,
      b,
      before,
      after,
      objective(before),
      objective(after),
    );
  }
}
