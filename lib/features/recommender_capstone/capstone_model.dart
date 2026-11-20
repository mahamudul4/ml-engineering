import 'dart:convert';

import 'package:flutter/services.dart';

import '../recommendation/recommendation_model.dart';

const capstoneSources = ['popularity', 'content', 'user_cf'];
const capstonePolicies = <String, List<double>>{
  'rrf_equal': [1, 1, 1],
  'rrf_cf': [1, 1, 2],
  'rrf_content': [1, 2, 1],
};

class CapstoneResult {
  final List<int> candidates, ranked;
  final List<Map<String, dynamic>> trace;
  const CapstoneResult(this.candidates, this.ranked, this.trace);
}

CapstoneResult capstoneFuse(
  Map<String, dynamic> sources, {
  String policy = 'rrf_equal',
  int budget = 50,
}) {
  if (!capstonePolicies.containsKey(policy) ||
      ![25, 50, 100].contains(budget)) {
    throw ArgumentError('Unknown preset');
  }
  final positions = <String, Map<int, int>>{}, candidates = <int>[];
  for (final name in capstoneSources) {
    final ids = List<int>.from(sources[name]).take(budget).toList();
    positions[name] = {for (var j = 0; j < ids.length; j++) ids[j]: j + 1};
    for (final id in ids) {
      if (!candidates.contains(id)) candidates.add(id);
    }
  }
  final contributions = <int, List<double>>{}, scores = <int, double>{};
  for (final id in candidates) {
    contributions[id] = [
      for (var j = 0; j < 3; j++)
        positions[capstoneSources[j]]!.containsKey(id)
            ? capstonePolicies[policy]![j] /
                  (60 + positions[capstoneSources[j]]![id]!)
            : 0,
    ];
    scores[id] = contributions[id]!.reduce((a, b) => a + b);
  }
  final ranked = [...candidates]
    ..sort((a, b) {
      final c = (scores[b]! * 1e12).round().compareTo(
        (scores[a]! * 1e12).round(),
      );
      return c != 0 ? c : a.compareTo(b);
    });
  final top = ranked.take(10).toList();
  return CapstoneResult(candidates, top, [
    for (final id in top)
      {
        'item': id,
        'score': scores[id],
        'contributions': contributions[id],
        'ranks': [for (final name in capstoneSources) positions[name]![id]],
      },
  ]);
}

String capstoneSelect(Map<String, dynamic> validationCards) {
  final names = capstonePolicies.keys.toList(),
      order = capstonePolicies.keys.toList();
  names.sort((a, b) {
    for (final key in ['ndcg', 'recall']) {
      final x = (validationCards[a]['warm'][key] as num).toDouble(),
          y = (validationCards[b]['warm'][key] as num).toDouble();
      final c = (y * 1e12).round().compareTo((x * 1e12).round());
      if (c != 0) return c;
    }
    return order.indexOf(a).compareTo(order.indexOf(b));
  });
  return names.first;
}

List<String> capstoneContractErrors(
  Map<String, dynamic> expected,
  Map<String, dynamic> loaded,
) => [
  for (final key in [
    'model_version',
    'model_sha256',
    'catalog_sha256',
    'feature_schema',
    'policy_sha256',
  ])
    if (expected[key] != loaded[key]) key,
];
String _artifactIdentity(Map<String, dynamic> manifest) => [
  for (final key in [
    'model_version',
    'model_sha256',
    'catalog_sha256',
    'feature_schema',
    'policy_sha256',
  ])
    manifest[key],
].join(':');
String capstoneCacheSignature(
  Map<String, dynamic> row,
  Map<String, dynamic> manifest,
  String policy, {
  int budget = 50,
}) =>
    '${_artifactIdentity(manifest)}:${row['user']}:${row['history_sha256']}:$policy:$budget:seen=all-fit';

Map<String, dynamic>? capstoneGuardedReplay(
  List<dynamic> rows,
  Map<String, dynamic> expected,
  Map<String, dynamic> loaded, {
  String mode = 'complete',
}) {
  if (capstoneContractErrors(expected, loaded).isNotEmpty) {
    return null;
  }
  return capstoneReplay(rows, expected, mode: mode);
}

Map<String, dynamic> capstoneReplay(
  List<dynamic> rows,
  Map<String, dynamic> manifest, {
  String mode = 'complete',
  int budget = 50,
}) {
  final warm = rows.firstWhere(
        (r) => r['train_count'] > 0 && (r['eligible'] as List).isNotEmpty,
      ),
      cold = rows.firstWhere((r) => r['train_count'] == 0);
  final requests = [
        (warm, 'rrf_equal'),
        (warm, 'rrf_cf'),
        (warm, 'rrf_equal'),
        (cold, 'rrf_equal'),
        (warm, 'rrf_cf'),
      ],
      cache = <String, Map<String, dynamic>>{},
      trace = <Map<String, dynamic>>[];
  for (final request in requests) {
    final row = request.$1, policy = request.$2;
    final full = capstoneCacheSignature(
          Map<String, dynamic>.from(row),
          manifest,
          policy,
          budget: budget,
        ),
        artifact = _artifactIdentity(manifest);
    final key = mode == 'complete'
        ? full
        : mode == 'shared_user'
        ? '$artifact:$policy:$budget:seen=all-fit'
        : '$artifact:${row['user']}:${row['history_sha256']}:$budget:seen=all-fit';
    final previous = cache[key],
        rejected = previous != null && previous['signature'] != full,
        hit = previous != null && !rejected;
    final ranked = hit
        ? previous['ranked']
        : capstoneFuse(
            Map<String, dynamic>.from(row['sources']),
            policy: policy,
            budget: budget,
          ).ranked;
    cache[key] = {'signature': full, 'ranked': ranked};
    trace.add({
      'user': row['user'],
      'policy': policy,
      'hit': hit,
      'rejected': rejected,
      'ranked': ranked,
    });
  }
  return {
    'requests': trace.length,
    'hits': trace.where((r) => r['hit'] == true).length,
    'rejected': trace.where((r) => r['rejected'] == true).length,
    'computations': trace.where((r) => r['hit'] == false).length,
    'trace': trace,
  };
}

class RecommenderCapstoneAssets {
  final Map<String, dynamic> data;
  late final RecommendationAssets model;
  static RecommenderCapstoneAssets? _cached;
  static Future<RecommenderCapstoneAssets>? _pending;
  static Future<RecommenderCapstoneAssets> load() async =>
      _cached ??= await (_pending ??= _load());
  static Future<RecommenderCapstoneAssets> _load() async =>
      RecommenderCapstoneAssets(
        jsonDecode(
          await rootBundle.loadString(
            'assets/datasets/movielens/recommender_capstone_lab.json',
          ),
        ),
      );
  RecommenderCapstoneAssets(this.data) {
    model = RecommendationAssets(Map<String, dynamic>.from(data['model']));
  }
  Map<String, dynamic> row(int user) => Map<String, dynamic>.from(
    (data['roles']['audit'] as List).firstWhere((r) => r['user'] == user),
  );
}
