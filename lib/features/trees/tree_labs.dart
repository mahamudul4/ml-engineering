import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import 'tree_model.dart';

class SplitLab extends StatefulWidget {
  const SplitLab({super.key});
  @override
  State<SplitLab> createState() => _SplitLabState();
}

class _SplitLabState extends State<SplitLab> {
  final data = TreeAssets.load();
  double threshold = 35;
  int minLeaf = 2;
  TreeCriterion criterion = TreeCriterion.gini;
  @override
  Widget build(BuildContext context) => FutureBuilder<TreeAssets>(
    future: data,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Panel(
          child: Text('Bundled tree data could not be read. Reopen the lab.'),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final rows = snapshot.data!.rows;
      final score = SplitScore.compute(
        rows,
        threshold,
        criterion: criterion,
        minLeaf: minLeaf,
      );
      final best = SplitScore.bestThreshold(
        rows,
        criterion: criterion,
        minLeaf: minLeaf,
      );
      return Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Tag('CLASSICAL ML · CHAPTER 04 · SPLIT EXPLORER', icon: Icons.call_split),
            const SizedBox(height: 18),
            const Text(
              'One question. Two child nodes.',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            const Text(
              'Original Adult file-এর প্রথম 24টি row: age দিয়ে >50K label আলাদা করার একটি split calculator। এটি trained full model বা validation result নয়।',
              style: TextStyle(fontFamily: 'NotoSansBengali', height: 2),
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<TreeCriterion>(
              key: ValueKey(criterion),
              initialValue: criterion,
              decoration: const InputDecoration(
                labelText: 'Impurity criterion',
              ),
              items: const [
                DropdownMenuItem(
                  value: TreeCriterion.gini,
                  child: Text('Gini'),
                ),
                DropdownMenuItem(
                  value: TreeCriterion.entropy,
                  child: Text('Entropy (bits)'),
                ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => criterion = v);
              },
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<int>(
              key: ValueKey(minLeaf),
              initialValue: minLeaf,
              decoration: const InputDecoration(
                labelText: 'Minimum rows in each child',
              ),
              items: [
                for (final n in [1, 2, 5, 10, 13])
                  DropdownMenuItem(value: n, child: Text('$n')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => minLeaf = v);
              },
            ),
            const SizedBox(height: 20),
            Text(
              'Rule: age ≤ ${threshold.toStringAsFixed(1)} → left',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Slider(
              key: const Key('tree-threshold'),
              value: threshold,
              min: 15,
              max: 75,
              divisions: 120,
              label: threshold.toStringAsFixed(1),
              onChanged: (v) => setState(() => threshold = v),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Tag(
                  'Parent impurity: ${score.parentImpurity.toStringAsFixed(4)}',
                ),
                Tag(
                  score.childImpurity == null
                      ? 'Child impurity: undefined (empty child)'
                      : 'Weighted child impurity: ${score.childImpurity!.toStringAsFixed(4)}',
                ),
                Tag(
                  score.gain == null
                      ? 'Gain: undefined'
                      : 'Gain: ${score.gain!.toStringAsFixed(4)}',
                ),
                Tag(
                  score.admissible
                      ? 'Admissible split'
                      : 'Rejected by min-leaf rule',
                  color: score.admissible ? null : const Color(0xFFB36D28),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _BranchDiagram(threshold: threshold, score: score),
            const SizedBox(height: 18),
            const Text(
              'Source rows · green = >50K · amber = ≤50K',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final row in rows)
                  Tag(
                    '#${row.sourceRow} · ${row.age.toInt()} · ${row.age <= threshold ? 'L' : 'R'}',
                    color: row.positive == 1 ? null : const Color(0xFFB36D28),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              best == null
                  ? 'No admissible threshold for this min-leaf setting.'
                  : 'Best admissible midpoint: ${best.toStringAsFixed(1)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  key: const Key('tree-best'),
                  onPressed: best == null
                      ? null
                      : () => setState(() => threshold = best),
                  child: const Text('Use best midpoint'),
                ),
                TextButton(
                  key: const Key('tree-empty'),
                  onPressed: () => setState(() => threshold = 75),
                  child: const Text('Show empty child'),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    threshold = 35;
                    minLeaf = 2;
                    criterion = TreeCriterion.gini;
                  }),
                  child: const Text('Reset split'),
                ),
              ],
            ),
            const Text(
              'Gain uses child-size weights. Equal ages always go to the same side; equality routes left. Best searches distinct adjacent ages and keeps the smallest midpoint on ties. Pure Dart calculations on bundled real observations; no Python runs in the app.',
              style: TextStyle(fontSize: 10, height: 1.8),
            ),
          ],
        ),
      );
    },
  );
}

class _BranchDiagram extends StatelessWidget {
  final double threshold;
  final SplitScore score;
  const _BranchDiagram({required this.threshold, required this.score});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Center(child: Tag('age ≤ ${threshold.toStringAsFixed(1)} ?')),
      const SizedBox(height: 8),
      const Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [Icon(Icons.south_west), Icon(Icons.south_east)],
      ),
      const SizedBox(height: 8),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _leaf('LEFT · yes', score.leftCount, score.leftPositive),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _leaf('RIGHT · no', score.rightCount, score.rightPositive),
          ),
        ],
      ),
    ],
  );
  Widget _leaf(String title, int n, int positive) => Panel(
    child: Column(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          '$n rows · $positive positive',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 6),
        Text(
          n == 0 ? 'p: undefined' : 'p: ${(positive / n).toStringAsFixed(3)}',
          style: const TextStyle(fontSize: 12),
        ),
      ],
    ),
  );
}

class PruningLab extends StatefulWidget {
  const PruningLab({super.key});
  @override
  State<PruningLab> createState() => _PruningLabState();
}

class _PruningLabState extends State<PruningLab> {
  final data = TreeAssets.load();
  int stage = 0;
  @override
  Widget build(BuildContext context) => FutureBuilder<TreeAssets>(
    future: data,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Panel(
          child: Text(
            'Bundled pruning path could not be read. Reopen the lab.',
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final asset = snapshot.data!, path = asset.path, node = path[stage];
      return Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Tag(
              'CLASSICAL ML · CHAPTER 04 · PRUNING PATH',
              icon: Icons.account_tree_outlined,
            ),
            const SizedBox(height: 18),
            const Text(
              'Pay for each leaf.',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            const Text(
              'Adult training data-তে age ও education_num দিয়ে fixed depth-5 tree fit করা হয়েছে। Training-only cost-complexity path-এর precomputed subtrees দেখুন; slider runtime training করে না।',
              style: TextStyle(fontFamily: 'NotoSansBengali', height: 2),
            ),
            const SizedBox(height: 18),
            Tag(
              'Train: ${asset.trainRows} · Development validation: ${asset.validRows}',
            ),
            const SizedBox(height: 16),
            Text(
              'Pruning stage: $stage / ${path.length - 1}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Slider(
              key: const Key('tree-pruning'),
              value: stage.toDouble(),
              min: 0,
              max: (path.length - 1).toDouble(),
              divisions: path.length - 1,
              label: '$stage',
              onChanged: (v) => setState(() => stage = v.round()),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Tag('Alpha: ${node.alpha.toStringAsFixed(6)}'),
                Tag('Leaves: ${node.leaves}'),
                Tag('Depth: ${node.depth}'),
                Tag(node.leaves == 1 ? 'Root-only tree' : 'Multi-leaf tree'),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Rα(T) = ${node.risk.toStringAsFixed(5)} + ${node.alpha.toStringAsFixed(6)} × ${node.leaves}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Penalized training objective: ${node.objective(node.alpha).toStringAsFixed(5)}',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Tag(
                  'Train accuracy: ${(node.trainAccuracy * 100).toStringAsFixed(2)}%',
                ),
                Tag(
                  'Validation accuracy: ${(node.validAccuracy * 100).toStringAsFixed(2)}%',
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'Each point is a fitted subtree · horizontal axis = pruning stage',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Semantics(
              label:
                  'Training and development validation accuracy across ${path.length} pruning stages. Current subtree has ${node.leaves} leaves.',
              child: SizedBox(
                height: 260,
                width: double.infinity,
                child: CustomPaint(
                  painter: _PruningPainter(
                    path,
                    stage,
                    Theme.of(context).brightness == Brightness.dark
                        ? lime
                        : forest,
                  ),
                ),
              ),
            ),
            const Text(
              'Green: training accuracy · Amber: development validation accuracy. Axis is stage index, not evenly spaced alpha. Accuracy need not improve monotonically when pruning.',
              style: TextStyle(fontSize: 10, height: 1.8),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  key: const Key('tree-root'),
                  onPressed: () => setState(() => stage = path.length - 1),
                  child: const Text('Prune to root'),
                ),
                TextButton(
                  onPressed: () => setState(() => stage = 0),
                  child: const Text('Restore full tree'),
                ),
              ],
            ),
            const Text(
              'R(T) হলো training sample-weighted leaf Gini, classification error নয়। Alpha-এর units সেই impurity objective-এর units। Path training থেকে; validation দেখে stage পছন্দ করা development selection। এই reused historical source fresh test, causal evidence বা deployment claim নয়।',
              style: TextStyle(
                fontFamily: 'NotoSansBengali',
                fontSize: 12,
                height: 2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Original UCI Adult · Becker & Kohavi (1996), CC BY 4.0. min_samples_leaf=100, random_state=42; profile groups are proxies, not verified independent persons. fnlwgt weights unused. Numeric snapshots are bundled with source hash and reproducible Python workflow.',
              style: TextStyle(fontSize: 10, height: 1.8),
            ),
          ],
        ),
      );
    },
  );
}

class _PruningPainter extends CustomPainter {
  final List<PruningSnapshot> path;
  final int stage;
  final Color color;
  _PruningPainter(this.path, this.stage, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    const left = 42.0, top = 15.0, bottom = 30.0;
    final width = size.width - left - 16, height = size.height - top - bottom;
    double x(int i) => left + width * i / (path.length - 1);
    double y(double accuracy) =>
        top + height * (1 - accuracy); // Full 0..1 scale.
    void label(String text, Offset position) {
      (TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(fontFamily: 'Manrope', fontSize: 10, color: color),
        ),
        textDirection: TextDirection.ltr,
      )..layout()).paint(canvas, position);
    }

    for (final tick in [0.0, .25, .5, .75, 1.0]) {
      canvas.drawLine(
        Offset(left, y(tick)),
        Offset(left + width, y(tick)),
        Paint()..color = color.withValues(alpha: .12),
      );
      label('${(tick * 100).toInt()}%', Offset(0, y(tick) - 6));
    }
    canvas.drawLine(
      Offset(x(stage), top),
      Offset(x(stage), top + height),
      Paint()..color = color.withValues(alpha: .35),
    );
    for (var i = 0; i < path.length; i++) {
      for (final train in [true, false]) {
        final shade = train ? color : const Color(0xFFB36D28);
        double value(int index) =>
            train ? path[index].trainAccuracy : path[index].validAccuracy;
        if (i > 0) {
          canvas.drawLine(
            Offset(x(i - 1), y(value(i - 1))),
            Offset(x(i), y(value(i))),
            Paint()
              ..color = shade
              ..strokeWidth = 2,
          );
        }
        canvas.drawCircle(
          Offset(x(i), y(value(i))),
          i == stage ? 5 : 2.5,
          Paint()..color = shade,
        );
      }
    }
    for (final i in {0, stage, path.length - 1}) {
      label('$i', Offset(x(i) - 3, size.height - 18));
    }
  }

  @override
  bool shouldRepaint(covariant _PruningPainter old) =>
      old.stage != stage || old.color != color || old.path != path;
}
