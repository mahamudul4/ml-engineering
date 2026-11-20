import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import 'statistics_model.dart';

String _percent(double x) => '${(100 * x).toStringAsFixed(2)}%';

class BayesLab extends StatefulWidget {
  const BayesLab({super.key});
  @override
  State<BayesLab> createState() => _BayesLabState();
}

class _BayesLabState extends State<BayesLab> {
  double prevalence = .01, sensitivity = .9, fpr = .05;
  @override
  Widget build(BuildContext context) {
    final result = FlagProbabilities.compute(
      prevalence: prevalence,
      sensitivity: sensitivity,
      falsePositiveRate: fpr,
    );
    final posterior = result.eventGivenFlag;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'ML FOUNDATIONS · CHAPTER 04 · BAYES & BASE RATES',
            icon: Icons.account_tree_outlined,
          ),
          const SizedBox(height: 18),
          const Text(
            'A flag changes the question.',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          const Text(
            'Generic rare-event flagger: P(flag | event) এবং P(event | flag) এক নয়। Base rate বদলে flagged cases-এর composition দেখুন।',
            style: TextStyle(fontFamily: 'NotoSansBengali', height: 2),
          ),
          const SizedBox(height: 18),
          Text(
            'Event base rate: ${_percent(prevalence)}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Slider(
            key: const Key('stats-base'),
            value: prevalence,
            min: 0,
            max: .2,
            divisions: 200,
            label: _percent(prevalence),
            onChanged: (v) => setState(() => prevalence = v),
          ),
          Text(
            'P(flag | event): ${_percent(sensitivity)}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Slider(
            key: const Key('stats-tpr'),
            value: sensitivity,
            min: 0,
            max: 1,
            divisions: 100,
            label: _percent(sensitivity),
            onChanged: (v) => setState(() => sensitivity = v),
          ),
          Text(
            'P(flag | no event): ${_percent(fpr)}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Slider(
            key: const Key('stats-fpr'),
            value: fpr,
            min: 0,
            max: .2,
            divisions: 40,
            label: _percent(fpr),
            onChanged: (v) => setState(() => fpr = v),
          ),
          const SizedBox(height: 14),
          Text(
            posterior == null
                ? 'P(event | flag): undefined (no flags)'
                : 'P(event | flag): ${_percent(posterior)}',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
          ),
          const SizedBox(height: 10),
          Tag('P(flag): ${_percent(result.flagProbability)}'),
          const SizedBox(height: 18),
          const Text(
            'Expected counts in 10,000 illustrative events',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Tag(
                'Event + flag: ${(10000 * result.truePositive).toStringAsFixed(1)}',
              ),
              Tag(
                'No event + flag: ${(10000 * result.falsePositive).toStringAsFixed(1)}',
                color: const Color(0xFFB36D28),
              ),
              Tag(
                'Event + no flag: ${(10000 * result.falseNegative).toStringAsFixed(1)}',
              ),
              Tag(
                'No event + no flag: ${(10000 * result.trueNegative).toStringAsFixed(1)}',
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (posterior != null) ...[
            const Text(
              'Composition among flags only',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Semantics(
              label: 'Among flags, ${_percent(posterior)} are true events',
              child: SizedBox(
                height: 26,
                width: double.infinity,
                child: CustomPaint(
                  painter: _FlagPainter(
                    posterior,
                    Theme.of(context).brightness == Brightness.dark
                        ? lime
                        : forest,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Green: event + flag · Amber: no event + flag',
              style: TextStyle(fontSize: 10, height: 1.8),
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            'Low prevalence-এ false positives অনেক বেশি আসতে পারে, যদিও sensitivity বেশি। FPR=0 এবং positive event mass থাকলে posterior1; flag probability0 হলে conditional probability এই formula-তে defined নয়।',
            style: TextStyle(
              fontFamily: 'NotoSansBengali',
              height: 2,
              fontSize: 12,
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                key: const Key('stats-perfect'),
                onPressed: () => setState(() => fpr = 0),
                child: const Text('Set FPR = 0'),
              ),
              TextButton(
                key: const Key('stats-no-flags'),
                onPressed: () => setState(() {
                  sensitivity = 0;
                  fpr = 0;
                }),
                child: const Text('Set TPR = FPR = 0'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  prevalence = .01;
                  sensitivity = .9;
                  fpr = .05;
                }),
                child: const Text('Reset Bayes'),
              ),
            ],
          ),
          const Text(
            'Constructed probability model, not observed records or a real classifier benchmark. Counts are expected values and can be fractional. No Python executes here.',
            style: TextStyle(fontSize: 10, height: 1.8),
          ),
        ],
      ),
    );
  }
}

class CoverageLab extends StatefulWidget {
  const CoverageLab({super.key});
  @override
  State<CoverageLab> createState() => _CoverageLabState();
}

class _CoverageLabState extends State<CoverageLab> {
  int n = 20, successes = 4;
  double p = .2;
  ConfidenceLevel confidence = ConfidenceLevel.ninetyFive;
  IntervalMethod method = IntervalMethod.wilson;
  @override
  Widget build(BuildContext context) {
    final wilson = BinomialCoverage.compute(n, p, confidence: confidence);
    final wald = BinomialCoverage.compute(
      n,
      p,
      confidence: confidence,
      method: IntervalMethod.wald,
    );
    final chosen = method == IntervalMethod.wilson ? wilson : wald;
    final interval = chosen.intervals[successes];
    final shown = {
      for (var i = 0; i <= 10; i++) (i * n / 10).round(),
      successes,
    }.toList()..sort();
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'ML FOUNDATIONS · CHAPTER 04 · INTERVAL COVERAGE',
            icon: Icons.align_horizontal_center,
          ),
          const SizedBox(height: 18),
          const Text(
            'A confidence level belongs to a procedure.',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          const Text(
            'Binomial(n,p) model-এ সব n+1 possible success counts enumerate করি। কোন intervals true p cover করে, সেই outcomes-এর probabilities যোগ করলে actual model coverage পাওয়া যায়।',
            style: TextStyle(fontFamily: 'NotoSansBengali', height: 2),
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<int>(
            key: ValueKey('stats-n-$n'),
            initialValue: n,
            decoration: const InputDecoration(labelText: 'Sample size n'),
            items: [
              for (final v in [10, 20, 50, 100])
                DropdownMenuItem(value: v, child: Text('$v')),
            ],
            onChanged: (v) {
              if (v != null) {
                setState(() {
                  n = v;
                  successes = (n * p).round();
                });
              }
            },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<ConfidenceLevel>(
            key: ValueKey(confidence),
            initialValue: confidence,
            decoration: const InputDecoration(
              labelText: 'Nominal confidence level',
            ),
            items: [
              for (final v in ConfidenceLevel.values)
                DropdownMenuItem(value: v, child: Text(v.label)),
            ],
            onChanged: (v) {
              if (v != null) setState(() => confidence = v);
            },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<IntervalMethod>(
            key: ValueKey(method),
            initialValue: method,
            decoration: const InputDecoration(
              labelText: 'Interval procedure in plot',
            ),
            items: const [
              DropdownMenuItem(
                value: IntervalMethod.wilson,
                child: Text('Wilson score'),
              ),
              DropdownMenuItem(
                value: IntervalMethod.wald,
                child: Text('Wald normal (clipped)'),
              ),
            ],
            onChanged: (v) {
              if (v != null) setState(() => method = v);
            },
          ),
          const SizedBox(height: 18),
          Text(
            'True p in this model: ${_percent(p)}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Slider(
            key: const Key('stats-true-p'),
            value: p,
            min: .05,
            max: .95,
            divisions: 90,
            label: _percent(p),
            onChanged: (v) => setState(() => p = v),
          ),
          Text(
            'Observed successes: $successes / $n',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Slider(
            key: const Key('stats-successes'),
            value: successes.toDouble(),
            min: 0,
            max: n.toDouble(),
            divisions: n,
            label: '$successes',
            onChanged: (v) => setState(() => successes = v.round()),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Tag('Wilson coverage: ${_percent(wilson.coverage)}'),
              Tag('Wald coverage: ${_percent(wald.coverage)}'),
              Tag(
                'Selected interval: [${interval.lower.toStringAsFixed(3)}, ${interval.upper.toStringAsFixed(3)}]',
              ),
              Tag(
                interval.contains(p)
                    ? 'Selected interval covers p'
                    : 'Selected interval misses p',
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Some possible intervals · vertical line = model p',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Semantics(
            label:
                'Displayed ${shown.length} intervals; exact coverage uses all ${n + 1} outcomes',
            child: SizedBox(
              height: 300,
              width: double.infinity,
              child: CustomPaint(
                painter: _CoveragePainter(
                  n,
                  p,
                  chosen.intervals,
                  shown,
                  successes,
                  Theme.of(context).brightness == Brightness.dark
                      ? lime
                      : forest,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Green covers p; amber misses. Plot shows evenly spaced counts plus the selected count, not equally probable samples. Coverage calculation uses every count with its Binomial probability.',
            style: TextStyle(fontSize: 10, height: 1.8),
          ),
          const SizedBox(height: 12),
          const Text(
            'একটি observed interval-এ parameter থাকার probability95%—এটি frequentist confidence-এর সরাসরি interpretation নয়। Discrete outcomes-এর জন্য actual coverage nominal level-এর চারপাশে বদলাতে পারে। Boundary-তে Wald interval degenerate হয়; clipping সেটি ঠিক করে না।',
            style: TextStyle(
              fontFamily: 'NotoSansBengali',
              height: 2,
              fontSize: 12,
            ),
          ),
          TextButton(
            onPressed: () => setState(() {
              n = 20;
              successes = 4;
              p = .2;
              confidence = ConfidenceLevel.ninetyFive;
              method = IntervalMethod.wilson;
            }),
            child: const Text('Reset coverage'),
          ),
          const Text(
            'Explicit Binomial model with independent Bernoulli trials. Finite enumeration in floating point; no random simulation, no real population parameter claim. Normal z quantiles are fixed for 90/95/99%.',
            style: TextStyle(fontSize: 10, height: 1.8),
          ),
        ],
      ),
    );
  }
}

class _FlagPainter extends CustomPainter {
  final double posterior;
  final Color color;
  _FlagPainter(this.posterior, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFB36D28),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width * posterior, size.height),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _FlagPainter old) =>
      old.posterior != posterior || old.color != color;
}

class _CoveragePainter extends CustomPainter {
  final int n, selected;
  final double p;
  final List<ProportionInterval> intervals;
  final List<int> shown;
  final Color color;
  _CoveragePainter(
    this.n,
    this.p,
    this.intervals,
    this.shown,
    this.selected,
    this.color,
  );
  @override
  void paint(Canvas canvas, Size size) {
    const left = 46.0, right = 14.0, top = 12.0, bottom = 22.0;
    final width = size.width - left - right,
        height = size.height - top - bottom;
    double x(double value) => left + width * value;
    void label(String text, Offset position) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(fontFamily: 'Manrope', fontSize: 10, color: color),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, position);
    }

    for (final tick in [0.0, .25, .5, .75, 1.0]) {
      canvas.drawLine(
        Offset(x(tick), top),
        Offset(x(tick), top + height),
        Paint()..color = color.withValues(alpha: .12),
      );
      label(tick.toStringAsFixed(2), Offset(x(tick) - 10, size.height - 17));
    }
    canvas.drawLine(
      Offset(x(p), top),
      Offset(x(p), top + height),
      Paint()
        ..color = color
        ..strokeWidth = 2,
    );
    for (var i = 0; i < shown.length; i++) {
      final k = shown[i],
          interval = intervals[k],
          y = top + (i + .5) * height / shown.length;
      final shade = interval.contains(p) ? color : const Color(0xFFB36D28);
      label('k=$k', Offset(0, y - 6));
      canvas.drawLine(
        Offset(x(interval.lower), y),
        Offset(x(interval.upper), y),
        Paint()
          ..color = shade
          ..strokeWidth = k == selected ? 4 : 2,
      );
      canvas.drawCircle(
        Offset(x(k / n), y),
        k == selected ? 4 : 2.5,
        Paint()..color = shade,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CoveragePainter old) =>
      old.n != n ||
      old.p != p ||
      old.intervals != intervals ||
      old.selected != selected ||
      old.color != color;
}
