import 'dart:math';

import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import 'evaluation_model.dart';

class FoldLab extends StatefulWidget {
  const FoldLab({super.key});
  @override
  State<FoldLab> createState() => _FoldLabState();
}

class _FoldLabState extends State<FoldLab> {
  FoldPolicy policy = FoldPolicy.interleaved;
  int fold = 0, gap = 0;
  @override
  Widget build(BuildContext context) {
    final plan = FoldPlan.make(policy, fold, gap: gap);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'CLASSICAL ML · CHAPTER 03 · SPLIT DESIGN',
            icon: Icons.view_week_outlined,
          ),
          const SizedBox(height: 18),
          const Text(
            'Who gets to see the future?',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          const Text(
            '১২টি Row ক্রমানুসারে সাজানো আছে। পাশাপাশি দুটি Row একই Group-এর। Split policy বদলে overlap ও time order দেখুন।',
            style: TextStyle(fontFamily: 'NotoSansBengali', height: 2),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<FoldPolicy>(
            key: ValueKey(policy),
            initialValue: policy,
            decoration: const InputDecoration(labelText: 'Split policy'),
            items: const [
              DropdownMenuItem(
                value: FoldPolicy.interleaved,
                child: Text('Interleaved row folds'),
              ),
              DropdownMenuItem(
                value: FoldPolicy.grouped,
                child: Text('Group-disjoint folds'),
              ),
              DropdownMenuItem(
                value: FoldPolicy.forward,
                child: Text('Forward time windows'),
              ),
            ],
            onChanged: (v) {
              if (v != null) setState(() => policy = v);
            },
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < 3; i++)
                ChoiceChip(
                  key: Key('eval-fold-$i'),
                  label: Text('Fold ${i + 1}'),
                  selected: fold == i,
                  onSelected: (_) => setState(() => fold = i),
                ),
            ],
          ),
          if (policy == FoldPolicy.forward)
            SwitchListTile.adaptive(
              key: const Key('eval-gap'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Leave a one-row gap'),
              subtitle: const Text(
                'Gap size must match the real label/feature horizon.',
              ),
              value: gap == 1,
              onChanged: (v) => setState(() => gap = v ? 1 : 0),
            ),
          const SizedBox(height: 18),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Tag('T · training'),
              Tag('V · validation', color: Color(0xFFB36D28)),
              Tag('— · unused'),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, box) => Wrap(
              spacing: 6,
              runSpacing: 8,
              children: [
                for (var i = 0; i < 12; i++)
                  SizedBox(
                    width: (box.maxWidth - 5 * 6) / 6,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: plan.validation.contains(i)
                            ? const Color(0xFFB36D28).withValues(alpha: .18)
                            : plan.train.contains(i)
                            ? forest.withValues(alpha: dark ? .4 : .12)
                            : Colors.grey.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          children: [
                            Text(
                              '${i + 1}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'G${i ~/ 2 + 1}',
                              style: const TextStyle(fontSize: 10),
                            ),
                            Text(
                              plan.validation.contains(i)
                                  ? 'V'
                                  : plan.train.contains(i)
                                  ? 'T'
                                  : '—',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Tag(
                'Train ${plan.train.length} · validation ${plan.validation.length}',
              ),
              Tag('Shared groups: ${plan.sharedGroups.length}'),
              Tag('Future in training: ${plan.trainsOnFuture ? 'yes' : 'no'}'),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            switch (policy) {
              FoldPolicy.interleaved => 'Row folds একই group ভাগ করে এবং future rows ব্যবহার করে। Independent/exchangeable rows হলে row CV উপযোগী হতে পারে; এই repeated-group/future task-এর জন্য নয়।',
              FoldPolicy.grouped => 'Group overlap নেই; কিন্তু future rows আছে। নতুন group-এ generalization পরীক্ষা করে—future forecasting-এর নিশ্চয়তা দেয় না।',
              FoldPolicy.forward => 'Training validation-এর আগে। একই group সীমান্তে থাকতে পারে; gap সব label leakage দূর করে না। Group এবং time দুটো constraint দরকার হলে custom splitter লিখুন।',
            },
            style: const TextStyle(
              fontFamily: 'NotoSansBengali',
              height: 2,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => setState(() {
              policy = FoldPolicy.interleaved;
              fold = 0;
              gap = 0;
            }),
            child: const Text('Reset split'),
          ),
          const Text(
            'Illustrative records, not Adult observations. These fixed folds expose constraints; no model is trained here.',
            style: TextStyle(fontSize: 10, height: 1.8),
          ),
        ],
      ),
    );
  }
}

class BootstrapLab extends StatefulWidget {
  const BootstrapLab({super.key});
  @override
  State<BootstrapLab> createState() => _BootstrapLabState();
}

class _BootstrapLabState extends State<BootstrapLab> {
  static const a = [.4, .2, .5, .8, .3, .6, .4, .7];
  static const b = [.2, .3, .4, .5, .5, .5, .4, .5];
  double confidence = .95;
  int repetitions = 1000;
  @override
  Widget build(BuildContext context) {
    final result = PairedBootstrap.lossDifference(
      a,
      b,
      confidence: confidence,
      repetitions: repetitions,
    );
    String n(double x) => x.toStringAsFixed(3);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'CLASSICAL ML · CHAPTER 03 · PAIRED UNCERTAINTY',
            icon: Icons.compare_arrows,
          ),
          const SizedBox(height: 18),
          const Text(
            'A gain is an estimate.',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          const Text(
            'একই আটটি held-out row-এ দুইটি fixed model-এর loss। প্রতিটি Pair একসঙ্গে রেখে Replacement-সহ Resample করি। Positive difference মানে B-এর loss কম।',
            style: TextStyle(fontFamily: 'NotoSansBengali', height: 2),
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<int>(
            key: ValueKey(repetitions),
            initialValue: repetitions,
            decoration: const InputDecoration(
              labelText: 'Bootstrap repetitions',
            ),
            items: [
              for (final count in [200, 1000, 3000])
                DropdownMenuItem(value: count, child: Text('$count')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => repetitions = v);
            },
          ),
          const SizedBox(height: 18),
          Text(
            'Percentile interval: ${(confidence * 100).round()}%',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Slider(
            key: const Key('eval-confidence'),
            value: confidence,
            min: .80,
            max: .99,
            divisions: 19,
            label: '${(confidence * 100).round()}%',
            onChanged: (v) => setState(() => confidence = v),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Tag('Mean gain A − B: ${n(result.estimate)}'),
              Tag('Interval [${n(result.lower)}, ${n(result.upper)}]'),
              Tag(
                result.lower <= 0 && result.upper >= 0
                    ? 'Interval includes zero'
                    : 'Interval excludes zero',
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Distribution of resampled mean differences',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Semantics(
            label:
                'Histogram of $repetitions bootstrap means, interval ${n(result.lower)} to ${n(result.upper)}',
            child: SizedBox(
              height: 150,
              width: double.infinity,
              child: CustomPaint(
                painter: _BootstrapPainter(
                  result.draws,
                  Theme.of(context).brightness == Brightness.dark
                      ? lime
                      : forest,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(n(result.draws.first)),
              const Text('0 · no mean loss gain'),
              Text(n(result.draws.last)),
            ],
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < a.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  Tag('Row ${i + 1}'),
                  Tag('A ${n(a[i])}'),
                  Tag('B ${n(b[i])}'),
                  Tag('A − B ${n(a[i] - b[i])}'),
                ],
              ),
            ),
          const SizedBox(height: 10),
          const Text(
            'বেশি repetitions Monte Carlo noise কমায়; নতুন independent data যোগ করে না। এটি fixed predictions-এর sampling uncertainty-এর একটি approximation; training/tuning uncertainty, dependence বা distribution shift এতে ধরা নেই। Zero থাকা equivalence-এর প্রমাণ নয়।',
            style: TextStyle(
              fontFamily: 'NotoSansBengali',
              height: 2,
              fontSize: 12,
            ),
          ),
          TextButton(
            onPressed: () => setState(() {
              confidence = .95;
              repetitions = 1000;
            }),
            child: const Text('Reset bootstrap'),
          ),
          const Text(
            'Eight explicitly illustrative loss pairs. Seed 42. Row bootstrap assumes independent/exchangeable observations; use cluster/block resampling when required. Percentile intervals can be unreliable with small samples.',
            style: TextStyle(fontSize: 10, height: 1.8),
          ),
        ],
      ),
    );
  }
}

class _BootstrapPainter extends CustomPainter {
  final List<double> draws;
  final Color color;
  _BootstrapPainter(this.draws, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final left = min(draws.first, 0.0) - .01;
    final right = max(draws.last, 0.0) + .01;
    final bins = List<int>.filled(30, 0);
    for (final value in draws) {
      bins[((value - left) / (right - left) * bins.length).floor().clamp(
        0,
        bins.length - 1,
      )]++;
    }
    final peak = bins.reduce(max);
    final paint = Paint()..color = color.withValues(alpha: .65);
    for (var i = 0; i < bins.length; i++) {
      final x = size.width * i / bins.length;
      final height = (size.height - 8) * bins[i] / peak;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x + 1,
            size.height - height,
            size.width / bins.length - 2,
            height,
          ),
          const Radius.circular(3),
        ),
        paint,
      );
    }
    final zero = (0 - left) / (right - left) * size.width;
    canvas.drawLine(
      Offset(zero, 0),
      Offset(zero, size.height),
      Paint()
        ..color = color
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _BootstrapPainter oldDelegate) =>
      oldDelegate.draws != draws || oldDelegate.color != color;
}
