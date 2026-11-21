import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../features/lessons/horizontal_reading_view.dart';
import 'rich_prose.dart';
import 'theme.dart';

/// Compact guided lesson intro card: Learning Goal, Prerequisites, and Outcomes.
class LessonHeaderCard extends StatelessWidget {
  final String goal;
  final List<String> prerequisites;
  final List<String> outcomes;

  const LessonHeaderCard({
    super.key,
    required this.goal,
    this.prerequisites = const [],
    this.outcomes = const [],
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Panel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('LEARNING GOAL'),
          const SizedBox(height: 8),
          RichProse(
            goal,
            style: TextStyle(
              fontFamily: 'NotoSansBengali',
              fontFamilyFallback: const ['Manrope', 'NotoSansMath', 'NotoSans'],
              fontSize: 14,
              height: 1.95,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          if (prerequisites.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Eyebrow('PREREQUISITES'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final pre in prerequisites)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: forest.withValues(alpha: isDark ? .18 : .08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      pre,
                      style: TextStyle(
                        fontFamilyFallback: const ['NotoSansBengali'],
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (outcomes.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Eyebrow('এই পাঠ শেষে আপনি যা পারবেন'),
            const SizedBox(height: 8),
            for (final out in outcomes)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Icon(
                        Icons.check_circle_outline_rounded,
                        size: 16,
                        color: forest,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: RichProse(
                        out,
                        style: const TextStyle(
                          fontFamily: 'NotoSansBengali',
                          fontFamilyFallback: [
                            'Manrope',
                            'NotoSansMath',
                            'NotoSans',
                          ],
                          fontSize: 13,
                          height: 1.85,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Clean vertical flow diagram connecting conceptual or algorithmic steps.
class FlowDiagramCard extends StatelessWidget {
  final String title;
  final List<Map<String, String>> steps;
  final String caption;

  const FlowDiagramCard({
    super.key,
    required this.title,
    required this.steps,
    this.caption = '',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = Theme.of(context).dividerColor;
    final stepBg = forest.withValues(alpha: isDark ? .14 : .06);

    return Panel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty) ...[
            Eyebrow(title.toUpperCase()),
            const SizedBox(height: 14),
          ],
          for (var i = 0; i < steps.length; i++) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: i == steps.length - 1
                    ? forest.withValues(alpha: isDark ? .24 : .12)
                    : stepBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: i == steps.length - 1
                      ? forest.withValues(alpha: .55)
                      : borderColor,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: forest.withValues(alpha: isDark ? .30 : .15),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichProse(
                          steps[i]['label'] ?? '',
                          selectable: false,
                          style: TextStyle(
                            fontFamily: 'NotoSansBengali',
                            fontFamilyFallback: const [
                              'Manrope',
                              'NotoSansMath',
                              'NotoSans',
                            ],
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            height: 1.6,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        if ((steps[i]['detail'] ?? '').isNotEmpty) ...[
                          const SizedBox(height: 3),
                          RichProse(
                            steps[i]['detail']!,
                            selectable: false,
                            style: TextStyle(
                              fontFamily: 'NotoSansBengali',
                              fontFamilyFallback: const [
                                'Manrope',
                                'NotoSansMath',
                                'NotoSans',
                              ],
                              fontSize: 12,
                              height: 1.75,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (i < steps.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Center(
                  child: Icon(
                    Icons.arrow_downward_rounded,
                    size: 18,
                    color: forest,
                  ),
                ),
              ),
          ],
          if (caption.isNotEmpty) ...[
            const SizedBox(height: 14),
            RichProse(
              caption,
              style: TextStyle(
                fontFamily: 'NotoSansBengali',
                fontFamilyFallback: const [
                  'Manrope',
                  'NotoSansMath',
                  'NotoSans',
                ],
                fontSize: 13,
                height: 1.9,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Math display card that explains context BEFORE the formula and defines EVERY
/// symbol right underneath so equations never appear out of nowhere.
class AnnotatedMathCard extends StatelessWidget {
  final String title;
  final String formula;
  final String lead;
  final List<Map<String, String>> symbols;
  final String note;

  const AnnotatedMathCard({
    super.key,
    required this.title,
    required this.formula,
    this.lead = '',
    this.symbols = const [],
    this.note = '',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasAnnotations =
        lead.isNotEmpty || symbols.isNotEmpty || note.isNotEmpty;

    if (!hasAnnotations) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: .05),
          borderRadius: BorderRadius.circular(14),
        ),
        child: HorizontalReadingView(
          hint: 'পুরো সমীকরণ দেখতে ডানে-বাঁয়ে সরান।',
          child: Math.tex(
            formula,
            textStyle: TextStyle(
              fontSize: 19,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      );
    }

    return Panel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty) ...[
            RichProse(
              title,
              selectable: false,
              style: const TextStyle(
                fontFamily: 'NotoSansBengali',
                fontFamilyFallback: ['Manrope', 'NotoSansMath', 'NotoSans'],
                fontSize: 16,
                fontWeight: FontWeight.w800,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (lead.isNotEmpty) ...[
            RichProse(
              lead,
              style: TextStyle(
                fontFamily: 'NotoSansBengali',
                fontFamilyFallback: const [
                  'Manrope',
                  'NotoSansMath',
                  'NotoSans',
                ],
                fontSize: 13.5,
                height: 1.95,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: .90),
              ),
            ),
            const SizedBox(height: 14),
          ],
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: isDark ? .14 : .06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: HorizontalReadingView(
              hint: 'পুরো সমীকরণ দেখতে ডানে-বাঁয়ে সরান।',
              child: Math.tex(
                formula,
                mathStyle: MathStyle.display,
                textStyle: TextStyle(
                  fontSize: 18,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
          if (symbols.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Eyebrow('প্রতিটি SYMBOL-এর অর্থ'),
            const SizedBox(height: 10),
            for (final sym in symbols)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      constraints: const BoxConstraints(
                        minWidth: 54,
                        maxWidth: 116,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: .05),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      alignment: Alignment.center,
                      child: RichProse(
                        sym['symbol'] ?? '',
                        selectable: false,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichProse(
                            sym['meaning'] ?? '',
                            style: const TextStyle(
                              fontFamily: 'NotoSansBengali',
                              fontFamilyFallback: [
                                'Manrope',
                                'NotoSansMath',
                                'NotoSans',
                              ],
                              fontSize: 13,
                              height: 1.8,
                            ),
                          ),
                          if ((sym['example'] ?? '').isNotEmpty) ...[
                            const SizedBox(height: 2),
                            RichProse(
                              sym['example']!,
                              style: TextStyle(
                                fontFamily: 'NotoSansBengali',
                                fontFamilyFallback: const [
                                  'Manrope',
                                  'NotoSansMath',
                                  'NotoSans',
                                ],
                                fontSize: 12,
                                height: 1.75,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (note.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: forest.withValues(alpha: isDark ? .14 : .06),
                borderRadius: BorderRadius.circular(10),
                border: const Border(
                  left: BorderSide(color: forest, width: 3.5),
                ),
              ),
              child: RichProse(
                note,
                style: const TextStyle(
                  fontFamily: 'NotoSansBengali',
                  fontFamilyFallback: ['Manrope', 'NotoSansMath', 'NotoSans'],
                  fontSize: 13,
                  height: 1.85,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ChartSeriesData {
  final String name;
  final List<(double, double)> points;
  final Color color;

  const ChartSeriesData({
    required this.name,
    required this.points,
    required this.color,
  });
}

/// Offline pure-Flutter line chart with optional key metric mini-cards.
class LineChartCard extends StatelessWidget {
  final String title;
  final String xLabel;
  final String yLabel;
  final List<ChartSeriesData> series;
  final List<Map<String, String>> metrics;
  final String provenance;

  const LineChartCard({
    super.key,
    required this.title,
    required this.xLabel,
    required this.yLabel,
    required this.series,
    this.metrics = const [],
    this.provenance = '',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gridColor = Theme.of(context).dividerColor;
    final labelColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Panel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty) ...[
            RichProse(
              title,
              selectable: false,
              style: const TextStyle(
                fontFamily: 'NotoSansBengali',
                fontFamilyFallback: ['Manrope', 'NotoSansMath', 'NotoSans'],
                fontSize: 16,
                fontWeight: FontWeight.w800,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (metrics.isNotEmpty) ...[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final m in metrics)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: forest.withValues(alpha: isDark ? .14 : .06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: gridColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          m['label'] ?? '',
                          style: TextStyle(
                            fontFamilyFallback: const ['NotoSansBengali'],
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: labelColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          m['value'] ?? '',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          if (series.length > 1) ...[
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                for (final s in series)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 3.5,
                        decoration: BoxDecoration(
                          color: s.color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          s.name,
                          style: TextStyle(
                            fontFamilyFallback: const ['NotoSansBengali'],
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: labelColor,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            height: 210,
            width: double.infinity,
            child: CustomPaint(
              painter: _LineChartPainter(
                series: series,
                gridColor: gridColor,
                labelColor: labelColor,
                xLabel: xLabel,
                yLabel: yLabel,
              ),
            ),
          ),
          if (provenance.isNotEmpty) ...[
            const SizedBox(height: 12),
            RichProse(
              provenance,
              style: TextStyle(
                fontFamily: 'NotoSansBengali',
                fontFamilyFallback: const [
                  'Manrope',
                  'NotoSansMath',
                  'NotoSans',
                ],
                fontSize: 11.5,
                height: 1.8,
                color: labelColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<ChartSeriesData> series;
  final Color gridColor;
  final Color labelColor;
  final String xLabel;
  final String yLabel;

  _LineChartPainter({
    required this.series,
    required this.gridColor,
    required this.labelColor,
    required this.xLabel,
    required this.yLabel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final allPts = [for (final s in series) ...s.points];
    if (allPts.isEmpty) return;

    const leftPad = 48.0;
    const rightPad = 18.0;
    const topPad = 18.0;
    const bottomPad = 36.0;
    final plotW = math.max(40.0, size.width - leftPad - rightPad);
    final plotH = math.max(40.0, size.height - topPad - bottomPad);

    var minX = allPts.first.$1, maxX = allPts.first.$1;
    var minY = 0.0, maxY = allPts.first.$2;
    for (final pt in allPts) {
      if (pt.$1 < minX) minX = pt.$1;
      if (pt.$1 > maxX) maxX = pt.$1;
      if (pt.$2 < minY) minY = pt.$2;
      if (pt.$2 > maxY) maxY = pt.$2;
    }
    if (maxX == minX) maxX = minX + 1;
    maxY = maxY <= minY ? minY + 1 : maxY * 1.12;

    double mapX(double x) => leftPad + ((x - minX) / (maxX - minX)) * plotW;
    double mapY(double y) => topPad + plotH - ((y - minY) / (maxY - minY)) * plotH;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    // Horizontal grid lines + Y ticks
    const yTicks = 4;
    for (var i = 0; i <= yTicks; i++) {
      final yVal = minY + (maxY - minY) * (i / yTicks);
      final py = mapY(yVal);
      canvas.drawLine(Offset(leftPad, py), Offset(leftPad + plotW, py), gridPaint);
      final tp = TextPainter(
        text: TextSpan(
          text: yVal >= 10 ? yVal.toStringAsFixed(0) : yVal.toStringAsFixed(1),
          style: TextStyle(fontSize: 10, color: labelColor),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(leftPad - tp.width - 6, py - tp.height / 2));
    }

    // X ticks from first series
    final xSet = <double>{for (final p in series.first.points) p.$1}.toList()..sort();
    final stride = xSet.length > 8 ? (xSet.length / 6).ceil() : 1;
    for (var i = 0; i < xSet.length; i += stride) {
      final xv = xSet[i];
      final px = mapX(xv);
      final tp = TextPainter(
        text: TextSpan(
          text: xv == xv.roundToDouble() ? xv.toInt().toString() : xv.toStringAsFixed(1),
          style: TextStyle(fontSize: 10, color: labelColor),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(px - tp.width / 2, topPad + plotH + 6));
    }

    // Axis titles
    if (xLabel.isNotEmpty) {
      final tp = TextPainter(
        text: TextSpan(
          text: xLabel,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: labelColor,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(leftPad + (plotW - tp.width) / 2, size.height - 14));
    }
    if (yLabel.isNotEmpty) {
      final tp = TextPainter(
        text: TextSpan(
          text: yLabel,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: labelColor,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(4, 0));
    }

    // Series lines & dots
    for (final s in series) {
      if (s.points.isEmpty) continue;
      final linePaint = Paint()
        ..color = s.color
        ..strokeWidth = 2.6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final dotPaint = Paint()..color = s.color;
      final path = Path();
      for (var i = 0; i < s.points.length; i++) {
        final px = mapX(s.points[i].$1);
        final py = mapY(s.points[i].$2);
        if (i == 0) {
          path.moveTo(px, py);
        } else {
          path.lineTo(px, py);
        }
      }
      canvas.drawPath(path, linePaint);
      for (final pt in s.points) {
        canvas.drawCircle(Offset(mapX(pt.$1), mapY(pt.$2)), 3.8, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) =>
      old.series != series || old.gridColor != gridColor;
}

/// Interactive inline Concept Check / Predict-Before-Reveal quiz card.
class ConceptCheckCard extends StatefulWidget {
  final String title;
  final String question;
  final List<String> options;
  final int answer;
  final String explanation;
  final bool predictMode;

  const ConceptCheckCard({
    super.key,
    required this.title,
    required this.question,
    required this.options,
    required this.answer,
    required this.explanation,
    this.predictMode = false,
  });

  @override
  State<ConceptCheckCard> createState() => _ConceptCheckCardState();
}

class _ConceptCheckCardState extends State<ConceptCheckCard> {
  int? _chosen;

  @override
  Widget build(BuildContext context) {
    final answered = _chosen != null;
    final correct = _chosen == widget.answer;
    final badge = widget.predictMode
        ? 'PREDICT BEFORE YOU SEE · আগে নিজে ভাবুন'
        : 'CONCEPT CHECK · ধারণা যাচাই';

    return Panel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Tag(badge, icon: Icons.psychology_alt_outlined),
          if (widget.title.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              widget.title,
              style: const TextStyle(
                fontFamilyFallback: ['NotoSansBengali'],
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          const SizedBox(height: 12),
          RichProse(
            widget.question,
            selectable: false,
            style: const TextStyle(
              fontFamily: 'NotoSansBengali',
              fontFamilyFallback: ['Manrope', 'NotoSansMath', 'NotoSans'],
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              height: 1.85,
            ),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < widget.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    backgroundColor: answered && i == widget.answer
                        ? forest.withValues(alpha: .10)
                        : answered && i == _chosen
                        ? const Color(0xFFB46744).withValues(alpha: .10)
                        : null,
                    side: BorderSide(
                      color: answered && i == widget.answer
                          ? forest
                          : answered && i == _chosen
                          ? const Color(0xFFB46744)
                          : Theme.of(context).dividerColor,
                    ),
                  ),
                  onPressed: () => setState(() => _chosen = i),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${String.fromCharCode(65 + i)}.',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: RichProse(
                          widget.options[i],
                          selectable: false,
                          style: TextStyle(
                            fontFamily: 'NotoSansBengali',
                            fontFamilyFallback: const [
                              'Manrope',
                              'NotoSansMath',
                              'NotoSans',
                            ],
                            fontSize: 13,
                            height: 1.8,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      if (answered && i == widget.answer)
                        const Padding(
                          padding: EdgeInsets.only(left: 8, top: 2),
                          child: Icon(
                            Icons.check_circle_rounded,
                            size: 18,
                            color: forest,
                          ),
                        )
                      else if (answered && i == _chosen)
                        const Padding(
                          padding: EdgeInsets.only(left: 8, top: 2),
                          child: Icon(
                            Icons.cancel_outlined,
                            size: 18,
                            color: Color(0xFFB46744),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          if (answered) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: (correct ? forest : const Color(0xFF9C7139))
                    .withValues(alpha: .09),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          correct
                              ? 'একদম সঠিক! মূল যুক্তিটি মিলিয়ে নিন:'
                              : 'ভালো চেষ্টা — কেন সঠিক উত্তরটি ভিন্ন, তা দেখুন:',
                          style: TextStyle(
                            fontFamilyFallback: const ['NotoSansBengali'],
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: correct ? forest : const Color(0xFF9C7139),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _chosen = null),
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  RichProse(
                    widget.explanation,
                    style: const TextStyle(
                      fontFamily: 'NotoSansBengali',
                      fontFamilyFallback: [
                        'Manrope',
                        'NotoSansMath',
                        'NotoSans',
                      ],
                      fontSize: 13,
                      height: 1.9,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Interactive lesson-scoped Interview Q&A bank organized by concept and
/// difficulty so learners can practice interview questions right inside each
/// lesson after learning the concept.
class InterviewQuestionsCard extends StatefulWidget {
  final String title;
  final String intro;
  final List<Map<String, String>> items;

  const InterviewQuestionsCard({
    super.key,
    required this.title,
    this.intro = '',
    required this.items,
  });

  @override
  State<InterviewQuestionsCard> createState() => _InterviewQuestionsCardState();
}

class _InterviewQuestionsCardState extends State<InterviewQuestionsCard> {
  final Set<int> _expanded = <int>{};
  String _selectedLevel = 'All';

  List<int> _visibleIndices() {
    if (_selectedLevel == 'All') {
      return [for (var i = 0; i < widget.items.length; i++) i];
    }
    return [
      for (var i = 0; i < widget.items.length; i++)
        if ((widget.items[i]['level'] ?? 'Core').toLowerCase() ==
            _selectedLevel.toLowerCase())
          i,
    ];
  }

  void _toggleAll(List<int> visible) {
    setState(() {
      final allOpen =
          visible.isNotEmpty && visible.every((i) => _expanded.contains(i));
      if (allOpen) {
        _expanded.removeAll(visible);
      } else {
        _expanded.addAll(visible);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = Theme.of(context).dividerColor;
    final visible = _visibleIndices();
    final allOpen =
        visible.isNotEmpty && visible.every((i) => _expanded.contains(i));

    final levels = <String>['Core', 'Intermediate', 'Senior'];
    final presentLevels = [
      for (final lv in levels)
        if (widget.items.any(
          (it) => (it['level'] ?? 'Core').toLowerCase() == lv.toLowerCase(),
        ))
          lv,
    ];

    return Panel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Tag(
                'INTERVIEW PREP · এই পাঠ থেকে সম্ভাব্য প্রশ্ন',
                icon: Icons.record_voice_over_outlined,
              ),
              if (visible.isNotEmpty)
                TextButton(
                  onPressed: () => _toggleAll(visible),
                  child: Text(allOpen ? 'সব লুকান' : 'সব উত্তর দেখুন'),
                ),
            ],
          ),
          if (widget.title.isNotEmpty) ...[
            const SizedBox(height: 10),
            RichProse(
              widget.title,
              selectable: false,
              style: const TextStyle(
                fontFamily: 'NotoSansBengali',
                fontFamilyFallback: ['Manrope', 'NotoSansMath', 'NotoSans'],
                fontSize: 17.5,
                fontWeight: FontWeight.w800,
                height: 1.5,
              ),
            ),
          ],
          if (widget.intro.isNotEmpty) ...[
            const SizedBox(height: 6),
            RichProse(
              widget.intro,
              style: TextStyle(
                fontFamily: 'NotoSansBengali',
                fontFamilyFallback: const [
                  'Manrope',
                  'NotoSansMath',
                  'NotoSans',
                ],
                fontSize: 13,
                height: 1.85,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (presentLevels.length > 1) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final lv in ['All', ...presentLevels])
                  ChoiceChip(
                    label: Text(
                      lv == 'All'
                          ? 'All (${widget.items.length})'
                          : '$lv (${widget.items.where((it) => (it['level'] ?? 'Core').toLowerCase() == lv.toLowerCase()).length})',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    selected: _selectedLevel == lv,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => setState(() => _selectedLevel = lv),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          for (final i in visible)
            _buildQuestionCard(context, i, widget.items[i], isDark, borderColor),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(
    BuildContext context,
    int index,
    Map<String, String> item,
    bool isDark,
    Color borderColor,
  ) {
    final isOpen = _expanded.contains(index);
    final level = item['level'] ?? 'Core';
    final concept = item['concept'] ?? '';
    final followUp = item['followUp'] ?? '';

    final levelColor = level.toLowerCase().contains('senior')
        ? const Color(0xFFB44C3B)
        : level.toLowerCase().contains('inter')
        ? const Color(0xFF9C7139)
        : forest;

    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Container(
        decoration: BoxDecoration(
          color: isOpen
              ? forest.withValues(alpha: isDark ? .12 : .045)
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: .02),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isOpen ? forest.withValues(alpha: .45) : borderColor,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() {
                if (isOpen) {
                  _expanded.remove(index);
                } else {
                  _expanded.add(index);
                }
              }),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: forest.withValues(alpha: isDark ? .26 : .12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Q${index + 1}',
                            style: TextStyle(
                              fontFamily: 'JetBrainsMono',
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: levelColor.withValues(alpha: .14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            level,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: levelColor,
                            ),
                          ),
                        ),
                        if (concept.isNotEmpty)
                          Text(
                            concept,
                            style: TextStyle(
                              fontFamilyFallback: const ['NotoSansBengali'],
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: RichProse(
                            item['question'] ?? '',
                            selectable: false,
                            style: const TextStyle(
                              fontFamily: 'NotoSansBengali',
                              fontFamilyFallback: [
                                'Manrope',
                                'NotoSansMath',
                                'NotoSans',
                              ],
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              height: 1.75,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          isOpen
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (isOpen)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Divider(color: borderColor, height: 14),
                    const Eyebrow('MODEL ANSWER · যেভাবে বলবেন'),
                    const SizedBox(height: 8),
                    RichProse(
                      item['answer'] ?? '',
                      style: const TextStyle(
                        fontFamily: 'NotoSansBengali',
                        fontFamilyFallback: [
                          'Manrope',
                          'NotoSansMath',
                          'NotoSans',
                        ],
                        fontSize: 13.5,
                        height: 1.9,
                      ),
                    ),
                    if (followUp.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: const Color(0xFF9C7139).withValues(alpha: .10),
                          borderRadius: BorderRadius.circular(8),
                          border: const Border(
                            left: BorderSide(
                              color: Color(0xFF9C7139),
                              width: 3,
                            ),
                          ),
                        ),
                        child: RichProse(
                          '**Follow-up Trap:** $followUp',
                          style: const TextStyle(
                            fontFamily: 'NotoSansBengali',
                            fontFamilyFallback: [
                              'Manrope',
                              'NotoSansMath',
                              'NotoSans',
                            ],
                            fontSize: 12.5,
                            height: 1.85,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
