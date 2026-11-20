import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

enum TreeCriterion { gini, entropy }

double binaryImpurity(int positives, int count, TreeCriterion criterion) {
  if (count < 1 || positives < 0 || positives > count) {
    throw ArgumentError('Nonempty valid binary counts required.');
  }
  final p = positives / count;
  if (criterion == TreeCriterion.gini) return 2 * p * (1 - p);
  if (p == 0 || p == 1) return 0;
  return -(p * log(p) + (1 - p) * log(1 - p)) / ln2;
}

class TreeObservation {
  final int sourceRow, positive;
  final double age;
  TreeObservation(this.sourceRow, this.age, this.positive) {
    if (sourceRow < 1 || !age.isFinite || (positive != 0 && positive != 1)) {
      throw ArgumentError(
        'Valid source row, finite age and binary label required.',
      );
    }
  }
}

class SplitScore {
  final int leftCount, rightCount, leftPositive, rightPositive;
  final double parentImpurity;
  final double? childImpurity, gain;
  final bool admissible;
  SplitScore._(
    this.leftCount,
    this.rightCount,
    this.leftPositive,
    this.rightPositive,
    this.parentImpurity,
    this.childImpurity,
    this.gain,
    this.admissible,
  );
  factory SplitScore.compute(
    List<TreeObservation> rows,
    double threshold, {
    TreeCriterion criterion = TreeCriterion.gini,
    int minLeaf = 2,
  }) {
    if (rows.isEmpty || !threshold.isFinite || minLeaf < 1) {
      throw ArgumentError(
        'Nonempty data, finite threshold and positive minLeaf required.',
      );
    }
    var left = 0, lp = 0, rp = 0;
    for (final row in rows) {
      if (row.age <= threshold) {
        left++;
        lp += row.positive;
      } else {
        rp += row.positive;
      }
    }
    final right = rows.length - left;
    final parent = binaryImpurity(lp + rp, rows.length, criterion);
    final child = left == 0 || right == 0
        ? null
        : (left * binaryImpurity(lp, left, criterion) +
                  right * binaryImpurity(rp, right, criterion)) /
              rows.length;
    return SplitScore._(
      left,
      right,
      lp,
      rp,
      parent,
      child,
      child == null ? null : parent - child,
      left >= minLeaf && right >= minLeaf,
    );
  }
  static double? bestThreshold(
    List<TreeObservation> rows, {
    TreeCriterion criterion = TreeCriterion.gini,
    int minLeaf = 2,
  }) {
    if (rows.isEmpty || minLeaf < 1) {
      throw ArgumentError('Invalid split search.');
    }
    final values = rows.map((r) => r.age).toSet().toList()..sort();
    double? best;
    var bestGain = double.negativeInfinity;
    for (var i = 1; i < values.length; i++) {
      final t = values[i - 1] / 2 + values[i] / 2;
      final score = SplitScore.compute(
        rows,
        t,
        criterion: criterion,
        minLeaf: minLeaf,
      );
      if (score.admissible && score.gain! > bestGain + 1e-12) {
        best = t;
        bestGain = score.gain!;
      }
    }
    return best;
  }
}

class PruningSnapshot {
  final double alpha, risk, trainAccuracy, validAccuracy;
  final int leaves, depth;
  PruningSnapshot.fromJson(Map<String, dynamic> j)
    : alpha = (j['alpha'] as num).toDouble(),
      risk = (j['risk'] as num).toDouble(),
      trainAccuracy = (j['train_accuracy'] as num).toDouble(),
      validAccuracy = (j['valid_accuracy'] as num).toDouble(),
      leaves = j['leaves'],
      depth = j['depth'] {
    if (!alpha.isFinite ||
        alpha < 0 ||
        leaves < 1 ||
        depth < 0 ||
        [
          risk,
          trainAccuracy,
          validAccuracy,
        ].any((x) => !x.isFinite || x < 0 || x > 1)) {
      throw FormatException('Invalid pruning snapshot.');
    }
  }
  double objective(double penalty) {
    if (!penalty.isFinite || penalty < 0) {
      throw ArgumentError('Nonnegative finite alpha required.');
    }
    return risk + penalty * leaves;
  }
}

class TreeAssets {
  static TreeAssets? _loaded;
  final List<TreeObservation> rows;
  final List<PruningSnapshot> path;
  final int trainRows, validRows;
  TreeAssets._(
    List<TreeObservation> rows,
    List<PruningSnapshot> path,
    this.trainRows,
    this.validRows,
  ) : rows = List.unmodifiable(rows),
      path = List.unmodifiable(path);
  static Future<TreeAssets> load() async {
    if (_loaded != null) return _loaded!;
    final data = await Future.wait([
      rootBundle.loadString('assets/datasets/adult/tree_split_lab.json'),
      rootBundle.loadString('assets/datasets/adult/tree_pruning_lab.json'),
    ]);
    final assets = TreeAssets.fromJson(
      jsonDecode(data[0]),
      jsonDecode(data[1]),
    );
    _loaded = assets;
    return assets;
  }

  factory TreeAssets.fromJson(
    Map<String, dynamic> split,
    Map<String, dynamic> pruning,
  ) {
    if (split['sha256'] != pruning['sha256'] ||
        split['sha256'] !=
            '5b00264637dbfec36bdeaab5676b0b309ff9eb788d63554ca0a249491c86603d') {
      throw FormatException('Expected original bundled source.');
    }
    final rows = [
      for (final j in split['rows'])
        TreeObservation(
          j['source_row_1based'],
          (j['age'] as num).toDouble(),
          j['positive'],
        ),
    ];
    final path = [
      for (final j in pruning['snapshots']) PruningSnapshot.fromJson(j),
    ];
    if (rows.isEmpty ||
        rows.map((r) => r.sourceRow).toSet().length != rows.length ||
        path.length < 2 ||
        pruning['train_rows'] < 1 ||
        pruning['valid_rows'] < 1) {
      throw FormatException('Empty or inconsistent lab data.');
    }
    for (var i = 1; i < path.length; i++) {
      if (path[i].alpha < path[i - 1].alpha ||
          path[i].leaves > path[i - 1].leaves ||
          path[i].risk < path[i - 1].risk - 1e-12) {
        throw FormatException('Invalid nested pruning path.');
      }
    }
    return TreeAssets._(
      rows,
      path,
      pruning['train_rows'],
      pruning['valid_rows'],
    );
  }
}
