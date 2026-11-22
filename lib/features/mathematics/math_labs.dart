import 'dart:math';

import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import 'math_model.dart';

String _number(double x) => (x.abs() < .0005 ? 0.0 : x).toStringAsFixed(3);
String _coordinates(MathVector v) => '(${_number(v.x)}, ${_number(v.y)})';

class ProjectionLab extends StatefulWidget {
  const ProjectionLab({super.key});
  @override
  State<ProjectionLab> createState() => _ProjectionLabState();
}

class _ProjectionLabState extends State<ProjectionLab> {
  double degrees = 0;
  bool zero = false;
  @override
  Widget build(BuildContext context) {
    final point = MathVector(3, 2);
    final direction = zero
        ? MathVector(0, 0)
        : MathVector(cos(degrees * pi / 180), sin(degrees * pi / 180));
    final projection = zero ? null : VectorProjection.of(point, direction);
    final color = Theme.of(context).brightness == Brightness.dark
        ? lime
        : forest;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag('ML FOUNDATIONS · CHAPTER 03 · VECTOR GEOMETRY', icon: Icons.open_with),
          const SizedBox(height: 18),
          const Text(
            'Keep the component. Inspect the residual.',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          const Text(
            'x=(3,2)-কে direction u-এর span-এ project করুন। Angle বদলালে Projection বদলায়। Residual ওই Direction-এর সঙ্গে Orthogonal থাকে।',
            style: TextStyle(fontFamily: 'NotoSansBengali', height: 2),
          ),
          const SizedBox(height: 18),
          Text(
            'Direction angle: ${degrees.round()}°',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Slider(
            key: const Key('math-angle'),
            value: degrees,
            min: -180,
            max: 180,
            divisions: 360,
            label: '${degrees.round()}°',
            onChanged: (v) => setState(() => degrees = v),
          ),
          SwitchListTile.adaptive(
            key: const Key('math-zero'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Use the zero direction'),
            subtitle: const Text('Expose the zero-denominator edge case.'),
            value: zero,
            onChanged: (v) => setState(() => zero = v),
          ),
          const SizedBox(height: 16),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: AspectRatio(
                aspectRatio: 1.3,
                child: Semantics(
                  label: projection == null
                      ? 'Zero direction: use the zero-subspace case separately'
                      : 'Projection ${_coordinates(projection.projected)}, residual ${_coordinates(projection.residual)}',
                  child: CustomPaint(
                    painter: _GeometryPainter(
                      point,
                      direction,
                      projection,
                      color,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Tag('x · green'),
              Tag('span(u) · amber', color: Color(0xFFB36D28)),
              Tag('projection · blue', color: Color(0xFF477CA6)),
            ],
          ),
          const SizedBox(height: 14),
          if (projection == null)
            const Tag(
              'Nonzero-direction formula undefined',
              color: Color(0xFFB36D28),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Tag('Projection: ${_coordinates(projection.projected)}'),
                Tag('Residual: ${_coordinates(projection.residual)}'),
                Tag(
                  'Residual · unit(u): ${_number(projection.residual.dot(projection.unit))}',
                ),
              ],
            ),
          const SizedBox(height: 14),
          const Text(
            'Nonzero u-কে rescale বা sign flip করলে span/projection একই। Zero Vector-এর কোনো Direction নেই। তাই ওই Formula-তে ভাগের হিসাব করা যায় না। Dot≈0 numerical orthogonality দেখায়; floating-point equality সবসময় exact নয়।',
            style: TextStyle(
              fontFamily: 'NotoSansBengali',
              height: 2,
              fontSize: 12,
            ),
          ),
          TextButton(
            onPressed: () => setState(() {
              degrees = 0;
              zero = false;
            }),
            child: const Text('Reset projection'),
          ),
          const Text(
            'Explicit mathematical vectors; not dataset observations. Axes show −4..4. Pure Dart geometry, no Python runtime.',
            style: TextStyle(fontSize: 10, height: 1.8),
          ),
        ],
      ),
    );
  }
}

class CurvatureLab extends StatefulWidget {
  const CurvatureLab({super.key});
  @override
  State<CurvatureLab> createState() => _CurvatureLabState();
}

class _CurvatureLabState extends State<CurvatureLab> {
  double kappa = 5, ratio = .8;
  int steps = 0;
  @override
  Widget build(BuildContext context) {
    final run = QuadraticRun.compute(kappa: kappa, ratio: ratio, steps: steps);
    final color = Theme.of(context).brightness == Brightness.dark
        ? lime
        : forest;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'ML FOUNDATIONS · CHAPTER 03 · CURVATURE & DESCENT',
            icon: Icons.multiline_chart,
          ),
          const SizedBox(height: 18),
          const Text(
            'One step size. Two curvatures.',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          const Text(
            'Rotated quadratic J(θ)=½θᵀHθ; eigenvalues 1 ও κ। Start=(3,2), minimum=(0,0)। Learning rate η=ratio/κ; stable range বোঝার জন্য ratio=ηL বদলান।',
            style: TextStyle(fontFamily: 'NotoSansBengali', height: 2),
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<double>(
            key: ValueKey(kappa),
            initialValue: kappa,
            decoration: const InputDecoration(
              labelText: 'Hessian condition number κ(H)',
            ),
            items: [
              for (final v in [1.0, 5.0, 20.0])
                DropdownMenuItem(value: v, child: Text(v.toStringAsFixed(0))),
            ],
            onChanged: (v) {
              if (v != null) {
                setState(() {
                  kappa = v;
                  steps = 0;
                });
              }
            },
          ),
          const SizedBox(height: 18),
          Text(
            'eta × L: ${ratio.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Slider(
            key: const Key('math-rate'),
            value: ratio,
            min: .1,
            max: 2.4,
            divisions: 23,
            label: ratio.toStringAsFixed(2),
            onChanged: (v) => setState(() {
              ratio = v;
              steps = 0;
            }),
          ),
          const Text(
            'Stable range: 0 < eta × L < 2',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton(
                key: const Key('math-step'),
                onPressed: run.stopped || steps >= 100
                    ? null
                    : () => setState(() => steps++),
                child: const Text('Step'),
              ),
              OutlinedButton(
                key: const Key('math-20'),
                onPressed: run.stopped || steps >= 100
                    ? null
                    : () => setState(() => steps = min(100, steps + 20)),
                child: const Text('20 steps'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  kappa = 5;
                  ratio = .8;
                  steps = 0;
                }),
                child: const Text('Reset descent'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Tag('Steps: ${run.losses.length - 1}'),
              Tag('Loss: ${_number(run.losses.last)}'),
              Tag('eta: ${_number(ratio / kappa)}'),
              if (run.stopped)
                const Tag('Divergence guard reached', color: Color(0xFFB36D28))
              else if (ratio >= 2)
                const Tag('Outside stable step range', color: Color(0xFFB36D28))
              else
                const Tag('Within stable step range'),
            ],
          ),
          const SizedBox(height: 18),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: AspectRatio(
                aspectRatio: 1.3,
                child: Semantics(
                  label:
                      'Quadratic contours and ${run.points.length - 1} gradient steps; current loss ${_number(run.losses.last)}',
                  child: CustomPaint(
                    painter: _ContourPainter(kappa, run.points, color),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Current θ: ${_coordinates(run.points.last)}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          const Text(
            'κ বড় হলে সবচেয়ে খাড়া Direction-টি Global Step Size-এর সীমা ঠিক করে। Flat Direction-এ তাই অগ্রগতি ধীর হয়। ηL≥2-এ এই SPD quadratic-এর convergence guarantee থাকে না। Plot −4..4-এ clipped; বড় numeric values উপরে দেখানো হয়।',
            style: TextStyle(
              fontFamily: 'NotoSansBengali',
              fontSize: 12,
              height: 2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Constructed quadratic, not empirical model performance. Guard stops before loss > 1e12 or norm > 1e6; at most 100 steps. Loss is this mathematical objective, not validation error.',
            style: TextStyle(fontSize: 10, height: 1.8),
          ),
        ],
      ),
    );
  }
}

class _Plot {
  final Canvas canvas;
  final Size size;
  _Plot(this.canvas, this.size);
  Rect get area {
    final side = min(size.width, size.height) - 28;
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: side,
      height: side,
    );
  }

  Offset at(MathVector p) => Offset(
    area.center.dx + p.x * area.width / 8,
    area.center.dy - p.y * area.height / 8,
  );
  void grid(Color color) {
    final paint = Paint()
      ..color = color.withValues(alpha: .12)
      ..strokeWidth = 1;
    for (var i = -4; i <= 4; i++) {
      canvas.drawLine(
        at(MathVector(i.toDouble(), -4)),
        at(MathVector(i.toDouble(), 4)),
        paint,
      );
      canvas.drawLine(
        at(MathVector(-4, i.toDouble())),
        at(MathVector(4, i.toDouble())),
        paint,
      );
    }
    paint.color = color.withValues(alpha: .5);
    canvas.drawLine(at(MathVector(-4, 0)), at(MathVector(4, 0)), paint);
    canvas.drawLine(at(MathVector(0, -4)), at(MathVector(0, 4)), paint);
  }

  void arrow(MathVector endpoint, Color color) {
    final origin = at(MathVector(0, 0)), end = at(endpoint);
    canvas.drawLine(
      origin,
      end,
      Paint()
        ..color = color
        ..strokeWidth = 3,
    );
    final angle = atan2(end.dy - origin.dy, end.dx - origin.dx);
    for (final delta in [-.45, .45]) {
      canvas.drawLine(
        end,
        end - Offset(10 * cos(angle + delta), 10 * sin(angle + delta)),
        Paint()
          ..color = color
          ..strokeWidth = 3,
      );
    }
  }
}

class _GeometryPainter extends CustomPainter {
  final MathVector point, direction;
  final VectorProjection? projection;
  final Color color;
  _GeometryPainter(this.point, this.direction, this.projection, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final plot = _Plot(canvas, size);
    plot.grid(color);
    canvas.save();
    canvas.clipRect(plot.area);
    if (projection != null) {
      final unit = projection!.unit;
      canvas.drawLine(
        plot.at(unit.scale(-6)),
        plot.at(unit.scale(6)),
        Paint()
          ..color = const Color(0xFFB36D28)
          ..strokeWidth = 2,
      );
      canvas.drawLine(
        plot.at(projection!.projected),
        plot.at(point),
        Paint()
          ..color = color.withValues(alpha: .5)
          ..strokeWidth = 2,
      );
      plot.arrow(projection!.projected, const Color(0xFF477CA6));
    }
    plot.arrow(point, color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GeometryPainter old) =>
      old.direction.x != direction.x ||
      old.direction.y != direction.y ||
      old.color != color;
}

class _ContourPainter extends CustomPainter {
  final double kappa;
  final List<MathVector> points;
  final Color color;
  _ContourPainter(this.kappa, this.points, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final plot = _Plot(canvas, size);
    plot.grid(color);
    canvas.save();
    canvas.clipRect(plot.area);
    final c = cos(QuadraticSurface.angle), s = sin(QuadraticSurface.angle);
    for (final level in [1.0, 3.0, 6.0, 12.0, 24.0]) {
      final path = Path();
      for (var i = 0; i <= 120; i++) {
        final t = i * 2 * pi / 120,
            low = sqrt(2 * level) * cos(t),
            high = sqrt(2 * level / kappa) * sin(t);
        final p = plot.at(MathVector(c * low - s * high, s * low + c * high));
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: .24)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final p = plot.at(points[i]);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawCircle(p, 2.5, Paint()..color = color);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      plot.at(points.last),
      5,
      Paint()..color = const Color(0xFFB36D28),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ContourPainter old) =>
      old.kappa != kappa || old.points != points || old.color != color;
}
