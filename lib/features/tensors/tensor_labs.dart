import 'dart:math';

import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import 'tensor_model.dart';

const _bn = TextStyle(fontFamily: 'NotoSansBengali', height: 1.9);
const _title = TextStyle(fontSize: 24, fontWeight: FontWeight.w800);
const _gap = SizedBox(height: 16);
Color _accent(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? lime : forest;
Widget _asset(Future<TensorAssets> f, Widget Function(TensorAssets) build) =>
    FutureBuilder<TensorAssets>(
      future: f,
      builder: (c, s) {
        if (s.hasError) {
          return const Panel(
            child: Text(
              'Bundled tensor evidence could not be read. Reopen the lab.',
            ),
          );
        }
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        return build(s.data!);
      },
    );
Widget _source() => const Text(
  'UCI Wine Quality · Cortez et al. (2009) · CC BY 4.0. Actual Chapter14 fit-role source rows only; no new decision/test evaluation। Dart metadata/math mirror locally verified PyTorch CPU float64 examples; app-এ Python/PyTorch engine নেই।',
  style: _bn,
);

class TensorLayoutLab extends StatefulWidget {
  const TensorLayoutLab({super.key});
  @override
  State<TensorLayoutLab> createState() => _TensorLayoutLabState();
}

class _TensorLayoutLabState extends State<TensorLayoutLab> {
  final data = TensorAssets.load();
  String mode = 'original';
  bool copy = false;
  int selected = 0;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final original = a.layout(mode),
        view = copy ? original.contiguous() : original,
        row = selected ~/ view.shape[1],
        col = selected % view.shape[1],
        address = view.elementOffset(row, col),
        accent = _accent(context);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'DEEP LEARNING & RL · CHAPTER 01 · TENSOR LAYOUT',
            icon: Icons.grid_view_outlined,
          ),
          _gap,
          const Text('Shape is a view of storage.', style: _title),
          _gap,
          const Text(
            'চারটি actual training row-এর alcohol / volatile acidity / sulphates দিয়ে 4×3 matrix। View বদলে shape, stride ও element offset অনুসরণ করুন। Storage indices এখানে conceptual element offsets; device memory addresses নয়। Expanded view-এ একই value একাধিক coordinates-এ দেখা যায়।',
            style: _bn,
          ),
          _gap,
          DropdownButtonFormField<String>(
            key: ValueKey('tensor-mode-$mode'),
            initialValue: mode,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Verified PyTorch layout',
            ),
            items: const [
              DropdownMenuItem(
                value: 'original',
                child: Text('Original · [4,3]'),
              ),
              DropdownMenuItem(
                value: 'transpose',
                child: Text('Transpose · [3,4]'),
              ),
              DropdownMenuItem(
                value: 'slice',
                child: Text('Column step 2 · [4,2]'),
              ),
              DropdownMenuItem(
                value: 'expand',
                child: Text('Expand first column · [4,3]'),
              ),
            ],
            onChanged: (v) {
              if (v != null) {
                setState(() {
                  mode = v;
                  copy = false;
                  selected = 0;
                });
              }
            },
          ),
          _gap,
          SwitchListTile(
            key: const Key('tensor-copy'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Inspect contiguous() result'),
            value: copy,
            onChanged: (v) => setState(() => copy = v),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Tag('Shape: ${view.shape}'),
              Tag('Stride: ${view.stride}'),
              Tag('Contiguous: ${view.isContiguous}'),
              Tag('Overlapping cells: ${view.overlaps}'),
            ],
          ),
          _gap,
          for (var i = 0; i < view.shape[0]; i++)
            Row(
              children: [
                for (var j = 0; j < view.shape[1]; j++)
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(3),
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 3,
                      ),
                      decoration: BoxDecoration(
                        color: address == view.elementOffset(i, j)
                            ? accent.withValues(alpha: .18)
                            : accent.withValues(alpha: .04),
                        border: Border.all(
                          color: accent.withValues(alpha: .25),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(
                            view.value(i, j).toStringAsFixed(3),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '[$i,$j] → ${view.elementOffset(i, j)}',
                            style: const TextStyle(fontSize: 9),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          _gap,
          DropdownButtonFormField<int>(
            key: ValueKey('tensor-cell-$mode-$copy-$selected'),
            initialValue: selected,
            decoration: const InputDecoration(
              labelText: 'Inspect logical coordinate',
            ),
            items: [
              for (var i = 0; i < view.shape[0] * view.shape[1]; i++)
                DropdownMenuItem(
                  value: i,
                  child: Text('[${i ~/ view.shape[1]}, ${i % view.shape[1]}]'),
                ),
            ],
            onChanged: (v) {
              if (v != null) setState(() => selected = v);
            },
          ),
          _gap,
          Text(
            'Element offset = ${view.offset} + $row × ${view.stride[0]} + $col × ${view.stride[1]} = $address\nfloat64 byte offset = $address × 8 = ${address * 8}\nValue = ${view.value(row, col).toStringAsFixed(4)}',
            style: const TextStyle(height: 1.8),
          ),
          _gap,
          const Text('Conceptual storage buffer · highlighted address'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              for (var i = 0; i < view.storage.length; i++)
                Container(
                  width: 52,
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: i == address ? .2 : .04),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$i\n${view.storage[i].toStringAsFixed(2)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
            ],
          ),
          _gap,
          Text(
            copy
                ? (original.isContiguous
                      ? 'Already contiguous: PyTorch may return the same tensor/storage.'
                      : 'Non-contiguous source: contiguous() materializes row-major values.')
                : 'View metadata only; no in-place writes in this lab.',
            style: _bn,
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                key: const Key('tensor-transpose'),
                onPressed: () => setState(() {
                  mode = 'transpose';
                  copy = false;
                  selected = 0;
                }),
                child: const Text('Inspect transpose'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  mode = 'original';
                  copy = false;
                  selected = 0;
                }),
                child: const Text('Reset layout'),
              ),
            ],
          ),
          _gap,
          _source(),
        ],
      ),
    );
  });
}

class BroadcastLab extends StatefulWidget {
  const BroadcastLab({super.key});
  @override
  State<BroadcastLab> createState() => _BroadcastLabState();
}

class _BroadcastLabState extends State<BroadcastLab> {
  final data = TensorAssets.load();
  int batch = 4;
  bool column = false;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final probability = a.probabilities(batch),
        labels = a.labels(batch),
        r = BroadcastResult.compute(probability, labels, columnTarget: column),
        correct = BroadcastResult.compute(
          probability,
          labels,
          columnTarget: false,
        ),
        accent = _accent(context);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'DEEP LEARNING & RL · CHAPTER 01 · BROADCAST AUDIT',
            icon: Icons.view_array_outlined,
          ),
          _gap,
          const Text('A valid broadcast can be a bug.', style: _title),
          _gap,
          const Text(
            'Actual fit-row probabilities fixed Chapter14 logistic reference থেকে। [B] prediction থেকে [B,1] target subtract করলে [B,B] pairwise errors হয়। এই MSE shape-debugging example, নতুন classifier objective নয়। BCEWithLogitsLoss exact input/target shape চায় এবং এই mismatch reject করে।',
            style: _bn,
          ),
          _gap,
          DropdownButtonFormField<int>(
            key: ValueKey('broadcast-batch-$batch'),
            initialValue: batch,
            decoration: const InputDecoration(
              labelText: 'Actual training batch size',
            ),
            items: [
              for (final n in [1, 2, 4])
                DropdownMenuItem(
                  value: n,
                  child: Text('$n actual observations'),
                ),
            ],
            onChanged: (v) {
              if (v != null) setState(() => batch = v);
            },
          ),
          _gap,
          SwitchListTile(
            key: const Key('broadcast-column'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Wrong target column [B, 1]'),
            value: column,
            onChanged: (v) => setState(() => column = v),
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Tag('Prediction: [$batch]'),
              Tag(column ? 'Target: [$batch, 1]' : 'Target: [$batch]'),
              Tag('Residual shape: ${r.shape}'),
              Tag('Mean squared error: ${r.mse.toStringAsFixed(6)}'),
            ],
          ),
          _gap,
          for (var i = 0; i < r.residual.length; i++)
            Row(
              children: [
                for (var j = 0; j < r.residual[i].length; j++)
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(3),
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 2,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(
                          alpha: .05 + r.residual[i][j].abs() * .13,
                        ),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: accent.withValues(alpha: .2)),
                      ),
                      child: Text(
                        r.residual[i][j].toStringAsFixed(3),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
              ],
            ),
          _gap,
          Text(
            column
                ? 'Rows index target j, columns index prediction i: p[i] − y[j].'
                : 'One row displays the correct vector: p[i] − y[i].',
            style: _bn,
          ),
          _gap,
          for (var i = 0; i < batch; i++)
            Text(
              'Source row #${a.samples[i].sourceRow}: label ${labels[i].toInt()} · probability ${probability[i].toStringAsFixed(6)}',
              style: const TextStyle(fontSize: 12, height: 1.8),
            ),
          _gap,
          Text(
            'Correct vector MSE: ${correct.mse.toStringAsFixed(6)}\n${column ? 'BCE shape contract: rejected' : 'BCE shape contract: aligned'}',
            style: const TextStyle(height: 1.8, fontWeight: FontWeight.w700),
          ),
          _gap,
          const Text(
            'B=1-এ ভুল shape হয়েও numeric MSE একই হতে পারে। শুধু loss scalar দেখে correctness নিশ্চিত করবেন না। Broadcast-backward replicated axes-এর contributions sum করে; accidental pairwise loss target association বদলে দেয়।',
            style: _bn,
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                key: const Key('broadcast-bug'),
                onPressed: () => setState(() => column = true),
                child: const Text('Inspect pairwise bug'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  batch = 4;
                  column = false;
                }),
                child: const Text('Reset broadcast'),
              ),
            ],
          ),
          _gap,
          _source(),
        ],
      ),
    );
  });
}

class AutogradLab extends StatefulWidget {
  const AutogradLab({super.key});
  @override
  State<AutogradLab> createState() => _AutogradLabState();
}

class _AutogradLabState extends State<AutogradLab> {
  final data = TensorAssets.load();
  List<double> theta = [0, 0, 0];
  double rate = .1;
  int backwards = 1, steps = 0;
  String? guard;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final X = a.gradientX,
        y = a.labels(16),
        result = GradientResult.compute(X, y, theta),
        g = result.gradient.map((v) => v * backwards).toList();
    void step() {
      final proposed = [for (var i = 0; i < 3; i++) theta[i] - rate * g[i]];
      if (proposed.any((v) => !v.isFinite || v.abs() > 4)) {
        setState(
          () => guard = 'Step exceeds the inspected [-4,4] range. Reduce the rate or reset.',
        );
        return;
      }
      setState(() {
        theta = proposed;
        steps++;
        backwards = 1;
        guard = null;
      });
    }

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'DEEP LEARNING & RL · CHAPTER 01 · GRADIENT MICROSCOPE',
            icon: Icons.route_outlined,
          ),
          _gap,
          const Text('Follow the graph. Check the gradient.', style: _title),
          _gap,
          const Text(
            'প্রথম 16 actual fit rows-এর standardized alcohol ও volatile acidity দিয়ে দুই-feature mean BCE microscope। Parameters zero থেকে শুরু; এটি selected/fitted classifier নয়। অন্য features নেই। Dart analytical gradient locally executed PyTorch autograd references-এর সঙ্গে যাচাই করা হয়েছে।',
            style: _bn,
          ),
          _gap,
          Wrap(
            spacing: 6,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: const [
              Tag('X: [16,2]'),
              Icon(Icons.arrow_forward, size: 16),
              Tag('logits: [16]'),
              Icon(Icons.arrow_forward, size: 16),
              Tag('mean BCE: []'),
              Icon(Icons.arrow_back, size: 16),
              Tag('VJP → leaf grads'),
            ],
          ),
          _gap,
          for (var i = 0; i < 3; i++)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${['alcohol weight', 'volatile acidity weight', 'bias'][i]}: ${theta[i].toStringAsFixed(3)}',
                ),
                Slider(
                  key: Key('gradient-parameter-$i'),
                  value: theta[i],
                  min: -4,
                  max: 4,
                  divisions: 80,
                  label: theta[i].toStringAsFixed(2),
                  onChanged: (v) => setState(() {
                    theta = [...theta]..[i] = v;
                    steps = 0;
                    backwards = 1;
                    guard = null;
                  }),
                ),
              ],
            ),
          DropdownButtonFormField<double>(
            key: ValueKey('gradient-rate-$rate'),
            initialValue: rate,
            decoration: const InputDecoration(
              labelText: 'Manual step learning rate',
            ),
            items: [
              for (final v in [.01, .1, .5, 2.0])
                DropdownMenuItem(value: v, child: Text('$v')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => rate = v);
            },
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Tag('Mean BCE: ${result.loss.toStringAsFixed(6)}'),
              Tag('Backward passes: $backwards'),
              Tag('Manual steps: $steps'),
            ],
          ),
          _gap,
          Text(
            'Accumulated gradients [dw0, dw1, db]\n[${g.map((v) => v.toStringAsFixed(6)).join(', ')}]',
            style: const TextStyle(height: 1.8),
          ),
          _gap,
          Semantics(
            label: 'Equal-axis mean BCE loss slice on real training rows. Current weights marked, normalized arrow points along negative weight gradient. Bias fixed at current displayed value.',
            child: SizedBox(
              height: 300,
              width: double.infinity,
              child: CustomPaint(
                painter: _LossPainter(X, y, theta, _accent(context)),
              ),
            ),
          ),
          const Text(
            'x: alcohol weight · y: volatile acidity weight · lighter = lower loss. Arrow শুধু normalized negative-gradient direction, learning-rate step length নয়। Bias এই slice-এ fixed; actual step bias-ও update করে।',
            style: _bn,
          ),
          _gap,
          if (guard != null) ...[
            Text(
              guard!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            _gap,
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                key: const Key('gradient-step'),
                onPressed: step,
                child: const Text('One gradient step'),
              ),
              OutlinedButton(
                key: const Key('gradient-accumulate'),
                onPressed: () => setState(() => backwards = 2),
                child: const Text('Accumulate twice'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  theta = [0, 0, 0];
                  rate = .1;
                  backwards = 1;
                  steps = 0;
                  guard = null;
                }),
                child: const Text('Reset autograd'),
              ),
            ],
          ),
          _gap,
          const Text(
            'দুই fresh graphs-এ একই parameters দিয়ে backward করলে .grad দ্বিগুণ জমে; loss scalar দ্বিগুণ হয় না। এই control সেই calculation mirror করে। Step-এর পরে count1-এ ফিরে আসে। Actual PyTorch graph, grad buffers ও no_grad update local code-এ execute করতে হবে।',
            style: _bn,
          ),
          _gap,
          _source(),
        ],
      ),
    );
  });
}

class _LossPainter extends CustomPainter {
  final List<List<double>> X;
  final List<double> y, theta;
  final Color accent;
  _LossPainter(this.X, this.y, this.theta, this.accent);
  @override
  void paint(Canvas c, Size s) {
    final side = min(s.width - 52, s.height - 40),
        rect = Rect.fromLTWH((s.width - side) / 2 + 12, 12, side, side);
    const n = 18;
    final values = [
      for (var row = 0; row < n; row++)
        [
          for (var col = 0; col < n; col++)
            GradientResult.compute(X, y, [
              -4 + (col + .5) * 8 / n,
              4 - (row + .5) * 8 / n,
              theta[2],
            ]).loss,
        ],
    ];
    final minLoss = values.expand((v) => v).reduce(min),
        maxLoss = values.expand((v) => v).reduce(max);
    for (var row = 0; row < n; row++) {
      for (var col = 0; col < n; col++) {
        final t = (values[row][col] - minLoss) / max(1e-12, maxLoss - minLoss);
        final color = Color.lerp(
          const Color(0xffd9edaa),
          const Color(0xff176b4b),
          t,
        )!;
        c.drawRect(
          Rect.fromLTWH(
            rect.left + col * side / n,
            rect.top + row * side / n,
            side / n + .4,
            side / n + .4,
          ),
          Paint()..color = color,
        );
      }
    }
    void label(String text, Offset pos) {
      final p = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: 'Manrope',
            fontFamilyFallback: const ['NotoSansMath', 'NotoSans'],
            fontSize: 10,
            color: accent,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      p.paint(c, pos);
    }

    for (final v in [-4, 0, 4]) {
      label('$v', Offset(rect.left + (v + 4) / 8 * side - 5, rect.bottom + 5));
      label('$v', Offset(rect.left - 24, rect.top + (4 - v) / 8 * side - 6));
    }
    final point = Offset(
          rect.left + (theta[0] + 4) / 8 * side,
          rect.top + (4 - theta[1]) / 8 * side,
        ),
        g = GradientResult.compute(X, y, theta).gradient,
        norm = sqrt(g[0] * g[0] + g[1] * g[1]);
    c.save();
    c.clipRect(rect);
    c.drawCircle(
      point,
      6,
      Paint()..color = Colors.black.withValues(alpha: .75),
    );
    c.drawCircle(point, 3, Paint()..color = Colors.white);
    if (norm > 1e-12) {
      final end = point + Offset(-g[0] / norm, g[1] / norm) * 30,
          pen = Paint()
            ..color = Colors.black
            ..strokeWidth = 2;
      c.drawLine(point, end, pen);
      final direction = (end - point) / 30,
          normal = Offset(-direction.dy, direction.dx);
      c.drawLine(end, end - direction * 8 + normal * 4, pen);
      c.drawLine(end, end - direction * 8 - normal * 4, pen);
    }
    c.restore();
  }

  @override
  bool shouldRepaint(covariant _LossPainter old) =>
      old.theta != theta || old.accent != accent;
}
