import 'dart:math';

import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import 'ensemble_model.dart';

class BaggingLab extends StatefulWidget {
  const BaggingLab({super.key});
  @override
  State<BaggingLab> createState() => _BaggingLabState();
}

class _BaggingLabState extends State<BaggingLab> {
  final data = EnsembleAssets.load();
  int point = 0, count = 1;
  bool oob = false;
  @override
  Widget build(BuildContext context) => FutureBuilder<EnsembleAssets>(
    future: data,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Panel(
          child: Text(
            'Bundled ensemble data could not be read. Reopen the lab.',
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final asset = snapshot.data!, row = asset.points[point];
      final average = MemberAverage.compute(
        row.probabilities,
        row.inBag,
        count: count,
        oobOnly: oob,
      );
      return Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Tag('CLASSICAL ML · CHAPTER 05 · BAGGING & OOB', icon: Icons.hub_outlined),
            const SizedBox(height: 18),
            const Text(
              'Which trees may vote?',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            const Text(
              'Real Adult training observations; 24টি fixed bootstrap tree-এর probabilities ও membership bundled আছে। Row-level OOB মানে ওই row training draw-এ ছিল না; related profile peers বাদ পড়েছে এমন নয়।',
              style: TextStyle(fontFamily: 'NotoSansBengali', height: 2),
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<int>(
              key: ValueKey('bag-point-$point'),
              initialValue: point,
              decoration: const InputDecoration(
                labelText: 'Actual source observation',
              ),
              items: [
                for (var i = 0; i < asset.points.length; i++)
                  DropdownMenuItem(
                    value: i,
                    child: Text('Row #${asset.points[i].sourceRow}'),
                  ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => point = v);
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Members considered: $count / ${asset.members}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Slider(
              key: const Key('ensemble-members'),
              value: count.toDouble(),
              min: 1,
              max: asset.members.toDouble(),
              divisions: asset.members - 1,
              label: '$count',
              onChanged: (v) => setState(() => count = v.round()),
            ),
            SwitchListTile(
              key: const Key('ensemble-oob'),
              contentPadding: EdgeInsets.zero,
              value: oob,
              onChanged: (v) => setState(() => oob = v),
              title: const Text(
                'Only OOB members',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Exclude trees whose bootstrap draw included this row.',
                style: TextStyle(fontSize: 10),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Tag('Eligible members: ${average.eligible}'),
                Tag('Observed label: ${row.positive == 1 ? '>50K' : '≤50K'}'),
                Tag('Hard positive votes: ${average.hardPositive}'),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              average.probability == null
                  ? 'Prediction unavailable (no OOB members)'
                  : 'Mean positive probability: ${average.probability!.toStringAsFixed(4)}',
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            const Text(
              'Soft averaging uses probabilities, not the majority of hard labels. Empty OOB support is undefined, never silently replaced with zero.',
              style: TextStyle(fontSize: 11, height: 1.8),
            ),
            const SizedBox(height: 18),
            const Text(
              'Each chip: tree number · probability · training membership',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < count; i++)
                  Tag(
                    '${i + 1} · ${row.probabilities[i].toStringAsFixed(2)} · ${row.inBag[i] ? 'in-bag' : 'OOB'}',
                    color: oob && row.inBag[i] ? const Color(0xFFB36D28) : null,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  key: const Key('ensemble-all'),
                  onPressed: () => setState(() => count = asset.members),
                  child: const Text('Use all 24 members'),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    point = 0;
                    count = 1;
                    oob = false;
                  }),
                  child: const Text('Reset bagging'),
                ),
              ],
            ),
            const Text(
              'Depth4/min_leaf20, bootstrap n draws, random_state42. Parameters are fixed for teaching; this calculator does not retrain. No group-safe performance claim from row-OOB; no Python runs here.',
              style: TextStyle(fontSize: 10, height: 1.8),
            ),
          ],
        ),
      );
    },
  );
}

class BoostingLab extends StatefulWidget {
  const BoostingLab({super.key});
  @override
  State<BoostingLab> createState() => _BoostingLabState();
}

class _BoostingLabState extends State<BoostingLab> {
  final data = EnsembleAssets.load();
  int run = 0, round = 0, probe = 0;
  @override
  Widget build(BuildContext context) => FutureBuilder<EnsembleAssets>(
    future: data,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Panel(
          child: Text(
            'Bundled boosting data could not be read. Reopen the lab.',
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final asset = snapshot.data!,
          model = asset.runs[run],
          prediction = model.predictions[probe][round],
          target = asset.targets[probe];
      return Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Tag(
              'CLASSICAL ML · CHAPTER 05 · RESIDUAL BOOSTING',
              icon: Icons.stacked_line_chart,
            ),
            const SizedBox(height: 18),
            const Text(
              'Add a correction. Recompute the residual.',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            const Text(
              'Real Adult hours_per_week regression: age ও education_num, fixed depth2/min_leaf100। প্রতিটি learning rate-এর জন্য আলাদাভাবে trees refit হয়েছে; একটি path শুধু rescale করা হয়নি। নিচের actual validation rows training-এ ব্যবহৃত হয়নি।',
              style: TextStyle(fontFamily: 'NotoSansBengali', height: 2),
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<int>(
              key: ValueKey('boost-run-$run'),
              initialValue: run,
              decoration: const InputDecoration(labelText: 'Learning rate η'),
              items: [
                for (var i = 0; i < asset.runs.length; i++)
                  DropdownMenuItem(
                    value: i,
                    child: Text(asset.runs[i].rate.toStringAsFixed(1)),
                  ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => run = v);
              },
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              key: ValueKey('boost-probe-$probe'),
              initialValue: '$probe',
              decoration: const InputDecoration(
                labelText: 'Actual validation observation',
              ),
              items: [
                for (var i = 0; i < asset.probeRows.length; i++)
                  DropdownMenuItem(
                    value: '$i',
                    child: Text('Row #${asset.probeRows[i]}'),
                  ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => probe = int.parse(v));
              },
            ),
            const SizedBox(height: 18),
            Text(
              'Boosting round: $round / ${asset.rounds}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Slider(
              key: const Key('ensemble-round'),
              value: round.toDouble(),
              min: 0,
              max: asset.rounds.toDouble(),
              divisions: asset.rounds,
              label: '$round',
              onChanged: (v) => setState(() => round = v.round()),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Tag('Observed hours: ${target.toStringAsFixed(1)}'),
                Tag('Prediction: ${prediction.toStringAsFixed(3)} h'),
                Tag(
                  'Residual y − F: ${(target - prediction).toStringAsFixed(3)} h',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              round == 0
                  ? 'Round 0: training-mean baseline'
                  : 'Update: ${model.predictions[probe][round - 1].toStringAsFixed(3)} + ${model.rate.toStringAsFixed(1)} × ${model.outputs[probe][round - 1].toStringAsFixed(3)} = ${prediction.toStringAsFixed(3)}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Tag(
                  'Train RMSE: ${model.trainRmse[round].toStringAsFixed(3)} h',
                ),
                Tag(
                  'Validation RMSE: ${model.validRmse[round].toStringAsFixed(3)} h',
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'RMSE in hours · same group split for each fixed run',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Semantics(
              label:
                  'Training and validation RMSE over ${asset.rounds} boosting rounds. Selected round $round.',
              child: SizedBox(
                height: 260,
                width: double.infinity,
                child: CustomPaint(
                  painter: _BoostPainter(
                    model,
                    round,
                    Theme.of(context).brightness == Brightness.dark
                        ? lime
                        : forest,
                  ),
                ),
              ),
            ),
            const Text(
              'Green: train · Amber: development validation. The selected row residual is a diagnostic; target values never enter its prediction. Squared-loss negative gradients equal residuals; other losses differ.',
              style: TextStyle(fontSize: 10, height: 1.8),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  key: const Key('ensemble-next'),
                  onPressed: round == asset.rounds
                      ? null
                      : () => setState(() => round++),
                  child: const Text('Add one round'),
                ),
                TextButton(
                  key: const Key('ensemble-final'),
                  onPressed: () => setState(() => round = asset.rounds),
                  child: const Text('Show round 16'),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    run = 0;
                    round = 0;
                    probe = 0;
                  }),
                  child: const Text('Reset boosting'),
                ),
              ],
            ),
            const Text(
              'Curves precomputed from fixed runs; no runtime fitting or automatic early stopping. Validation দেখে rate/round বাছলে সেটি development selection। Reused historical source; no fresh-test, causal বা deployment claim।',
              style: TextStyle(
                fontFamily: 'NotoSansBengali',
                height: 2,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Train ${asset.trainRows} · Validation ${asset.validRows} · UCI Adult, Becker & Kohavi (1996), CC BY 4.0. Source hash and reproducible code bundled; profile groups are proxies, fnlwgt unused.',
              style: const TextStyle(fontSize: 10, height: 1.8),
            ),
          ],
        ),
      );
    },
  );
}

class _BoostPainter extends CustomPainter {
  final BoostRun run;
  final int round;
  final Color color;
  _BoostPainter(this.run, this.round, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    const left = 45.0, top = 16.0, bottom = 28.0;
    final width = size.width - left - 16, height = size.height - top - bottom;
    final maximum = [...run.trainRmse, ...run.validRmse].reduce(max) * 1.1;
    double x(int t) => left + width * t / (run.trainRmse.length - 1);
    double y(double v) => top + height * (1 - v / maximum);
    void label(String s, Offset position) {
      (TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(fontFamily: 'Manrope', fontSize: 10, color: color),
        ),
        textDirection: TextDirection.ltr,
      )..layout()).paint(canvas, position);
    }

    for (var k = 0; k <= 4; k++) {
      final v = maximum * k / 4;
      canvas.drawLine(
        Offset(left, y(v)),
        Offset(left + width, y(v)),
        Paint()..color = color.withValues(alpha: .12),
      );
      label(v.toStringAsFixed(1), Offset(0, y(v) - 6));
    }
    canvas.drawLine(
      Offset(x(round), top),
      Offset(x(round), top + height),
      Paint()..color = color.withValues(alpha: .35),
    );
    for (final train in [true, false]) {
      final values = train ? run.trainRmse : run.validRmse,
          shade = train ? color : const Color(0xFFB36D28);
      for (var i = 0; i < values.length; i++) {
        if (i > 0) {
          canvas.drawLine(
            Offset(x(i - 1), y(values[i - 1])),
            Offset(x(i), y(values[i])),
            Paint()
              ..color = shade
              ..strokeWidth = 2,
          );
        }
        canvas.drawCircle(
          Offset(x(i), y(values[i])),
          i == round ? 5 : 2.5,
          Paint()..color = shade,
        );
      }
    }
    for (final t in {0, 4, 8, 12, 16, round}) {
      label('$t', Offset(x(t) - 4, size.height - 18));
    }
  }

  @override
  bool shouldRepaint(covariant _BoostPainter old) =>
      old.run != run || old.round != round || old.color != color;
}
