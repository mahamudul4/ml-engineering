import 'dart:math';

import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import 'temporal_model.dart';

const _bn = TextStyle(fontFamily: 'NotoSansBengali', height: 1.9);
const _title = TextStyle(fontSize: 24, fontWeight: FontWeight.w800);
const _gap = SizedBox(height: 16);
Color _accent(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? lime : forest;
Widget _asset(
  Future<TemporalAssets> f,
  Widget Function(TemporalAssets) build,
) => FutureBuilder<TemporalAssets>(
  future: f,
  builder: (c, s) {
    if (s.hasError) {
      return const Panel(
        child: Text('Bundled temporal data could not be read. Reopen the lab.'),
      );
    }
    if (!s.hasData) return const Center(child: CircularProgressIndicator());
    return build(s.data!);
  },
);
Widget _source() => const Text(
  'UCI Bike Sharing · Fanaee-T (2013) · CC BY 4.0. Actual daily counts; original day.csv source rows. Labs use only 2011–June 2012 development data। শেষ 184 দিনের outcomes এই labs-এ নেই।',
  style: _bn,
);
Widget _method(String selected, ValueChanged<String?> change, String prefix) =>
    DropdownButtonFormField<String>(
      key: ValueKey('$prefix-method-$selected'),
      initialValue: selected,
      decoration: const InputDecoration(labelText: 'Fixed-origin baseline'),
      items: const [
        DropdownMenuItem(
          value: 'naive',
          child: Text('Naive · repeat last value'),
        ),
        DropdownMenuItem(
          value: 'seasonal',
          child: Text('Seasonal naive · period 7'),
        ),
        DropdownMenuItem(value: 'drift', child: Text('Drift · endpoint slope')),
      ],
      onChanged: change,
    );
Widget _metrics(ForecastMetrics m) => Wrap(
  spacing: 8,
  runSpacing: 8,
  children: [
    Tag('MAE: ${m.mae.toStringAsFixed(2)}'),
    Tag('RMSE: ${m.rmse.toStringAsFixed(2)}'),
    Tag('MASE7: ${m.mase7?.toStringAsFixed(3) ?? 'undefined'}'),
  ],
);
Widget _plot(
  TemporalAssets a,
  TemporalFold f,
  List<double> prediction,
  Color accent,
) {
  final start = max(f.trainStart, f.origin - 28);
  final actual = <double?>[
    ...a.counts.sublist(start, f.origin),
    ...List<double?>.filled(f.gap, null),
    ...a.counts.sublist(f.validStart, f.validEnd),
  ];
  final predicted = <double?>[
    ...List<double?>.filled(f.validStart - start, null),
    ...prediction,
  ];
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '${a.dates[start]} → ${a.dates[f.validEnd - 1]} · daily rental count',
        style: const TextStyle(fontSize: 11),
      ),
      Semantics(
        label: 'Daily count plot: gray observations, accent fixed-origin forecasts, vertical origin line, blank embargo observations. X is daily order, y is rental count.',
        child: SizedBox(
          height: 260,
          width: double.infinity,
          child: CustomPaint(
            painter: _SeriesPainter(
              actual,
              predicted,
              accent,
              origin: f.origin - start,
            ),
          ),
        ),
      ),
      const Text(
        'Gray = observations · accent = forecast · vertical line = origin. Gap outcomes ব্যবহৃত বা plot করা হয়নি।',
        style: _bn,
      ),
    ],
  );
}

class AnomalyLab extends StatefulWidget {
  const AnomalyLab({super.key});
  @override
  State<AnomalyLab> createState() => _AnomalyLabState();
}

class _AnomalyLabState extends State<AnomalyLab> {
  final data = TemporalAssets.load();
  double threshold = 3.5;
  int selected = 0;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final q = a.queries[selected],
        scores = a.queries
            .map((q) => robustAnomalyScore(q.residual, a.median, a.mad))
            .toList(),
        flags = scores.where((s) => s > threshold).length;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag('CLASSICAL ML · CHAPTER 08 · ANOMALY SCORES', icon: Icons.radar_outlined),
          _gap,
          const Text('A flag needs investigation.', style: _title),
          _gap,
          const Text(
            'Weekly difference r[t]=count[t]−count[t−7]। Median/MAD fit হয়েছে শুধু 2011-এর 358টি differences-এ। এখানে প্রথম 42 development dates-এর score ও strict score > threshold flags আবার Dart-এ গণনা হয়। এগুলো confirmed incident labels বা anomaly probabilities নয়।',
            style: _bn,
          ),
          _gap,
          Text(
            'Threshold: ${threshold.toStringAsFixed(1)}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Slider(
            key: const Key('anomaly-threshold'),
            value: threshold,
            min: .5,
            max: 6,
            divisions: 11,
            label: threshold.toStringAsFixed(1),
            onChanged: (v) => setState(() => threshold = v),
          ),
          DropdownButtonFormField<int>(
            key: ValueKey('anomaly-query-$selected'),
            initialValue: selected,
            decoration: const InputDecoration(
              labelText: 'Inspect actual development day',
            ),
            items: [
              for (var i = 0; i < a.queries.length; i++)
                DropdownMenuItem(
                  value: i,
                  child: Text(
                    '${a.queries[i].date} · row #${a.queries[i].sourceRow}',
                  ),
                ),
            ],
            onChanged: (v) {
              if (v != null) setState(() => selected = v);
            },
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Tag('Flags: $flags / ${a.queries.length}'),
              Tag('Selected score: ${scores[selected].toStringAsFixed(3)}'),
              Tag(
                scores[selected] > threshold
                    ? 'Selected: flagged'
                    : 'Selected: below threshold',
              ),
            ],
          ),
          _gap,
          Semantics(
            label: 'Robust absolute weekly-difference score over 42 actual dates; horizontal threshold, outlined selected day.',
            child: SizedBox(
              height: 260,
              width: double.infinity,
              child: CustomPaint(
                painter: _SeriesPainter(
                  scores,
                  List<double?>.filled(scores.length, null),
                  _accent(context),
                  threshold: threshold,
                  selected: selected,
                ),
              ),
            ),
          ),
          Text(
            '${q.date} · daily count ${q.actual.toInt()} · previous week ${q.lag7.toInt()}\nDifference ${q.residual.toInt()} · training median ${a.median} · MAD ${a.mad}',
            style: const TextStyle(height: 1.8),
          ),
          _gap,
          const Text(
            'x: chronological days · y: absolute robust score. Seasonality বা growth expected change তৈরি করতে পারে। Threshold কমালে flags বাড়তে পারে; precision/recall বাড়ে এমন দাবি labels ছাড়া করা যায় না।',
            style: _bn,
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                key: const Key('anomaly-sensitive'),
                onPressed: () => setState(() => threshold = .5),
                child: const Text('More sensitive'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  threshold = 3.5;
                  selected = 0;
                }),
                child: const Text('Reset alerts'),
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

class ForecastLab extends StatefulWidget {
  const ForecastLab({super.key});
  @override
  State<ForecastLab> createState() => _ForecastLabState();
}

class _ForecastLabState extends State<ForecastLab> {
  final data = TemporalAssets.load();
  int origin = 365, horizon = 7;
  String method = 'seasonal';
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final f = TemporalFold.create(
          n: a.counts.length,
          origin: origin,
          horizon: horizon,
        ),
        history = a.history(origin),
        prediction = baselineForecast(
          history,
          horizon: horizon,
          method: method,
        ),
        m = ForecastMetrics.compute(
          a.counts.sublist(f.validStart, f.validEnd),
          prediction,
          history,
        );
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'CLASSICAL ML · CHAPTER 08 · FORECAST ORIGIN',
            icon: Icons.timeline_outlined,
          ),
          _gap,
          const Text('Freeze the origin. Forecast forward.', style: _title),
          _gap,
          const Text(
            'একটি cutoff-এ দাঁড়িয়ে সব h দিনের forecast একসঙ্গে করি। Future actual values শুধু error মাপার জন্য; prediction-এ যায় না। এটি one-step rolling evaluation নয়। Realized future weather এবং same-day casual/registered target components ব্যবহার হয়নি।',
            style: _bn,
          ),
          _gap,
          DropdownButtonFormField<int>(
            key: ValueKey('forecast-origin-$origin'),
            initialValue: origin,
            decoration: const InputDecoration(
              labelText: 'Last observed day · fixed origin',
            ),
            items: [
              for (final o in [365, 456, 517])
                DropdownMenuItem(value: o, child: Text(a.dates[o - 1])),
            ],
            onChanged: (v) {
              if (v != null) setState(() => origin = v);
            },
          ),
          _gap,
          _method(method, (v) {
            if (v != null) setState(() => method = v);
          }, 'forecast'),
          _gap,
          DropdownButtonFormField<int>(
            key: ValueKey('forecast-horizon-$horizon'),
            initialValue: horizon,
            decoration: const InputDecoration(labelText: 'Forecast horizon'),
            items: [
              for (final h in [7, 14, 28])
                DropdownMenuItem(value: h, child: Text('$h days ahead')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => horizon = v);
            },
          ),
          _gap,
          Tag('Horizon: $horizon days · origin ${a.dates[origin - 1]}'),
          _gap,
          _metrics(m),
          _gap,
          _plot(a, f, prediction, _accent(context)),
          _gap,
          Text(
            'First forecast: ${prediction.first.toStringAsFixed(2)} rentals · last: ${prediction.last.toStringAsFixed(2)}\nMASE7 denominator uses only ${history.length} observed training days.',
            style: const TextStyle(height: 1.8),
          ),
          _gap,
          const Text(
            'Drift negative forecast দিতে পারে; এখানে silently clip করি না। Baseline formula বোঝাই, count-distribution model fit নয়। Horizon বদলালে evaluation dates-ও বদলায়; MAE-এর পার্থক্যকে শুধু horizon-এর causal effect বলবেন না।',
            style: _bn,
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                key: const Key('forecast-long'),
                onPressed: () => setState(() => horizon = 28),
                child: const Text('28-day forecast'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  origin = 365;
                  horizon = 7;
                  method = 'seasonal';
                }),
                child: const Text('Reset forecast'),
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

class BacktestLab extends StatefulWidget {
  const BacktestLab({super.key});
  @override
  State<BacktestLab> createState() => _BacktestLabState();
}

class _BacktestLabState extends State<BacktestLab> {
  final data = TemporalAssets.load();
  int origin = 365, gap = 0;
  bool rolling = false;
  String method = 'drift';
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final f = TemporalFold.create(
          n: a.counts.length,
          origin: origin,
          horizon: 14,
          gap: gap,
          window: rolling ? 90 : null,
        ),
        history = a.history(origin, window: rolling ? 90 : null),
        prediction = baselineForecast(
          history,
          horizon: 14,
          method: method,
          gap: gap,
        ),
        m = ForecastMetrics.compute(
          a.counts.sublist(f.validStart, f.validEnd),
          prediction,
          history,
        );
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'CLASSICAL ML · CHAPTER 08 · CHRONOLOGICAL BACKTEST',
            icon: Icons.date_range_outlined,
          ),
          _gap,
          const Text('Train on the past. Respect the gap.', style: _title),
          _gap,
          const Text(
            'Origin slider-এর আগে train, পরে gap, তারপর 14 দিনের validation। Gap মানে forecast lead আরও দীর্ঘ; intermediate outcomes baseline পায় না। Expanding বা last-90-day training বেছে নিন। এটি fixed-origin block; মূল Python workflow-এর one-step CV protocol আলাদা।',
            style: _bn,
          ),
          _gap,
          Text(
            'Training rows end before index $origin',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Slider(
            key: const Key('backtest-origin'),
            value: origin.toDouble(),
            min: 180,
            max: 490,
            divisions: 310,
            label: a.dates[origin - 1],
            onChanged: (v) => setState(() => origin = v.round()),
          ),
          SwitchListTile(
            key: const Key('backtest-window'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Rolling 90-day training'),
            value: rolling,
            onChanged: (v) => setState(() => rolling = v),
          ),
          DropdownButtonFormField<int>(
            key: ValueKey('backtest-gap-$gap'),
            initialValue: gap,
            decoration: const InputDecoration(
              labelText: 'Unobserved gap before validation',
            ),
            items: const [
              DropdownMenuItem(value: 0, child: Text('0 days')),
              DropdownMenuItem(value: 7, child: Text('7 days')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => gap = v);
            },
          ),
          _gap,
          _method(method, (v) {
            if (v != null) setState(() => method = v);
          }, 'backtest'),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Tag('Training rows: ${f.trainCount}'),
              Tag('Gap: $gap days'),
              Tag(
                'Validation: ${a.dates[f.validStart]} → ${a.dates[f.validEnd - 1]}',
              ),
            ],
          ),
          _gap,
          Semantics(
            label: 'Complete development timeline. Accent training, amber excluded gap, blue validation, gray unused dates.',
            child: SizedBox(
              height: 54,
              width: double.infinity,
              child: CustomPaint(
                painter: _FoldPainter(a.counts.length, f, _accent(context)),
              ),
            ),
          ),
          const Text(
            'Accent = training · amber = gap · blue = validation · gray = unused. Origin-এর পরে validation পর্যন্ত কোনো outcomes forecast history-তে নেই।',
            style: _bn,
          ),
          _gap,
          _metrics(m),
          _gap,
          _plot(a, f, prediction, _accent(context)),
          _gap,
          const Text(
            'Rolling window drift slope ও training MASE denominator বদলায়। Naive/seasonal-এর recent history একই থাকলে তাদের predictions অপরিবর্তিত থাকতে পারে। Row gap নিজে delayed labels, overlapping targets বা future covariates-এর leakage ঠিক করে না।',
            style: _bn,
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                key: const Key('backtest-embargo'),
                onPressed: () => setState(() => gap = 7),
                child: const Text('Add 7-day gap'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  origin = 365;
                  gap = 0;
                  rolling = false;
                  method = 'drift';
                }),
                child: const Text('Reset backtest'),
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

class _FoldPainter extends CustomPainter {
  final int n;
  final TemporalFold fold;
  final Color accent;
  _FoldPainter(this.n, this.fold, this.accent);
  @override
  void paint(Canvas c, Size s) {
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 8, s.width, 30),
        const Radius.circular(6),
      ),
      Paint()..color = const Color(0xff888888).withValues(alpha: .2),
    );
    for (final b in [
      (fold.trainStart, fold.origin, accent),
      (fold.origin, fold.validStart, const Color(0xffdb8e29)),
      (fold.validStart, fold.validEnd, const Color(0xff3f92ca)),
    ]) {
      c.drawRect(
        Rect.fromLTRB(b.$1 / n * s.width, 8, b.$2 / n * s.width, 38),
        Paint()..color = b.$3,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FoldPainter old) =>
      old.fold != fold || old.accent != accent;
}

class _SeriesPainter extends CustomPainter {
  final List<double?> actual, predicted;
  final Color accent;
  final int? origin, selected;
  final double? threshold;
  _SeriesPainter(
    this.actual,
    this.predicted,
    this.accent, {
    this.origin,
    this.threshold,
    this.selected,
  });
  @override
  void paint(Canvas c, Size s) {
    final values = [...actual, ...predicted].whereType<double>().toList();
    final high = max(1.0, max(values.reduce(max), threshold ?? 0)) * 1.12,
        low = min(0.0, values.reduce(min));
    final rect = Rect.fromLTWH(40, 12, max(1, s.width - 52), s.height - 40);
    Offset at(int i, double y) => Offset(
      rect.left + i / max(1, actual.length - 1) * rect.width,
      rect.bottom - (y - low) / (high - low) * rect.height,
    );
    void label(String text, Offset pos) {
      final t = TextPainter(
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
      t.paint(c, pos);
    }

    for (var i = 0; i <= 4; i++) {
      final value = low + (high - low) * i / 4, y = at(0, value).dy;
      c.drawLine(
        Offset(rect.left, y),
        Offset(rect.right, y),
        Paint()..color = accent.withValues(alpha: .14),
      );
      label(value.toStringAsFixed(threshold == null ? 0 : 1), Offset(0, y - 6));
    }
    for (final k in [0, (actual.length - 1) ~/ 2, actual.length - 1]) {
      label('${k + 1}', Offset(at(k, 0).dx - 5, rect.bottom + 6));
    }
    c.save();
    c.clipRect(rect);
    if (origin != null) {
      final x = (at(origin!, low).dx + at(origin! - 1, low).dx) / 2;
      c.drawLine(
        Offset(x, rect.top),
        Offset(x, rect.bottom),
        Paint()
          ..color = accent.withValues(alpha: .6)
          ..strokeWidth = 1,
      );
    }
    void line(List<double?> data, Color color) {
      final pen = Paint()
        ..color = color
        ..strokeWidth = 1.8;
      for (var i = 0; i < data.length; i++) {
        final v = data[i];
        if (v == null) continue;
        if (i > 0 && data[i - 1] != null) {
          c.drawLine(at(i - 1, data[i - 1]!), at(i, v), pen);
        }
        c.drawCircle(at(i, v), 2.3, pen);
      }
    }

    line(actual, const Color(0xff888888));
    line(predicted, accent);
    if (threshold != null) {
      final y = at(0, threshold!).dy;
      c.drawLine(
        Offset(rect.left, y),
        Offset(rect.right, y),
        Paint()
          ..color = const Color(0xffdb8e29)
          ..strokeWidth = 1.8,
      );
    }
    if (selected != null && actual[selected!] != null) {
      c.drawCircle(
        at(selected!, actual[selected!]!),
        6,
        Paint()
          ..color = accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    c.restore();
  }

  @override
  bool shouldRepaint(covariant _SeriesPainter old) => true;
}
