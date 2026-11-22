import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import 'classification_model.dart';

class ClassificationLab extends StatefulWidget {
  const ClassificationLab({super.key});
  @override
  State<ClassificationLab> createState() => _ClassificationLabState();
}

class _ClassificationLabState extends State<ClassificationLab> {
  double w1 = 1, w2 = 1, bias = -4, x1 = 2, x2 = 2;
  Widget slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> change,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '$label: ${value.toStringAsFixed(2)}',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      Slider(
        value: value,
        min: min,
        max: max,
        divisions: 80,
        label: value.toStringAsFixed(2),
        semanticFormatterCallback: (v) => '$label ${v.toStringAsFixed(2)}',
        onChanged: change,
      ),
    ],
  );
  @override
  Widget build(BuildContext context) {
    final score = w1 * x1 + w2 * x2 + bias,
        probability = ClassificationModel.sigmoid(score);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'CLASSICAL ML · CHAPTER 02 · DECISION BOUNDARY',
            icon: Icons.scatter_plot_outlined,
          ),
          const SizedBox(height: 18),
          const Text(
            'Where does the decision change?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Weights ও bias বদলান। Selected point-এর probability দেখুন।',
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
                'z = ${w1.toStringAsFixed(2)}x₁ + ${w2.toStringAsFixed(2)}x₂ + ${bias.toStringAsFixed(2)}',
              ),
              Tag('P(class 1) = ${probability.toStringAsFixed(3)}'),
            ],
          ),
          const SizedBox(height: 18),
          Semantics(
            label:
                'Two-dimensional binary decision boundary at probability 0.5. Selected point ${x1.toStringAsFixed(2)}, ${x2.toStringAsFixed(2)}, probability ${probability.toStringAsFixed(3)}.',
            child: SizedBox(
              height: 270,
              width: double.infinity,
              child: CustomPaint(
                painter: BoundaryPainter(
                  w1,
                  w2,
                  bias,
                  x1,
                  x2,
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).dividerColor,
                  Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '○ Class 1   □ Class 0   ◉ Selected point\nShading: predicted region · Line: p = .5 · Axes: synthetic x₁, x₂',
            style: TextStyle(fontSize: 10, height: 1.9),
          ),
          const SizedBox(height: 18),
          slider('Weight w₁', w1, -3, 3, (v) => setState(() => w1 = v)),
          slider('Weight w₂', w2, -3, 3, (v) => setState(() => w2 = v)),
          slider('Bias b', bias, -8, 8, (v) => setState(() => bias = v)),
          const Divider(),
          const SizedBox(height: 10),
          slider('Selected x₁', x1, 0, 4, (v) => setState(() => x1 = v)),
          slider('Selected x₂', x2, 0, 4, (v) => setState(() => x2 = v)),
          Text(
            'Score ${score.toStringAsFixed(3)} → class ${probability >= .5 ? 1 : 0} at t = 0.50',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() {
              w1 = 1;
              w2 = 1;
              bias = -4;
              x1 = 2;
              x2 = 2;
            }),
            child: const Text('Reset boundary'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Fixed synthetic labels. Sliders set coefficients; no model is fitted here. At zero weights the score is constant and there may be no dividing line. The threshold lab uses a separate set of ten fixed scores.',
            style: TextStyle(fontSize: 10, height: 1.9),
          ),
        ],
      ),
    );
  }
}

class BoundaryPainter extends CustomPainter {
  final double w1, w2, bias, x1, x2;
  final Color color, grid, inkColor;
  BoundaryPainter(
    this.w1,
    this.w2,
    this.bias,
    this.x1,
    this.x2,
    this.color,
    this.grid,
    this.inkColor,
  );
  static const examples = [
    (.3, .6, 0),
    (.8, 1.5, 0),
    (1.4, .6, 0),
    (.6, 3.0, 0),
    (2.0, .9, 0),
    (2.5, 2.0, 1),
    (3.4, 3.0, 1),
    (1.6, 3.6, 1),
    (3.6, .9, 1),
    (2.6, 3.5, 1),
  ];
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTRB(28, 12, size.width - 12, size.height - 28);
    Offset point(double x, double y) => Offset(
      rect.left + x / 4 * rect.width,
      rect.bottom - y / 4 * rect.height,
    );
    for (var ix = 0; ix < 32; ix++) {
      for (var iy = 0; iy < 32; iy++) {
        final score = w1 * (ix + .5) / 8 + w2 * (iy + .5) / 8 + bias;
        canvas.drawRect(
          Rect.fromPoints(
            point(ix / 8, (iy + 1) / 8),
            point((ix + 1) / 8, iy / 8),
          ),
          Paint()
            ..color = (score >= 0 ? color : const Color(0xFFB5783D)).withValues(
              alpha: .09,
            ),
        );
      }
    }
    for (var i = 0; i <= 4; i++) {
      canvas.drawLine(
        point(i.toDouble(), 0),
        point(i.toDouble(), 4),
        Paint()..color = grid,
      );
      canvas.drawLine(
        point(0, i.toDouble()),
        point(4, i.toDouble()),
        Paint()..color = grid,
      );
      _label(canvas, '$i', point(i.toDouble(), 0) + const Offset(-2, 6));
      _label(canvas, '$i', point(0, i.toDouble()) + const Offset(-17, -4));
    }
    final ends = ClassificationModel.boundary(w1, w2, bias);
    if (ends.length >= 2) {
      canvas.drawLine(
        point(ends.first.$1, ends.first.$2),
        point(ends.last.$1, ends.last.$2),
        Paint()
          ..color = color
          ..strokeWidth = 2.5,
      );
    }
    for (final p in examples) {
      final position = point(p.$1, p.$2);
      if (p.$3 == 1) {
        canvas.drawCircle(position, 4.5, Paint()..color = color);
      } else {
        canvas.drawRect(
          Rect.fromCenter(center: position, width: 8, height: 8),
          Paint()
            ..color = const Color(0xFFB5783D)
            ..strokeWidth = 1.8
            ..style = PaintingStyle.stroke,
        );
      }
    }
    canvas.drawCircle(
      point(x1, x2),
      8,
      Paint()
        ..color = inkColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(point(x1, x2), 2.5, Paint()..color = inkColor);
    _label(canvas, 'x₁', Offset(rect.right - 3, size.height - 12));
    _label(canvas, 'x₂', Offset(3, 2));
  }

  void _label(Canvas canvas, String label, Offset at) {
    final text = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(fontSize: 9, color: inkColor, fontFamily: 'Manrope'),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, at);
  }

  @override
  bool shouldRepaint(covariant BoundaryPainter old) =>
      w1 != old.w1 ||
      w2 != old.w2 ||
      bias != old.bias ||
      x1 != old.x1 ||
      x2 != old.x2 ||
      color != old.color ||
      grid != old.grid;
}

class ThresholdLab extends StatefulWidget {
  const ThresholdLab({super.key});
  @override
  State<ThresholdLab> createState() => _ThresholdLabState();
}

class _ThresholdLabState extends State<ThresholdLab> {
  double threshold = .5;
  String metric(double? v) => v == null ? 'N/A' : v.toStringAsFixed(3);
  @override
  Widget build(BuildContext context) {
    final result = ConfusionMetrics.evaluate(
      ThresholdDemo.labels,
      ThresholdDemo.scores,
      threshold,
    );
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag('CLASSICAL ML · CHAPTER 02 · THRESHOLD LAB', icon: Icons.tune),
          const SizedBox(height: 18),
          const Text(
            'Same scores. Different decisions.',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Threshold বদলে ভুলের ধরন আর কতগুলো Case Review করতে হবে, তা তুলনা করুন।',
            style: TextStyle(
              fontFamily: 'NotoSansBengali',
              fontSize: 13,
              height: 2,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Decision threshold: ${threshold.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          Slider(
            key: const Key('threshold-slider'),
            value: threshold,
            min: 0,
            max: 1,
            divisions: 20,
            label: threshold.toStringAsFixed(2),
            semanticFormatterCallback: (v) =>
                'Threshold ${v.toStringAsFixed(2)}',
            onChanged: (v) => setState(() => threshold = v),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              Tag('Precision  ${metric(result.precision)}'),
              Tag('Recall  ${metric(result.recall)}'),
              Tag('F1  ${metric(result.f1)}'),
              Tag('Accuracy  ${metric(result.accuracy)}'),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            'Confusion matrix · actual rows, predicted columns',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, box) => Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final item in [
                  ('TN', result.tn, 'Actual 0 → predicted 0'),
                  ('FP', result.fp, 'Actual 0 → predicted 1'),
                  ('FN', result.fn, 'Actual 1 → predicted 0'),
                  ('TP', result.tp, 'Actual 1 → predicted 1'),
                ])
                  Container(
                    width: (box.maxWidth - 12) / 2,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.$3,
                          style: const TextStyle(fontSize: 9, height: 1.8),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${item.$1}: ${item.$2}',
                          style: const TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Predicted positive: ${result.predictedPositive}/10',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            'Illustrative review cost = FP × 1 + FN × 3 = ${result.fp + 3 * result.fn} units',
            style: const TextStyle(fontSize: 11, height: 1.9),
          ),
          const SizedBox(height: 20),
          const Text(
            'Scores are fixed · p ≥ threshold predicts class 1',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < ThresholdDemo.scores.length; i++)
                Tag(
                  '${ThresholdDemo.scores[i].toStringAsFixed(2)} · y${ThresholdDemo.labels[i]} → ${ThresholdDemo.scores[i] >= threshold ? 1 : 0}',
                ),
            ],
          ),
          const SizedBox(height: 18),
          TextButton(
            onPressed: () => setState(() => threshold = .5),
            child: const Text('Reset threshold'),
          ),
          const Text(
            'Ten synthetic evaluation examples, not a deployment recommendation. N/A means the metric denominator is zero. Choose thresholds using validation/out-of-fold scores; keep final test data untouched. Cost weights above are illustrative.',
            style: TextStyle(fontSize: 10, height: 1.9),
          ),
        ],
      ),
    );
  }
}

class SigmoidPainter extends CustomPainter {
  final Color color, grid;
  SigmoidPainter({required this.color, required this.grid});
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTRB(12, 12, size.width - 12, size.height - 18);
    Offset point(double x, double y) => Offset(
      rect.left + (x + 6) / 12 * rect.width,
      rect.bottom - y * rect.height,
    );
    for (var i = -6; i <= 6; i += 2) {
      canvas.drawLine(
        point(i.toDouble(), 0),
        point(i.toDouble(), 1),
        Paint()..color = grid,
      );
    }
    for (var i = 0; i <= 4; i++) {
      canvas.drawLine(point(-6, i / 4), point(6, i / 4), Paint()..color = grid);
    }
    final path = Path();
    for (var i = 0; i <= 120; i++) {
      final z = -6 + i / 10, p = point(z, ClassificationModel.sigmoid(z));
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
    canvas.drawCircle(point(0, .5), 5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant SigmoidPainter old) =>
      color != old.color || grid != old.grid;
}
