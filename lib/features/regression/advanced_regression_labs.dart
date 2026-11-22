import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import 'advanced_regression_model.dart';

String _number(double v) =>
    v.abs() >= 10000 ? v.toStringAsExponential(2) : v.toStringAsFixed(4);

class OptimizationLab extends StatefulWidget {
  const OptimizationLab({super.key});
  @override
  State<OptimizationLab> createState() => _OptimizationLabState();
}

class _OptimizationLabState extends State<OptimizationLab> {
  bool standardized = true;
  double rate = .05;
  late OptimizationRun run = OptimizationRun();
  void reset() {
    run = OptimizationRun(standardized: standardized, learningRate: rate);
  }

  void train(int count) => setState(() {
    for (var i = 0; i < count; i++) {
      if (!run.step()) break;
    }
  });
  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Tag(
          'CLASSICAL ML · CHAPTER 01 · OPTIMIZATION LAB',
          icon: Icons.science_outlined,
        ),
        const SizedBox(height: 18),
        const Text(
          'Follow the gradient.',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w800,
            letterSpacing: -.6,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Learning Rate আর Feature Scale বদলে দেখুন Training কোন পথে এগোয়।',
          style: TextStyle(
            fontFamily: 'NotoSansBengali',
            height: 2,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<double>(
          key: ValueKey(rate),
          initialValue: rate,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Learning rate (α)'),
          items: [
            for (final r in [.001, .01, .05, .2, 1.2])
              DropdownMenuItem(value: r, child: Text(r.toString())),
          ],
          onChanged: (v) {
            if (v != null) {
              setState(() {
                rate = v;
                reset();
              });
            }
          },
        ),
        const SizedBox(height: 10),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Standardize training features',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          subtitle: const Text(
            'Toggle starts a fresh run · raw x = 100…600',
            style: TextStyle(fontSize: 10, height: 1.8),
          ),
          value: standardized,
          onChanged: (v) => setState(() {
            standardized = v;
            reset();
          }),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            Tag('Training MSE  ${_number(run.loss)}'),
            Tag('${run.steps} updates'),
            Tag('w ${_number(run.weight)} · b ${_number(run.bias)}'),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          'Training loss history · logarithmic y axis',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Semantics(
          label:
              'Loss after ${run.steps} updates: ${_number(run.loss)}. Initial loss ${_number(run.history.first)}.',
          child: SizedBox(
            width: double.infinity,
            height: 185,
            child: CustomPaint(
              painter: LossPainter(
                history: List.of(run.history),
                color: Theme.of(context).colorScheme.primary,
                gridColor: Theme.of(context).dividerColor,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Initial: ${_number(run.history.first)} → current: ${_number(run.loss)}',
          style: const TextStyle(fontSize: 11),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton(
              onPressed: run.stopped || run.steps >= 1000
                  ? null
                  : () => train(1),
              child: const Text('Step ×1'),
            ),
            OutlinedButton(
              onPressed: run.stopped || run.steps >= 1000
                  ? null
                  : () => train(25),
              child: const Text('Step ×25'),
            ),
            TextButton(
              onPressed: () => setState(reset),
              child: const Text('Reset run'),
            ),
          ],
        ),
        if (run.stopped) ...[
          const SizedBox(height: 18),
          const Text(
            'Run stopped: the next step exceeds the numerical safety limit. Last finite state shown. Reset, standardize features, or reduce α.',
            style: TextStyle(
              fontSize: 12,
              height: 1.9,
              color: Color(0xFFB36D28),
            ),
          ),
        ],
        if (run.steps >= 1000)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              '1,000-step demo limit reached. Reset to experiment again.',
              style: TextStyle(fontSize: 11),
            ),
          ),
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 12),
        Text(
          'Equivalent raw-input model: ŷ = ${_number(run.rawParameters.$1)}x + ${_number(run.rawParameters.$2)}',
          style: const TextStyle(fontSize: 12, height: 1.9),
        ),
        const SizedBox(height: 10),
        const Text(
          'Synthetic data · training loss only. Scaling uses the six training inputs. Rate or scale changes reset parameters and history. This lab does not measure generalization.',
          style: TextStyle(fontSize: 10, height: 1.9),
        ),
      ],
    ),
  );
}

class LossPainter extends CustomPainter {
  final List<double> history;
  final Color color, gridColor;
  LossPainter({
    required this.history,
    required this.color,
    required this.gridColor,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      4,
      8,
      math.max(1, size.width - 12),
      size.height - 20,
    );
    for (var i = 0; i <= 4; i++) {
      final y = rect.top + rect.height * i / 4;
      canvas.drawLine(
        Offset(rect.left, y),
        Offset(rect.right, y),
        Paint()
          ..color = gridColor
          ..strokeWidth = 1,
      );
    }
    final values = history.map((v) => math.log(math.max(v, 1e-8))).toList();
    final low = values.reduce(math.min) - .2,
        high = values.reduce(math.max) + .2;
    Offset point(int i) => Offset(
      rect.left + i / math.max(1, values.length - 1) * rect.width,
      rect.bottom - (values[i] - low) / (high - low) * rect.height,
    );
    final path = Path()..moveTo(point(0).dx, point(0).dy);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(point(i).dx, point(i).dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );
    canvas.drawCircle(point(values.length - 1), 4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant LossPainter old) => true;
}

class MultipleFeatureLab extends StatefulWidget {
  const MultipleFeatureLab({super.key});
  @override
  State<MultipleFeatureLab> createState() => _MultipleFeatureLabState();
}

class _MultipleFeatureLabState extends State<MultipleFeatureLab> {
  double area = 1000, bedrooms = 2;
  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Tag('MULTIPLE FEATURES · PREDICTION LAB', icon: Icons.tune),
        const SizedBox(height: 18),
        const Text(
          'Every feature has a part.',
          style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        const Text(
          'Fixed toy model · price (লাখ) = 8 + 0.04 × area + 5 × bedrooms',
          style: TextStyle(
            fontFamilyFallback: ['NotoSansBengali'],
            fontSize: 12,
            height: 2,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Area: ${area.round()} sqft',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        Slider(
          value: area,
          min: 500,
          max: 2500,
          divisions: 40,
          label: '${area.round()} sqft',
          semanticFormatterCallback: (v) => 'Area ${v.round()} square feet',
          onChanged: (v) => setState(() => area = v),
        ),
        Text(
          'Bedrooms: ${bedrooms.round()}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        Slider(
          value: bedrooms,
          min: 1,
          max: 5,
          divisions: 4,
          label: '${bedrooms.round()}',
          semanticFormatterCallback: (v) => '${v.round()} bedrooms',
          onChanged: (v) => setState(() => bedrooms = v),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            const Tag('Intercept  8'),
            Tag('Area  ${(area * .04).toStringAsFixed(1)}'),
            Tag('Bedrooms  ${(bedrooms * 5).toStringAsFixed(1)}'),
          ],
        ),
        const SizedBox(height: 22),
        Text(
          '${MultipleRegression.predict([area, bedrooms], [.04, 5], 8).toStringAsFixed(1)} লাখ',
          style: const TextStyle(
            fontFamilyFallback: ['NotoSansBengali'],
            fontSize: 34,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Illustrative coefficients, not fitted market data. Holding bedrooms fixed, +100 sqft adds 4 lakh to this prediction. Coefficients describe this toy model; they do not establish causation.',
          style: TextStyle(fontSize: 11, height: 1.9),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => setState(() {
            area = 1000;
            bedrooms = 2;
          }),
          child: const Text('Reset features'),
        ),
      ],
    ),
  );
}
