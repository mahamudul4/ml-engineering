import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

int practiceRankKey(Map<String, dynamic> r) =>
    ((r['total'] as num) / (r['n'] as num) * 1e12).round();

Map<String, dynamic> practiceTopK(
  List<Map<String, dynamic>> catalog, {
  int k = 10,
  int minimum = 10,
  String method = 'heap',
}) {
  if (k < 0 || minimum < 1 || !['heap', 'merge'].contains(method)) {
    throw ArgumentError('Invalid Top-K request');
  }
  // Keep filtering lazy: the heap path must not allocate an O(n) candidate copy.
  final rows = catalog.where((r) => (r['n'] as num) >= minimum);
  var comparisons = 0;
  bool better(Map<String, dynamic> a, Map<String, dynamic> b) {
    comparisons++;
    final ka = practiceRankKey(a), kb = practiceRankKey(b);
    return ka > kb || (ka == kb && (a['id'] as int) < (b['id'] as int));
  }

  List<Map<String, dynamic>> mergeSort(List<Map<String, dynamic>> xs) {
    if (xs.length < 2) return xs.toList();
    final at = xs.length ~/ 2,
        a = mergeSort(xs.sublist(0, at)),
        b = mergeSort(xs.sublist(at));
    final out = <Map<String, dynamic>>[];
    var i = 0, j = 0;
    while (i < a.length && j < b.length) {
      if (better(a[i], b[j])) {
        out.add(a[i++]);
      } else {
        out.add(b[j++]);
      }
    }
    return [...out, ...a.skip(i), ...b.skip(j)];
  }

  if (k == 0) {
    return {
      'ids': <int>[],
      'eligible': rows.length,
      'comparisons': 0,
      'selection_slots': 0,
    };
  }
  late List<Map<String, dynamic>> selected;
  late int slots;
  if (method == 'merge') {
    selected = mergeSort(rows.toList()).take(k).toList();
    slots = rows.length;
  } else {
    final heap = <Map<String, dynamic>>[];
    for (final row in rows) {
      if (heap.length < k) {
        heap.add(row);
        var i = heap.length - 1;
        while (i > 0) {
          final parent = (i - 1) ~/ 2;
          if (!better(heap[parent], heap[i])) break;
          final saved = heap[i];
          heap[i] = heap[parent];
          heap[parent] = saved;
          i = parent;
        }
      } else if (better(row, heap.first)) {
        heap[0] = row;
        var i = 0;
        while (2 * i + 1 < heap.length) {
          var child = 2 * i + 1;
          if (child + 1 < heap.length && better(heap[child], heap[child + 1])) {
            child++;
          }
          if (!better(heap[i], heap[child])) break;
          final saved = heap[i];
          heap[i] = heap[child];
          heap[child] = saved;
          i = child;
        }
      }
    }
    selected = mergeSort(heap);
    slots = heap.length;
  }
  return {
    'ids': [for (final r in selected) r['id']],
    'eligible': rows.length,
    'comparisons': comparisons,
    'selection_slots': slots,
  };
}

Map<String, dynamic> practiceMetrics(
  List<Map<String, dynamic>> rows, {
  double threshold = .5,
  String bug = 'none',
  int fpCost = 10,
}) {
  if (!threshold.isFinite ||
      threshold < 0 ||
      threshold > 1 ||
      fpCost < 0 ||
      !['none', 'precision_swap', 'logit_threshold'].contains(bug)) {
    throw ArgumentError('Invalid diagnostic request');
  }
  var tp = 0, fp = 0, tn = 0, fn = 0;
  var loss = 0.0;
  for (final r in rows) {
    final z = (r['logit'] as num).toDouble(),
        score = (r['score'] as num).toDouble(),
        y = r['label'];
    if (!z.isFinite ||
        !score.isFinite ||
        score < 0 ||
        score > 1 ||
        (y != 0 && y != 1)) {
      throw ArgumentError('Invalid diagnostic row');
    }
    final predicted = (bug == 'logit_threshold' ? z : score) >= threshold;
    if (predicted && y == 1) {
      tp++;
    } else if (predicted) {
      fp++;
    } else if (y == 1) {
      fn++;
    } else {
      tn++;
    }
    loss += math.max(z, 0) - z * (y as int) + math.log(1 + math.exp(-z.abs()));
  }
  final precision = tp + fp > 0 ? tp / (tp + fp) : null,
      recall = tp + fn > 0 ? tp / (tp + fn) : null;
  return {
    'n': rows.length,
    'threshold': threshold,
    'bug': bug,
    'fp_cost': fpCost,
    'tp': tp,
    'fp': fp,
    'tn': tn,
    'fn': fn,
    'precision': precision,
    'recall': recall,
    'reported_precision': bug == 'precision_swap' ? recall : precision,
    'accuracy': rows.isNotEmpty ? (tp + tn) / rows.length : null,
    'fpr': fp + tn > 0 ? fp / (fp + tn) : null,
    'symbolic_cost': fpCost * fp + fn,
    'bce': rows.isNotEmpty ? loss / rows.length : null,
  };
}

class PracticeAssets {
  final Map<String, dynamic> data, source;
  PracticeAssets(this.data, this.source);
  static PracticeAssets? _cached;
  static Future<PracticeAssets>? _pending;
  static Future<PracticeAssets> load() async =>
      _cached ??= await (_pending ??= _load());
  static Future<PracticeAssets> _load() async {
    final strings = await Future.wait([
      rootBundle.loadString(
        'assets/datasets/interview_practice/interview_lab.json',
      ),
      rootBundle.loadString('assets/datasets/system_design/design_lab.json'),
    ]);
    return PracticeAssets(jsonDecode(strings[0]), jsonDecode(strings[1]));
  }

  late final catalog = [
    for (final r in data['catalog']) Map<String, dynamic>.from(r),
  ];
  late final diagnostics = <Map<String, dynamic>>[
    for (final r in source['spam']['validation']) _diagnostic(r),
  ];
  Map<String, dynamic> _diagnostic(dynamic r) {
    final m = source['spam']['model'];
    var z = (m['intercept'] as num).toDouble();
    for (var j = 0; j < 57; j++) {
      z +=
          (m['weights'][j] as num) *
          ((r['features'][j] as num) - (m['mean'][j] as num)) /
          (m['scale'][j] as num);
    }
    final e = math.exp(-z.abs());
    return {
      'index': r['index'],
      'label': r['label'],
      'logit': z,
      'score': z >= 0 ? 1 / (1 + e) : e / (1 + e),
    };
  }
}

class PracticeSqlPlan {
  final String sql;
  final List<Object?> parameters;
  PracticeSqlPlan(this.sql, this.parameters);
}

PracticeSqlPlan practiceSqlPlan({
  String task = 'summary',
  String variant = 'fixed',
  String genre = 'All',
  int minimum = 10,
  int k = 10,
}) {
  if (!['summary', 'top_movies', 'latest_user'].contains(task) ||
      !['fixed', 'fanout'].contains(variant) ||
      !['All', 'Comedy', 'Drama', 'Action'].contains(genre) ||
      minimum < 1 ||
      k < 0) {
    throw ArgumentError('Invalid SQL practice selection');
  }
  final eligible = variant == 'fixed'
      ? "SELECT r.* FROM ratings r WHERE (?='All' OR EXISTS(SELECT 1 FROM movie_genres g WHERE g.movie_id=r.movie_id AND g.genre=?))"
      : "SELECT r.* FROM ratings r JOIN movie_genres g ON g.movie_id=r.movie_id WHERE (?='All' OR g.genre=?)";
  final prefix = 'WITH eligible AS ($eligible) ';
  if (task == 'summary') {
    return PracticeSqlPlan(
      '${prefix}SELECT COUNT(*) AS n,COUNT(DISTINCT user_id) AS users,COUNT(DISTINCT movie_id) AS movies,AVG(rating) AS mean FROM eligible',
      [genre, genre],
    );
  }
  if (task == 'top_movies') {
    return PracticeSqlPlan(
      '${prefix}SELECT movie_id,COUNT(*) AS n,AVG(rating) AS mean FROM eligible GROUP BY movie_id HAVING COUNT(*)>=? ORDER BY ROUND(AVG(rating),12) DESC,movie_id ASC LIMIT ?',
      [genre, genre, minimum, k],
    );
  }
  return PracticeSqlPlan(
    '$prefix, ranked AS (SELECT user_id,movie_id,rating,ts,ROW_NUMBER() OVER(PARTITION BY user_id ORDER BY ts DESC,movie_id DESC) AS rn FROM eligible) SELECT user_id,movie_id,rating,ts FROM ranked WHERE rn=1 ORDER BY user_id ASC LIMIT ?',
    [genre, genre, k],
  );
}

/// Each panel owns a read-only handle; learner database is never opened here.
class PracticeSqlStore {
  final Database db;
  static final _installs = <String, Future<void>>{};
  static final _installed = <String>{};
  PracticeSqlStore(this.db);
  static Future<PracticeSqlStore> open(
    PracticeAssets assets, {
    DatabaseFactory? factory,
    String? path,
  }) async {
    final f = factory ?? databaseFactory;
    final hash = assets.data['report']['database_sha256'] as String;
    final location =
        path ??
        p.join(
          await f.getDatabasesPath(),
          'ml_interview39_${hash.substring(0, 16)}.sqlite',
        );
    if (!_installed.contains(location)) {
      await _installs.putIfAbsent(location, () async {
        final file = File(location);
        if (!await file.exists()) {
          await file.parent.create(recursive: true);
          final bytes = await rootBundle.load(
            'assets/datasets/interview_practice/interview.sqlite',
          );
          await file.writeAsBytes(
            bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
            flush: true,
          );
        }
      });
      _installed.add(location);
      _installs.remove(location);
    }
    final db = await f.openDatabase(
      location,
      options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
    );
    await db.execute('PRAGMA query_only=ON');
    return PracticeSqlStore(db);
  }

  Future<List<Map<String, Object?>>> query(PracticeSqlPlan plan) =>
      db.rawQuery(plan.sql, plan.parameters);
  Future<void> close() => db.close();
}
