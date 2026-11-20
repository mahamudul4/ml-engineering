import 'dart:math';

import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import 'neural_model.dart';

const _gap = SizedBox(height: 16);
const _bn = TextStyle(fontFamily: 'NotoSansBengali', height: 1.85);
const _title = TextStyle(fontSize: 24, fontWeight: FontWeight.w800);
Color _accent(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? lime : forest;
Widget _asset(Future<NeuralAssets> f, Widget Function(NeuralAssets) build) =>
    FutureBuilder<NeuralAssets>(
      future: f,
      builder: (c, s) {
        if (s.hasError) {
          return const Panel(
            child: Text(
              'Bundled neural evidence could not be read. Reopen the lab.',
            ),
          );
        }
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        return build(s.data!);
      },
    );
Widget _source(NeuralAssets a) => Text(
  'UCI Wine Quality · Cortez et al. (2009) · CC BY 4.0. Existing 966 fit rows → inner train ${a.trainRows} / validation ${a.validationRows}; group-disjoint, scaler inner training-এ fit। Dart calculations PyTorch CPU float64 references-এর সঙ্গে যাচাইকৃত। App-এ Python training engine নেই; Chapter 14 decision/test পুনরায় evaluate হয়নি।',
  style: _bn,
);
Widget _graph() => Wrap(
  spacing: 6,
  runSpacing: 8,
  crossAxisAlignment: WrapCrossAlignment.center,
  children: const [
    Tag('X [B,11]'),
    Icon(Icons.arrow_forward, size: 16),
    Tag('Z1 / ReLU [B,4]'),
    Icon(Icons.arrow_forward, size: 16),
    Tag('logits [B]'),
    Icon(Icons.arrow_forward, size: 16),
    Tag('mean BCE []'),
  ],
);

class ForwardLab extends StatefulWidget {
  const ForwardLab({super.key});
  @override
  State<ForwardLab> createState() => _ForwardLabState();
}

class _ForwardLabState extends State<ForwardLab> {
  final data = NeuralAssets.load();
  int row = 0, checkpoint = 0, unit = 0;
  bool tanh = false;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final sample = a.samples[row],
        p = a.checkpoints[checkpoint].parameters,
        r = NeuralTrace.compute(
          sample.x,
          sample.positive.toDouble(),
          p,
          tanh: tanh,
        ),
        accent = _accent(context);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'DEEP LEARNING & RL · CHAPTER 02 · FORWARD PASS',
            icon: Icons.account_tree_outlined,
          ),
          _gap,
          const Text('Follow one row through the network.', style: _title),
          _gap,
          const Text(
            '11টি standardized chemistry features → 4টি hidden units → একটি logit। একটি actual inner-training row বেছে প্রতিটি weighted sum ও activation অনুসরণ করুন। Tanh toggle একই weights-এর what-if; নতুন trained model নয়।',
            style: _bn,
          ),
          _gap,
          _graph(),
          _gap,
          DropdownButtonFormField<int>(
            key: ValueKey('forward-row-$row'),
            initialValue: row,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Actual inner-training observation',
            ),
            items: [
              for (var i = 0; i < a.samples.length; i++)
                DropdownMenuItem(
                  value: i,
                  child: Text(
                    'Source #${a.samples[i].sourceRow} · quality ${a.samples[i].quality} · y=${a.samples[i].positive}',
                  ),
                ),
            ],
            onChanged: (v) {
              if (v != null) setState(() => row = v);
            },
          ),
          _gap,
          DropdownButtonFormField<int>(
            key: ValueKey('forward-epoch-$checkpoint'),
            initialValue: checkpoint,
            decoration: const InputDecoration(
              labelText: 'Stored ReLU checkpoint',
            ),
            items: [
              for (var i = 0; i < a.checkpoints.length; i++)
                DropdownMenuItem(
                  value: i,
                  child: Text('Epoch ${a.checkpoints[i].evidence.epoch}'),
                ),
            ],
            onChanged: (v) {
              if (v != null) setState(() => checkpoint = v);
            },
          ),
          _gap,
          SwitchListTile(
            key: const Key('forward-tanh'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Tanh at the same weights (what-if)'),
            value: tanh,
            onChanged: (v) => setState(() => tanh = v),
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              const Tag('Parameters: 53'),
              Tag(
                tanh ? 'Activation: tanh what-if' : 'Activation: trained ReLU',
              ),
              Tag('Logit: ${r.logit.toStringAsFixed(6)}'),
              Tag('Probability: ${r.probability.toStringAsFixed(6)}'),
              Tag('Row BCE: ${r.loss.toStringAsFixed(6)}'),
            ],
          ),
          _gap,
          const Text('Hidden units · tap to inspect an input sum'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var j = 0; j < 4; j++)
                OutlinedButton(
                  onPressed: () => setState(() => unit = j),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: unit == j
                        ? accent.withValues(alpha: .12)
                        : null,
                  ),
                  child: Text('h$j = ${r.hidden[j].toStringAsFixed(4)}'),
                ),
            ],
          ),
          _gap,
          Text(
            'Inspecting unit $unit: z = Σ x[k] × W1[$unit,k] + b1[$unit]',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          _gap,
          for (var d = 0; d < 11; d++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '${a.features[d]}: ${sample.x[d].toStringAsFixed(4)} × ${p.w1[unit][d].toStringAsFixed(4)} = ${(sample.x[d] * p.w1[unit][d]).toStringAsFixed(5)}',
                style: const TextStyle(fontSize: 12, height: 1.6),
              ),
            ),
          _gap,
          Text(
            'bias ${p.b1[unit].toStringAsFixed(6)} → z1 ${r.preactivation[unit].toStringAsFixed(6)} → h ${r.hidden[unit].toStringAsFixed(6)}\nOutput contributions: [${r.contributions.map((v) => v.toStringAsFixed(4)).join(', ')}]\nOutput bias ${p.b2.toStringAsFixed(6)} → logit ${r.logit.toStringAsFixed(6)}',
            style: const TextStyle(height: 1.9),
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                key: const Key('forward-final'),
                onPressed: () => setState(() => checkpoint = 7),
                child: const Text('Inspect epoch 120'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  row = 0;
                  checkpoint = 0;
                  unit = 0;
                  tanh = false;
                }),
                child: const Text('Reset forward'),
              ),
            ],
          ),
          _gap,
          _source(a),
        ],
      ),
    );
  });
}

class BackpropLab extends StatefulWidget {
  const BackpropLab({super.key});
  @override
  State<BackpropLab> createState() => _BackpropLabState();
}

class _BackpropLabState extends State<BackpropLab> {
  final data = NeuralAssets.load();
  bool sum = false, detached = false;
  int unit = 0;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final p = a.checkpoints.first.parameters,
        g = NeuralGradient.compute(a.X, a.y, p, sum: sum),
        r = NeuralTrace.compute(a.X.first, a.y.first, p);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag('DEEP LEARNING & RL · CHAPTER 02 · BACKPROPAGATION', icon: Icons.route_outlined),
          _gap,
          const Text(
            'Trace the error back, one layer at a time.',
            style: _title,
          ),
          _gap,
          const Text(
            'প্রথম 8 actual inner-training rows ও initial weights-এ analytical backprop। Mean/sum বদলালে সব gradients-এর scale বদলায়। Hidden detach করলে forward values ও output-layer gradients একই থাকে, কিন্তু first-layer .grad হয় None; সেটিকে zero derivative বলা ঠিক নয়।',
            style: _bn,
          ),
          _gap,
          _graph(),
          _gap,
          SwitchListTile(
            key: const Key('backprop-reduction'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Use sum reduction instead of mean'),
            value: sum,
            onChanged: (v) => setState(() => sum = v),
          ),
          SwitchListTile(
            key: const Key('backprop-detach'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Detach hidden activations (broken path)'),
            value: detached,
            onChanged: (v) => setState(() => detached = v),
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Tag(sum ? 'Reduction: sum' : 'Reduction: mean'),
              Tag('Batch loss: ${g.loss.toStringAsFixed(6)}'),
              Tag(
                detached ? 'Hidden path: detached' : 'Hidden path: connected',
              ),
              Tag('Output bias grad: ${g.db2.toStringAsFixed(6)}'),
            ],
          ),
          _gap,
          const Text(
            'δ2 = (sigmoid(logit) − y) / B\ndW2 = Hᵀδ2 · db2 = Σδ2\nδ1 = (δ2 W2) ⊙ ReLU′(Z1)\ndW1 = δ1ᵀX · db1 = Σδ1',
            style: TextStyle(height: 2, fontWeight: FontWeight.w600),
          ),
          _gap,
          DropdownButtonFormField<int>(
            key: ValueKey('backprop-unit-$unit'),
            initialValue: unit,
            decoration: const InputDecoration(
              labelText: 'Inspect hidden unit gradient',
            ),
            items: [
              for (var j = 0; j < 4; j++)
                DropdownMenuItem(value: j, child: Text('Hidden unit $j')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => unit = v);
            },
          ),
          _gap,
          Text(
            'First row: z1=${r.preactivation[unit].toStringAsFixed(6)} · gate=${r.gate[unit].toInt()}\nδ2=${g.dlogit.first.toStringAsFixed(6)} · W2=${p.w2[unit].toStringAsFixed(6)}\nConnected δ1=${(g.dlogit.first * p.w2[unit] * r.gate[unit]).toStringAsFixed(6)}',
            style: const TextStyle(height: 1.9),
          ),
          _gap,
          Text(
            detached
                ? 'First-layer gradients: None (disconnected)'
                : 'First-layer gradients: computed',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: _accent(context),
            ),
          ),
          _gap,
          for (var d = 0; d < 11; d++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'dW1[$unit,$d] · ${a.features[d]}: ${detached ? 'None' : g.dw1[unit][d].toStringAsFixed(7)}',
                style: const TextStyle(fontSize: 12, height: 1.6),
              ),
            ),
          _gap,
          Text(
            'db1[$unit]: ${detached ? 'None' : g.db1[unit].toStringAsFixed(7)}\ndW2: [${g.dw2.map((v) => v.toStringAsFixed(6)).join(', ')}]',
            style: const TextStyle(height: 1.9),
          ),
          _gap,
          const Text(
            'একটি row-এর negative preactivation-এ ReLU gate 0 হলে সেই row থেকে gradient 0 আসে। অন্য rows সক্রিয় থাকলে batch gradient nonzero হতে পারে। Dead unit, disconnected graph ও mean/sum scaling আলাদা diagnosis।',
            style: _bn,
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                key: const Key('backprop-sum'),
                onPressed: () => setState(() => sum = true),
                child: const Text('Inspect sum gradients'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  sum = false;
                  detached = false;
                  unit = 0;
                }),
                child: const Text('Reset backprop'),
              ),
            ],
          ),
          _gap,
          _source(a),
        ],
      ),
    );
  });
}

class TrainingLab extends StatefulWidget {
  const TrainingLab({super.key});
  @override
  State<TrainingLab> createState() => _TrainingLabState();
}

class _TrainingLabState extends State<TrainingLab> {
  final data = NeuralAssets.load();
  int checkpoint = 0;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final e = a.checkpoints[checkpoint].evidence;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'DEEP LEARNING & RL · CHAPTER 02 · TRAINING HISTORY',
            icon: Icons.show_chart_outlined,
          ),
          _gap,
          const Text(
            'Read the learning curve, defend the scope.',
            style: _title,
          ),
          _gap,
          const Text(
            'Actual CPU PyTorch run: 11→4→1 ReLU, 53 parameters, seed 16, full-batch SGD, learning rate .05, 120 updates। এটি একটি fixed recipe; best epoch বা architecture search নয়। Curves full inner train/validation-এর post-update BCE; আটটি stored checkpoint inspect করা যায়।',
            style: _bn,
          ),
          _gap,
          Semantics(
            label: 'Actual training and inner validation BCE across 0 to 120 SGD updates. Green train, orange validation. Selected epoch marked.',
            child: SizedBox(
              height: 300,
              width: double.infinity,
              child: CustomPaint(
                painter: _CurvePainter(a.history, e.epoch, _accent(context)),
              ),
            ),
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Tag('Epoch: ${e.epoch} / 120'),
              Tag('Train BCE: ${e.trainLoss.toStringAsFixed(6)}'),
              Tag(
                'Inner validation BCE: ${e.validationLoss.toStringAsFixed(6)}',
              ),
            ],
          ),
          _gap,
          DropdownButtonFormField<int>(
            key: ValueKey('training-checkpoint-$checkpoint'),
            initialValue: checkpoint,
            decoration: const InputDecoration(
              labelText: 'Stored epoch (no mobile retraining)',
            ),
            items: [
              for (var i = 0; i < a.checkpoints.length; i++)
                DropdownMenuItem(
                  value: i,
                  child: Text('Epoch ${a.checkpoints[i].evidence.epoch}'),
                ),
            ],
            onChanged: (v) {
              if (v != null) setState(() => checkpoint = v);
            },
          ),
          _gap,
          Text(
            'Train accuracy @0.5: ${(100 * e.trainAccuracy).toStringAsFixed(2)}%\nInner validation accuracy @0.5: ${(100 * e.validationAccuracy).toStringAsFixed(2)}%\nBCE gap (validation − train): ${(e.validationLoss - e.trainLoss).toStringAsFixed(6)}',
            style: const TextStyle(height: 1.9),
          ),
          _gap,
          const Text(
            'Train ও validation BCE একসঙ্গে পড়ুন; ছোট gap একা correctness বা নতুন-domain generalization প্রমাণ নয়। এই reused source আগে দেখা হয়েছে। Validation দেখে recipe বদলালে সেটিও selection; নতুন confirmatory evidence প্রয়োজন। Epoch 120 পূর্বনির্ধারিত endpoint, curve দেখে বেছে নেওয়া winner নয়।',
            style: _bn,
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                key: const Key('training-final'),
                onPressed: () => setState(() => checkpoint = 7),
                child: const Text('Inspect final epoch'),
              ),
              TextButton(
                onPressed: () => setState(() => checkpoint = 0),
                child: const Text('Reset history'),
              ),
            ],
          ),
          _gap,
          _source(a),
        ],
      ),
    );
  });
}

class _CurvePainter extends CustomPainter {
  final List<NeuralEpoch> history;
  final int selected;
  final Color accent;
  _CurvePainter(this.history, this.selected, this.accent);
  @override
  void paint(Canvas c, Size s) {
    final r = Rect.fromLTWH(48, 18, max(1, s.width - 66), s.height - 56),
        all = [
          for (final e in history) ...[e.trainLoss, e.validationLoss],
        ],
        lo = all.reduce(min) - .02,
        hi = all.reduce(max) + .02;
    Offset point(int epoch, double loss) => Offset(
      r.left + epoch / 120 * r.width,
      r.bottom - (loss - lo) / (hi - lo) * r.height,
    );
    void label(String t, Offset pos, {Color? color}) {
      final p = TextPainter(
        text: TextSpan(
          text: t,
          style: TextStyle(
            fontFamily: 'Manrope',
            fontFamilyFallback: const ['NotoSansMath', 'NotoSans'],
            fontSize: 10,
            color: color ?? accent,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      p.paint(c, pos);
    }

    for (var i = 0; i < 4; i++) {
      final loss = lo + (hi - lo) * i / 3, dy = point(0, loss).dy;
      c.drawLine(
        Offset(r.left, dy),
        Offset(r.right, dy),
        Paint()..color = accent.withValues(alpha: .12),
      );
      label(loss.toStringAsFixed(2), Offset(3, dy - 6));
    }
    for (final epoch in [0, 40, 80, 120]) {
      label('$epoch', Offset(point(epoch, lo).dx - 8, r.bottom + 6));
    }
    for (final validation in [false, true]) {
      final color = validation ? const Color(0xffbc6c25) : accent,
          path = Path();
      for (var i = 0; i < history.length; i++) {
        final p = point(
          i,
          validation ? history[i].validationLoss : history[i].trainLoss,
        );
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      c.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
      final e = history[selected];
      c.drawCircle(
        point(selected, validation ? e.validationLoss : e.trainLoss),
        4,
        Paint()..color = color,
      );
    }
    c.drawLine(
      Offset(point(selected, lo).dx, r.top),
      Offset(point(selected, lo).dx, r.bottom),
      Paint()
        ..color = accent.withValues(alpha: .3)
        ..strokeWidth = 1,
    );
    label('Train', Offset(r.left, r.top - 15));
    label(
      'Inner validation',
      Offset(r.left + 60, r.top - 15),
      color: const Color(0xffbc6c25),
    );
    label('SGD updates', Offset(r.right - 70, r.bottom + 22));
  }

  @override
  bool shouldRepaint(covariant _CurvePainter old) =>
      old.selected != selected || old.accent != accent;
}
