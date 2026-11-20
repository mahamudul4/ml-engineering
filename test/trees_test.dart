import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/features/trees/tree_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  List<TreeObservation> sample(List<int> y) => [
    for (var i = 0; i < y.length; i++)
      TreeObservation(i + 1, i.toDouble(), y[i]),
  ];
  test('Binary impurity has correct scale, symmetry and pure endpoints', () {
    expect(binaryImpurity(1, 4, TreeCriterion.gini), .375);
    expect(binaryImpurity(2, 4, TreeCriterion.gini), .5);
    expect(binaryImpurity(2, 4, TreeCriterion.entropy), 1);
    expect(binaryImpurity(0, 4, TreeCriterion.entropy), 0);
    expect(binaryImpurity(4, 4, TreeCriterion.entropy), 0);
    expect(
      binaryImpurity(1, 4, TreeCriterion.entropy),
      closeTo(.8112781244591328, 1e-12),
    );
    expect(
      binaryImpurity(3, 4, TreeCriterion.entropy),
      binaryImpurity(1, 4, TreeCriterion.entropy),
    );
    expect(() => binaryImpurity(0, 0, TreeCriterion.gini), throwsArgumentError);
    expect(() => binaryImpurity(5, 4, TreeCriterion.gini), throwsArgumentError);
  });
  test(
    'Split uses child sizes, routes equality left and accounts for all labels',
    () {
      final r = SplitScore.compute(sample([0, 0, 0, 1, 1, 1]), 1);
      expect(r.leftCount, 2);
      expect(r.rightCount, 4);
      expect(r.leftPositive, 0);
      expect(r.rightPositive, 3);
      expect(r.parentImpurity, .5);
      expect(r.childImpurity, .25);
      expect(r.gain, .25);
      expect(r.admissible, isTrue);
      expect(
        r.childImpurity,
        isNot(closeTo(.1875, 1e-12)),
        reason: 'Unweighted child average is wrong',
      );
    },
  );
  test(
    'Empty or undersized child is rejected without fabricated zero impurity',
    () {
      final rows = sample([0, 0, 0, 1, 1, 1]);
      final empty = SplitScore.compute(rows, 100);
      expect(empty.admissible, isFalse);
      expect(empty.childImpurity, isNull);
      expect(empty.gain, isNull);
      final small = SplitScore.compute(rows, 0, minLeaf: 2);
      expect(small.admissible, isFalse);
      expect(small.gain, isNotNull);
      expect(() => SplitScore.compute(rows, double.nan), throwsArgumentError);
      expect(() => SplitScore.compute([], 2), throwsArgumentError);
      expect(
        () => SplitScore.compute(rows, 2, minLeaf: 0),
        throwsArgumentError,
      );
    },
  );
  test('Best midpoint is optimal, duplicates never separate, impossible size returns null', () {
    expect(SplitScore.bestThreshold(sample([0, 0, 0, 1, 1, 1])), 2.5);
    final duplicates = [
      TreeObservation(1, 2, 0),
      TreeObservation(2, 2, 1),
      TreeObservation(3, 4, 1),
      TreeObservation(4, 4, 0),
    ];
    expect(SplitScore.bestThreshold(duplicates), 3);
    expect(SplitScore.compute(duplicates, 2).leftCount, 2);
    expect(SplitScore.bestThreshold(duplicates, minLeaf: 3), isNull);
    expect(
      SplitScore.bestThreshold([
        TreeObservation(1, 2, 0),
        TreeObservation(2, 2, 1),
      ], minLeaf: 1),
      isNull,
    );
    expect(() => TreeObservation(1, double.infinity, 0), throwsArgumentError);
    expect(() => TreeObservation(1, 20, 2), throwsArgumentError);
  });
  test('Real source subset has documented counts and best split dominates admissible candidates', () async {
    final assets = await TreeAssets.load();
    expect(assets.rows.length, 24);
    expect(assets.rows.first.age, 39);
    expect(assets.rows.where((r) => r.positive == 1).length, 8);
    for (final criterion in TreeCriterion.values) {
      final best = SplitScore.bestThreshold(assets.rows, criterion: criterion)!;
      final gain = SplitScore.compute(
        assets.rows,
        best,
        criterion: criterion,
      ).gain!;
      for (var t = 15.0; t <= 75; t += .5) {
        final candidate = SplitScore.compute(
          assets.rows,
          t,
          criterion: criterion,
        );
        if (candidate.admissible) {
          expect(gain + 1e-12, greaterThanOrEqualTo(candidate.gain!));
        }
      }
    }
    expect(() => assets.rows.clear(), throwsUnsupportedError);
  });
  test('Bundled pruning path has correct normalization, nested complexity and immutable stages', () async {
    final assets = await TreeAssets.load();
    expect(assets.trainRows, 26050);
    expect(assets.validRows, 6511);
    expect(assets.path.length, 27);
    expect(assets.path.first.leaves, 29);
    final root = assets.path.last;
    expect(root.leaves, 1);
    expect(root.depth, 0);
    expect(root.risk, closeTo(.362474538481659, 1e-12));
    expect(root.objective(.1), closeTo(root.risk + .1, 1e-12));
    for (var i = 1; i < assets.path.length; i++) {
      expect(
        assets.path[i].leaves,
        lessThanOrEqualTo(assets.path[i - 1].leaves),
      );
      expect(
        assets.path[i].risk + 1e-12,
        greaterThanOrEqualTo(assets.path[i - 1].risk),
      );
    }
    expect(() => root.objective(-.1), throwsArgumentError);
    expect(() => assets.path.clear(), throwsUnsupportedError);
  });
  test(
    'Corrupt asset provenance and invalid path stages fail explicitly',
    () async {
      final split = jsonDecode(
        await rootBundle.loadString(
          'assets/datasets/adult/tree_split_lab.json',
        ),
      ) as Map<String, dynamic>;
      final pruning = jsonDecode(
        await rootBundle.loadString(
          'assets/datasets/adult/tree_pruning_lab.json',
        ),
      ) as Map<String, dynamic>;
      expect(
        () => TreeAssets.fromJson({...split, 'sha256': 'wrong'}, pruning),
        throwsFormatException,
      );
      final bad = jsonDecode(jsonEncode(pruning)) as Map<String, dynamic>;
      bad['snapshots'][1]['leaves'] = 1000;
      expect(() => TreeAssets.fromJson(split, bad), throwsFormatException);
      expect(
        () => PruningSnapshot.fromJson({
          'alpha': -.1,
          'risk': .1,
          'train_accuracy': .8,
          'valid_accuracy': .8,
          'leaves': 1,
          'depth': 0,
        }),
        throwsFormatException,
      );
    },
  );
}
