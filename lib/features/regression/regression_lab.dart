import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import 'regression_model.dart';

class RegressionLab extends StatefulWidget {
  const RegressionLab({super.key});
  @override
  State<RegressionLab> createState() => _RegressionLabState();
}

class _RegressionLabState extends State<RegressionLab> {
  double weight = .6, bias = .4, input = 4;
  int steps = 0;
  bool residuals = true;
  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Eyebrow('THE REGRESSION PLAYGROUND'),
            Tag('Interactive', icon: Icons.touch_app_outlined),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'A little change. A better fit.',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          'রেখাটি সরান, prediction দেখুন, error কমান।',
          style: TextStyle(
            fontFamily: 'NotoSansBengali',
            height: 1.8,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            Tag(
              'ŷ = ${weight.toStringAsFixed(2)}x + ${bias.toStringAsFixed(2)}',
            ),
            Tag(
              'MSE  ${RegressionModel.mse(weight, bias).toStringAsFixed(3)}',
              color: const Color(0xFFB36D28),
            ),
            Tag('$steps gradient steps'),
          ],
        ),
        const SizedBox(height: 14),
        Semantics(
          label:
              'Scatter plot of study hours versus practice scores. Current mean squared error ${RegressionModel.mse(weight, bias).toStringAsFixed(3)}',
          child: SizedBox(
            height: 240,
            width: double.infinity,
            child: CustomPaint(
              painter: RegressionPainter(
                weight: weight,
                bias: bias,
                residuals: residuals,
                dark: Theme.of(context).brightness == Brightness.dark,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _slider('Weight (w)', weight, 0, 2, (v) => setState(() => weight = v)),
        _slider('Bias (b)', bias, -2, 3, (v) => setState(() => bias = v)),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('Show residuals', style: TextStyle(fontSize: 12)),
          value: residuals,
          onChanged: (v) => setState(() => residuals = v),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: () => setState(() {
                final next = RegressionModel.step(weight, bias);
                weight = next.$1;
                bias = next.$2;
                steps++;
              }),
              icon: const Icon(Icons.trending_down, size: 17),
              label: const Text('Train one step'),
            ),
            OutlinedButton(
              onPressed: () => setState(() {
                final fit = RegressionModel.fit();
                weight = fit.$1;
                bias = fit.$2;
              }),
              child: const Text('Best fit'),
            ),
            TextButton(
              onPressed: () => setState(() {
                weight = .6;
                bias = .4;
                steps = 0;
              }),
              child: const Text('Reset'),
            ),
          ],
        ),
        const SizedBox(height: 22),
        const Divider(),
        const SizedBox(height: 10),
        _slider('Study hours', input, 0, 6, (v) => setState(() => input = v)),
        Text(
          '${input.toStringAsFixed(1)} hours → ${RegressionModel.predict(input, weight, bias).toStringAsFixed(2)} predicted score',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 8),
        const Text(
          'Toy data · A line can predict outside the score range. This is an illustration, not a guarantee.',
          style: TextStyle(fontSize: 11, height: 1.7),
        ),
      ],
    ),
  );
  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> change,
  ) => Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          Text(
            value.toStringAsFixed(2),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ],
      ),
      Slider(
        semanticFormatterCallback: (v) => '$label ${v.toStringAsFixed(2)}',
        value: value.clamp(min, max),
        min: min,
        max: max,
        onChanged: change,
      ),
    ],
  );
}

class RegressionPainter extends CustomPainter {
  final double weight, bias;
  final bool residuals, dark, decorative;
  RegressionPainter({
    this.weight = 1.2,
    this.bias = .8,
    this.residuals = false,
    this.dark = false,
    this.decorative = false,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final left = decorative ? 20.0 : 36.0,
        top = 12.0,
        bottom = size.height - 28,
        right = size.width - 12;
    Offset point(double x, double y) =>
        Offset(left + x / 7 * (right - left), bottom - y / 10 * (bottom - top));
    final grid = Paint()
      ..color = (dark ? Colors.white : forest).withValues(alpha: .10)
      ..strokeWidth = 1;
    for (var x = 0; x <= 7; x++) {
      canvas.drawLine(point(x.toDouble(), 0), point(x.toDouble(), 10), grid);
    }
    for (var y = 0; y <= 10; y += 2) {
      canvas.drawLine(point(0, y.toDouble()), point(7, y.toDouble()), grid);
    }
    if (!decorative) {
      for (var x = 0; x <= 6; x++) {
        _label(canvas, '$x', point(x.toDouble(), 0) + const Offset(-3, 8));
      }
      for (var y = 0; y <= 10; y += 2) {
        _label(canvas, '$y', point(0, y.toDouble()) + const Offset(-24, -5));
      }
    }
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(left, top, right, bottom));
    if (decorative) {
      final area = Path()
        ..moveTo(point(0, 0).dx, point(0, 0).dy)
        ..lineTo(point(0, bias).dx, point(0, bias).dy)
        ..lineTo(point(7, weight * 7 + bias).dx, point(7, weight * 7 + bias).dy)
        ..lineTo(point(7, 0).dx, point(7, 0).dy)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              forest.withValues(alpha: .17),
              forest.withValues(alpha: 0),
            ],
          ).createShader(Offset.zero & size),
      );
    }
    canvas.drawLine(
      point(0, bias),
      point(7, weight * 7 + bias),
      Paint()
        ..color = dark ? lime : forest
        ..strokeWidth = decorative ? 2.5 : 2,
    );
    for (final p in RegressionModel.points) {
      if (residuals) {
        final start = point(p.$1, p.$2),
            end = point(p.$1, RegressionModel.predict(p.$1, weight, bias));
        final distance = (end - start).distance;
        for (double d = 0; d < distance; d += 7) {
          canvas.drawLine(
            Offset.lerp(start, end, d / math.max(distance, 1))!,
            Offset.lerp(
              start,
              end,
              math.min(d + 3, distance) / math.max(distance, 1),
            )!,
            Paint()
              ..color = const Color(0xFFD59B56)
              ..strokeWidth = 1.5,
          );
        }
      }
      canvas.drawCircle(
        point(p.$1, p.$2),
        decorative ? 6 : 5,
        Paint()..color = dark ? lime : forest,
      );
      canvas.drawCircle(
        point(p.$1, p.$2),
        decorative ? 2 : 1.5,
        Paint()..color = dark ? forest : Colors.white,
      );
    }
    canvas.restore();
    if (!decorative) {
      _label(
        canvas,
        'Study hours (x)',
        Offset(size.width / 2 - 28, size.height - 10),
      );
    }
  }

  void _label(Canvas canvas, String text, Offset offset) {
    final p = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: dark ? const Color(0xFFB7C8BA) : const Color(0xFF718076),
          fontSize: 9,
          fontFamily: 'Manrope',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    p.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant RegressionPainter old) =>
      old.weight != weight ||
      old.bias != bias ||
      old.residuals != residuals ||
      old.dark != dark;
}
