import 'package:flutter/material.dart';

import '../../ui/theme.dart';

class PolynomialModel {
  static double predict(double x, double linear, double quadratic) =>
      1 + linear * x + quadratic * x * x;
  static double mse(double linear, double quadratic) {
    var sum = 0.0;
    for (var i = -3; i <= 3; i++) {
      final x = i.toDouble();
      final e = predict(x, linear, quadratic) - predict(x, 2, .5);
      sum += e * e;
    }
    return sum / 7;
  }
}

class PolynomialLab extends StatefulWidget {
  const PolynomialLab({super.key});
  @override
  State<PolynomialLab> createState() => _PolynomialLabState();
}

class _PolynomialLabState extends State<PolynomialLab> {
  double linear = 1, quadratic = 0, input = 2;
  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Tag('REGRESSION VARIANTS · CURVE LAB', icon: Icons.show_chart),
        const SizedBox(height: 18),
        const Text(
          'Let the line bend.',
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        const Text(
          'Polynomial features বদলান, curve ও training error দেখুন।',
          style: TextStyle(
            fontFamily: 'NotoSansBengali',
            fontSize: 13,
            height: 2,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            Tag(
              'ŷ = 1 + ${linear.toStringAsFixed(2)}x + ${quadratic.toStringAsFixed(2)}x²',
            ),
            Tag(
              'Training MSE  ${PolynomialModel.mse(linear, quadratic).toStringAsFixed(3)}',
            ),
          ],
        ),
        const SizedBox(height: 18),
        Semantics(
          label:
              'Polynomial prediction curve and seven synthetic observations. Mean squared error ${PolynomialModel.mse(linear, quadratic).toStringAsFixed(3)}',
          child: SizedBox(
            height: 240,
            width: double.infinity,
            child: CustomPaint(
              painter: PolynomialPainter(
                linear,
                quadratic,
                Theme.of(context).colorScheme.primary,
                Theme.of(context).dividerColor,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Linear coefficient: ${linear.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        Slider(
          value: linear,
          min: -3,
          max: 3,
          divisions: 120,
          label: linear.toStringAsFixed(2),
          onChanged: (v) => setState(() => linear = v),
        ),
        Text(
          'Quadratic coefficient: ${quadratic.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        Slider(
          value: quadratic,
          min: -1,
          max: 1,
          divisions: 80,
          label: quadratic.toStringAsFixed(2),
          onChanged: (v) => setState(() => quadratic = v),
        ),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            FilledButton(
              onPressed: () => setState(() {
                linear = 2;
                quadratic = .5;
              }),
              child: const Text('Match toy curve'),
            ),
            TextButton(
              onPressed: () => setState(() {
                linear = 1;
                quadratic = 0;
                input = 2;
              }),
              child: const Text('Reset curve'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Input x: ${input.toStringAsFixed(1)} → prediction ${PolynomialModel.predict(input, linear, quadratic).toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        Slider(
          value: input,
          min: -3,
          max: 3,
          divisions: 60,
          label: input.toStringAsFixed(1),
          onChanged: (v) => setState(() => input = v),
        ),
        const Text(
          'Dots: y = 1 + 2x + 0.5x² for x = −3…3. Fixed intercept 1. Controls set coefficients; Match toy curve restores the known generating rule, not a fitted estimator. Training MSE is not test performance. Plot: x from −3 to 3; y from −8 to 14; extreme curves are clipped.',
          style: TextStyle(fontSize: 10, height: 1.9),
        ),
      ],
    ),
  );
}

class PolynomialPainter extends CustomPainter {
  final double linear, quadratic;
  final Color color, grid;
  PolynomialPainter(this.linear, this.quadratic, this.color, this.grid);
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(10, 10, size.width - 20, size.height - 20);
    Offset point(double x, double y) => Offset(
      rect.left + (x + 3) / 6 * rect.width,
      rect.bottom - (y + 8) / 22 * rect.height,
    );
    for (var x = -3; x <= 3; x++) {
      canvas.drawLine(
        point(x.toDouble(), -8),
        point(x.toDouble(), 14),
        Paint()..color = grid,
      );
    }
    for (var y = -8; y <= 14; y += 2) {
      canvas.drawLine(
        point(-3, y.toDouble()),
        point(3, y.toDouble()),
        Paint()..color = grid,
      );
    }
    canvas.save();
    canvas.clipRect(rect);
    final path = Path();
    for (var i = 0; i <= 180; i++) {
      final x = -3 + i / 30,
          p = point(x, PolynomialModel.predict(x, linear, quadratic));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );
    for (var x = -3; x <= 3; x++) {
      canvas.drawCircle(
        point(x.toDouble(), PolynomialModel.predict(x.toDouble(), 2, .5)),
        5,
        Paint()..color = const Color(0xFFB5783D),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant PolynomialPainter old) =>
      linear != old.linear ||
      quadratic != old.quadratic ||
      color != old.color ||
      grid != old.grid;
}
