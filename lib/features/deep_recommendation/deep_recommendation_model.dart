import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

import '../recommendation/recommendation_model.dart';

const deepRecommendationConfigs = [
  'neural20',
  'neural50',
  'neural100',
  'hybrid50',
];
double deepDot(List<double> a, List<double> b) {
  var sum = 0.0;
  for (var j = 0; j < a.length; j++) {
    sum += a[j] * b[j];
  }
  return sum;
}

List<double> _v(dynamic r) =>
    (r as List).map((x) => (x as num).toDouble()).toList();
List<List<double>> _m(dynamic r) => (r as List).map(_v).toList();
List<double> _normalize(List<double> x) {
  final norm = math.sqrt(deepDot(x, x));
  return x.map((v) => v / math.max(norm, 1e-12)).toList();
}

List<double> _dense(List<double> x, List<List<double>> w, List<double> b) =>
    List.generate(w.length, (j) => deepDot(x, w[j]) + b[j]);
double deepLogSumExp(List<double> x) {
  final max = x.reduce(math.max);
  return max + math.log(x.fold(0.0, (s, v) => s + math.exp(v - max)));
}

List<double> deepBatchLoss(
  List<List<double>> q,
  List<List<double>> c,
  List<List<int>> positive, {
  double temperature = .2,
}) => List.generate(q.length, (j) {
  final logits = c.map((v) => deepDot(q[j], v) / temperature).toList(),
      logz = deepLogSumExp(logits);
  return logz -
      positive[j].fold(0.0, (s, k) => s + logits[k]) / positive[j].length;
});

class DeepPipeline {
  final List<int> candidates, ranked;
  final bool fallback;
  const DeepPipeline(this.candidates, this.ranked, this.fallback);
}

class DeepRecommendationAssets {
  final Map<String, dynamic> data;
  final RecommendationAssets base;
  late final List<int> users, items;
  late final Map<int, int> userIndex, itemIndex;
  late final Map<String, List<List<double>>> towerMatrix;
  late final Map<String, List<double>> towerVector;
  late final List<List<double>> itemGenres, queries, vectors, profiles, rankW1;
  late final List<double> rankB1, rankW2, featureMean, featureStd, bayes;
  late final double rankBias, statsMean;
  late final List<int> userCounts, itemCounts, itemPositive;
  late final List<Set<int>> likes;
  static DeepRecommendationAssets? _cached;
  static Future<DeepRecommendationAssets>? _pending;
  static Future<DeepRecommendationAssets> load() async =>
      _cached ??= await (_pending ??= _load());
  static Future<DeepRecommendationAssets> _load() async =>
      DeepRecommendationAssets(
        jsonDecode(
          await rootBundle.loadString(
            'assets/datasets/movielens/deep_recommendation_lab.json',
          ),
        ),
        await RecommendationAssets.load(),
      );
  DeepRecommendationAssets(this.data, this.base) {
    users = List<int>.from(data['users']);
    items = List<int>.from(data['items']);
    userIndex = {for (var j = 0; j < users.length; j++) users[j]: j};
    itemIndex = {for (var j = 0; j < items.length; j++) items[j]: j};
    towerMatrix = {};
    towerVector = {};
    for (final e in (data['tower'] as Map<String, dynamic>).entries) {
      if (e.key.endsWith('.weight')) {
        towerMatrix[e.key] = _m(e.value);
      } else {
        towerVector[e.key] = _v(e.value);
      }
    }
    itemGenres = [
      for (final i in items)
        _normalize([
          for (final g in base.genres)
            base.movies[i]!.genres.contains(g) ? 1.0 : 0.0,
        ]),
    ];
    queries = [for (var j = 0; j < users.length; j++) towerForward(j)];
    vectors = [
      for (var j = 0; j < items.length; j++)
        towerForward(j, genres: itemGenres[j]),
    ];
    userCounts = List.filled(users.length, 0);
    itemCounts = List.filled(items.length, 0);
    itemPositive = List.filled(items.length, 0);
    likes = List.generate(users.length, (_) => <int>{});
    final sums = List.filled(items.length, 0.0);
    var total = 0.0, count = 0;
    for (final index in data['retrieval_indices']) {
      final row = base.data['train'][index],
          u = userIndex[row[0]]!,
          i = itemIndex[row[1]]!,
          rating = (row[2] as num).toDouble();
      userCounts[u]++;
      itemCounts[i]++;
      sums[i] += rating;
      total += rating;
      count++;
      if (rating >= 4) {
        likes[u].add(i);
        itemPositive[i]++;
      }
    }
    statsMean = total / count;
    bayes = List.generate(
      items.length,
      (i) => (sums[i] + 20 * statsMean) / (itemCounts[i] + 20),
    );
    profiles = [];
    for (final liked in likes) {
      final p = List.filled(base.genres.length, 0.0);
      for (final i in liked) {
        for (var g = 0; g < p.length; g++) {
          p[g] += itemGenres[i][g];
        }
      }
      profiles.add(_normalize(p));
    }
    rankW1 = _m(data['ranker']['net.0.weight']);
    rankB1 = _v(data['ranker']['net.0.bias']);
    rankW2 = _v(data['ranker']['net.2.weight'][0]);
    rankBias = (data['ranker']['net.2.bias'][0] as num).toDouble();
    featureMean = _v(data['ranker_settings']['feature_mean']);
    featureStd = _v(data['ranker_settings']['feature_std']);
  }
  List<double> towerForward(int index, {List<double>? genres}) {
    final name = genres == null ? 'user' : 'item',
        x = [...towerMatrix['${name}_embedding.weight']![index], ...?genres],
        h = _dense(
          x,
          towerMatrix['${name}_net.0.weight']!,
          towerVector['${name}_net.0.bias']!,
        ).map((v) => math.max(0.0, v)).toList();
    return _normalize(
      _dense(
        h,
        towerMatrix['${name}_net.2.weight']!,
        towerVector['${name}_net.2.bias']!,
      ),
    );
  }

  bool isCold(int user) =>
      !userIndex.containsKey(user) || likes[userIndex[user]!].isEmpty;
  List<double> features(int user, int item) {
    final u = userIndex[user]!, i = itemIndex[item]!;
    return [
      deepDot(queries[u], vectors[i]),
      math.log(1 + userCounts[u]),
      math.log(1 + itemPositive[i]),
      bayes[i],
      deepDot(profiles[u], itemGenres[i]),
    ];
  }

  List<double> standardize(List<double> x) =>
      List.generate(x.length, (j) => (x[j] - featureMean[j]) / featureStd[j]);
  double logit(List<double> features) {
    final h = _dense(
      standardize(features),
      rankW1,
      rankB1,
    ).map((v) => math.max(0.0, v)).toList();
    return deepDot(h, rankW2) + rankBias;
  }

  DeepPipeline run(int user, {int budget = 50, bool hybrid = false}) {
    final seen = base.history[user] ?? {},
        available = items.where((i) => !seen.containsKey(i)).toList();
    final cold = isCold(user);
    List<int> ordered(List<int> ids, Map<int, double> scores) {
      final result = [...ids];
      result.sort((a, b) {
        final c = (scores[b]! * 1e12).round().compareTo(
          (scores[a]! * 1e12).round(),
        );
        return c != 0 ? c : a.compareTo(b);
      });
      return result;
    }

    final pop = {
      for (final i in items) i: (base.positiveCounts[i] ?? 0).toDouble(),
    };
    if (cold) {
      final candidates = ordered(available, pop).take(budget).toList();
      return DeepPipeline(candidates, candidates.take(10).toList(), true);
    }
    final q = queries[userIndex[user]!],
        scores = {for (final i in items) i: deepDot(q, vectors[itemIndex[i]!])},
        candidates = ordered(available, scores).take(budget).toList();
    if (hybrid) {
      for (final item in ordered(available, pop).take(budget)) {
        if (!candidates.contains(item)) candidates.add(item);
      }
    }
    final ranked = ordered(candidates, {
      for (final i in candidates) i: logit(features(user, i)),
    }).take(10).toList();
    return DeepPipeline(candidates, ranked, false);
  }

  List<double> batchLoss({double temperature = .2}) {
    final b = data['first_batch'];
    return deepBatchLoss(
      [for (final u in b['users']) queries[userIndex[u]!]],
      [for (final i in b['candidates']) vectors[itemIndex[i]!]],
      [for (final p in b['positive_columns']) List<int>.from(p)],
      temperature: temperature,
    );
  }
}

Map<String, num?> deepPipelineScore(
  List<dynamic> rows,
  String config, {
  bool warmOnly = true,
  int catalogSize = 7867,
}) {
  final basic = recommendationScorecard(
        rows,
        config,
        warmOnly: warmOnly,
        catalogSize: catalogSize,
      ),
      cohort = rows
          .where(
            (r) => warmOnly
                ? r['train_count'] > 0 && (r['eligible'] as List).isNotEmpty
                : (r['positive'] as List).isNotEmpty,
          )
          .toList();
  if (cohort.isEmpty) {
    return {
      ...basic,
      'candidate_recall': null,
      'oracle_recall10': null,
      'mean_candidates': null,
    };
  }
  var recall = 0.0, oracle = 0.0, count = 0.0;
  for (final r in cohort) {
    final c = List<int>.from(r['pipelines'][config]['candidates']),
        gold = Set<int>.from(r[warmOnly ? 'eligible' : 'positive']),
        hits = c.where(gold.contains).length;
    recall += hits / gold.length;
    oracle += math.min(10, hits) / gold.length;
    count += c.length;
  }
  return {
    ...basic,
    'candidate_recall': recall / cohort.length,
    'oracle_recall10': oracle / cohort.length,
    'mean_candidates': count / cohort.length,
  };
}
