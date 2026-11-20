import 'dart:math';

import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import 'unsupervised_model.dart';

const _bn = TextStyle(fontFamily: 'NotoSansBengali', height: 1.9);
const _heading = TextStyle(fontSize: 24, fontWeight: FontWeight.w800);
const _gap = SizedBox(height: 16);
Widget _source() => const Text(
  'UCI Adult · CC BY 4.0 · 96 actual budget-training rows, age / hours_per_week. Income labels ব্যবহার করা হয়নি। মূল 3-feature experiment থেকে আলাদা 2D teaching pool।',
  style: _bn,
);
Widget _asset(
  Future<UnsupervisedAssets> data,
  Widget Function(UnsupervisedAssets) build,
) => FutureBuilder<UnsupervisedAssets>(
  future: data,
  builder: (context, s) {
    if (s.hasError) {
      return const Panel(
        child: Text('Bundled lab data could not be read. Reopen the lab.'),
      );
    }
    if (!s.hasData) return const Center(child: CircularProgressIndicator());
    return build(s.data!);
  },
);
Color _accent(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? lime : forest;
Widget _chart(BuildContext c, _ScatterPainter painter, String semantics) =>
    Semantics(
      label: semantics,
      child: SizedBox(
        height: 310,
        width: double.infinity,
        child: CustomPaint(painter: painter),
      ),
    );

class KMeansLab extends StatefulWidget {
  const KMeansLab({super.key});
  @override
  State<KMeansLab> createState() => _KMeansLabState();
}

class _KMeansLabState extends State<KMeansLab> {
  final data = UnsupervisedAssets.load();
  int run = 1, step = 0;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final r = a.runs[run], s = r.states[step];
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag('CLASSICAL ML · CHAPTER 07 · K-MEANS', icon: Icons.scatter_plot_outlined),
          _gap,
          const Text('Assign. Average. Repeat.', style: _heading),
          _gap,
          const Text(
            'একই real observations-এ Lloyd steps দেখুন। একটি step-এ আগের assignments-এর mean দিয়ে centers update হয়, তারপর নিকটতম center দিয়ে labels আবার নির্ধারিত হয়। Bundled Python trace; device-এ retraining নয়।',
            style: _bn,
          ),
          _gap,
          DropdownButtonFormField<int>(
            key: ValueKey('lloyd-run-$run'),
            initialValue: run,
            decoration: const InputDecoration(
              labelText: 'Fixed start · clusters k / seed',
            ),
            items: [
              for (var i = 0; i < a.runs.length; i++)
                DropdownMenuItem(
                  value: i,
                  child: Text('k=${a.runs[i].k} · seed=${a.runs[i].seed}'),
                ),
            ],
            onChanged: (v) {
              if (v != null) {
                setState(() {
                  run = v;
                  step = 0;
                });
              }
            },
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Tag('Iteration: $step / ${r.states.length - 1}'),
              Tag('Inertia: ${s.inertia.toStringAsFixed(3)}'),
              Tag('Empty before update: ${s.emptyBeforeUpdate.length}'),
            ],
          ),
          Slider(
            value: step.toDouble(),
            min: 0,
            max: (r.states.length - 1).toDouble(),
            divisions: r.states.length - 1,
            label: 'Step $step',
            onChanged: (v) => setState(() => step = v.round()),
          ),
          _chart(
            context,
            _ScatterPainter(
              points: a.points.map((p) => p.coordinates).toList(),
              accent: _accent(context),
              labels: s.labels,
              centers: s.centers,
            ),
            'Equal-unit k-means plot. Colored observations, numbered cross centers. Center labels are arbitrary IDs.',
          ),
          const Text(
            'x: standardized age · y: standardized hours/week · cross = center. Cluster ID কোনো ranking বা income class নয়।',
            style: _bn,
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                key: const Key('lloyd-next'),
                onPressed: step < r.states.length - 1
                    ? () => setState(() => step++)
                    : null,
                child: const Text('Next iteration'),
              ),
              OutlinedButton(
                key: const Key('lloyd-final'),
                onPressed: () => setState(() => step = r.states.length - 1),
                child: const Text('Final iteration'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  run = 1;
                  step = 0;
                }),
                child: const Text('Reset k-means'),
              ),
            ],
          ),
          _gap,
          const Text(
            'Tie হলে smallest center ID; empty center হলে আগের অবস্থান রাখা হয়। Library-এর relocation policy আলাদা হতে পারে। Final snapshot এই bounded run-এর শেষ step; global optimum-এর নিশ্চয়তা নয়।',
            style: _bn,
          ),
          _gap,
          _source(),
        ],
      ),
    );
  });
}

class DensityLab extends StatefulWidget {
  const DensityLab({super.key});
  @override
  State<DensityLab> createState() => _DensityLabState();
}

class _DensityLabState extends State<DensityLab> {
  final data = UnsupervisedAssets.load();
  double eps = .35;
  int minSamples = 5, query = 0;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final points = a.points.map((p) => p.coordinates).toList(),
        r = DensityResult.compute(points, eps: eps, minSamples: minSamples);
    final type = r.core[query]
        ? 'core'
        : r.labels[query] < 0
        ? 'noise'
        : 'border';
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag('CLASSICAL ML · CHAPTER 07 · DBSCAN', icon: Icons.hub_outlined),
          _gap,
          const Text('Density connects core points.', style: _heading),
          _gap,
          const Text(
            'Radius ও min_samples বদলালে Dart-এ neighborhood এবং core components আবার হিসাব হয়। Border point নিজে core নয়; একাধিক core component-এর কাছে থাকলে lowest component ID বেছে নিই। Border দিয়ে দুটি component জোড়া লাগে না।',
            style: _bn,
          ),
          _gap,
          Text(
            'Radius eps: ${eps.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Slider(
            key: const Key('density-radius'),
            value: eps,
            min: .05,
            max: 1.25,
            divisions: 24,
            label: eps.toStringAsFixed(2),
            onChanged: (v) => setState(() => eps = v),
          ),
          DropdownButtonFormField<int>(
            key: ValueKey('density-min-$minSamples'),
            initialValue: minSamples,
            decoration: const InputDecoration(
              labelText: 'min_samples · includes the observation itself',
            ),
            items: [
              for (final n in [3, 5, 8, 97])
                DropdownMenuItem(value: n, child: Text('$n observations')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => minSamples = v);
            },
          ),
          _gap,
          DropdownButtonFormField<String>(
            key: ValueKey('density-query-$query'),
            initialValue: '$query',
            decoration: const InputDecoration(
              labelText: 'Inspect an actual source observation',
            ),
            items: [
              for (var i = 0; i < a.points.length; i++)
                DropdownMenuItem(
                  value: '$i',
                  child: Text(
                    'Row #${a.points[i].sourceRow} · age ${a.points[i].values[0].toInt()} / hours ${a.points[i].values[1].toInt()}',
                  ),
                ),
            ],
            onChanged: (v) {
              if (v != null) setState(() => query = int.parse(v));
            },
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Tag('Clusters: ${r.clusters}'),
              Tag('Noise: ${r.noise} / ${points.length}'),
              Tag('Border: ${r.borders}'),
              Tag(
                'Coverage: ${((points.length - r.noise) / points.length * 100).toStringAsFixed(1)}%',
              ),
              Tag('Selected: $type · neighbors ${r.counts[query]}'),
            ],
          ),
          _gap,
          _chart(
            context,
            _ScatterPainter(
              points: points,
              accent: _accent(context),
              labels: r.labels,
              core: r.core,
              query: query,
              radius: eps,
            ),
            'Equal-unit DBSCAN plot. Filled core points, hollow border points, gray crosses for noise. Ring shows selected epsilon neighborhood including self.',
          ),
          const Text(
            'Filled = core · hollow = border · gray × = noise · ring = eps. একই location-এর একাধিক actual row থাকলে points overlap করতে পারে। Noise মানেই anomaly বা ভুল record নয়।',
            style: _bn,
          ),
          _gap,
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                key: const Key('density-noise'),
                onPressed: () => setState(() => minSamples = 97),
                child: const Text('Try all noise'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  eps = .35;
                  minSamples = 5;
                  query = 0;
                }),
                child: const Text('Reset density'),
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

class PcaLab extends StatefulWidget {
  const PcaLab({super.key});
  @override
  State<PcaLab> createState() => _PcaLabState();
}

class _PcaLabState extends State<PcaLab> {
  final data = UnsupervisedAssets.load();
  int space = 1, q = 1, query = 0;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final p = a.pca[space],
        x = p.data[query],
        restored = p.reconstruct(x, q),
        scores = p.project(x, q);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag('CLASSICAL ML · CHAPTER 07 · PCA', icon: Icons.compress_outlined),
          _gap,
          const Text('Project. Reconstruct. Measure loss.', style: _heading),
          _gap,
          const Text(
            'PCA এই 96 displayed row-তেই fit করা। Raw ও budget-training-standardized space-এর জন্য আলাদা centered SVD আছে। q বদলালে device-এ projection, reconstruction ও MSE হিসাব হয়। Scaling বদলালে objective-এর অর্থও বদলায়।',
            style: _bn,
          ),
          _gap,
          DropdownButtonFormField<String>(
            key: ValueKey('pca-space-$space'),
            initialValue: '$space',
            decoration: const InputDecoration(
              labelText: 'Coordinate space · separately fitted PCA',
            ),
            items: const [
              DropdownMenuItem(value: '0', child: Text('Raw age / hours')),
              DropdownMenuItem(
                value: '1',
                child: Text('Standardized age / hours'),
              ),
            ],
            onChanged: (v) {
              if (v != null) setState(() => space = int.parse(v));
            },
          ),
          _gap,
          DropdownButtonFormField<int>(
            key: ValueKey('pca-q-$q'),
            initialValue: q,
            decoration: const InputDecoration(
              labelText: 'Retained components q',
            ),
            items: [
              for (var i = 0; i <= 2; i++)
                DropdownMenuItem(value: i, child: Text('$i / 2 components')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => q = v);
            },
          ),
          _gap,
          DropdownButtonFormField<String>(
            key: ValueKey('pca-row-$query'),
            initialValue: '$query',
            decoration: const InputDecoration(labelText: 'Inspect source row'),
            items: [
              for (var i = 0; i < a.points.length; i++)
                DropdownMenuItem(
                  value: '$i',
                  child: Text('Row #${a.points[i].sourceRow}'),
                ),
            ],
            onChanged: (v) {
              if (v != null) setState(() => query = int.parse(v));
            },
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Tag('Variance kept: ${(p.kept(q) * 100).toStringAsFixed(2)}%'),
              Tag('Coordinate MSE: ${p.mse(q).toStringAsFixed(6)}'),
              Tag('Components: $q / 2'),
            ],
          ),
          _gap,
          _chart(
            context,
            _ScatterPainter(
              points: p.data,
              accent: _accent(context),
              restored: p.data.map((x) => p.reconstruct(x, q)).toList(),
              query: query,
              mean: p.mean,
              axis: p.components[0],
            ),
            'Equal-coordinate-unit PCA plot. Gray original points and accent reconstructed points, selected residual segment. Principal axis through fitted mean.',
          ),
          Text(
            'Row #${a.points[query].sourceRow}: x = (${x.map((v) => v.toStringAsFixed(3)).join(', ')})\nScores = [${scores.map((v) => v.toStringAsFixed(3)).join(', ')}]\nReconstruction = (${restored.map((v) => v.toStringAsFixed(3)).join(', ')})',
            style: const TextStyle(height: 1.8),
          ),
          _gap,
          const Text(
            'Gray = original · accent = reconstructed · line = PC1 · ring = selected. MSE = SSE / (96 × 2), এই coordinate space-এ। Raw ও standardized MSE সরাসরি তুলনাযোগ্য নয়। q=0 mean-only; q=2 full reconstruction। High variance মানেই predictive signal নয়।',
            style: _bn,
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                key: const Key('pca-full'),
                onPressed: () => setState(() => q = 2),
                child: const Text('Full reconstruction'),
              ),
              OutlinedButton(
                key: const Key('pca-mean'),
                onPressed: () => setState(() => q = 0),
                child: const Text('Mean only'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  space = 1;
                  q = 1;
                  query = 0;
                }),
                child: const Text('Reset PCA'),
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

class _ScatterPainter extends CustomPainter {
  final List<List<double>> points;
  final Color accent;
  final List<int>? labels;
  final List<bool>? core;
  final List<List<double>> centers, restored;
  final int? query;
  final double? radius;
  final List<double>? mean, axis;
  _ScatterPainter({
    required this.points,
    required this.accent,
    this.labels,
    this.core,
    this.centers = const [],
    this.restored = const [],
    this.query,
    this.radius,
    this.mean,
    this.axis,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final all = [...points, ...centers, ...restored];
    var xmin = all.map((p) => p[0]).reduce(min),
        xmax = all.map((p) => p[0]).reduce(max),
        ymin = all.map((p) => p[1]).reduce(min),
        ymax = all.map((p) => p[1]).reduce(max);
    if (query != null && radius != null) {
      xmin = min(xmin, points[query!][0] - radius!);
      xmax = max(xmax, points[query!][0] + radius!);
      ymin = min(ymin, points[query!][1] - radius!);
      ymax = max(ymax, points[query!][1] + radius!);
    }
    final cx = (xmin + xmax) / 2,
        cy = (ymin + ymax) / 2,
        scale =
            min(
              (size.width - 52) / max(xmax - xmin, 1e-9),
              (size.height - 42) / max(ymax - ymin, 1e-9),
            ) *
            .87;
    Offset at(List<double> p) => Offset(
      size.width / 2 + (p[0] - cx) * scale,
      (size.height - 24) / 2 - (p[1] - cy) * scale + 8,
    );
    void text(String s, Offset pos) {
      final p = TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(
            fontSize: 10,
            color: accent,
            fontFamily: 'Manrope',
            fontFamilyFallback: const ['NotoSansMath', 'NotoSans'],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      p.paint(canvas, pos);
    }

    final rect = Rect.fromLTWH(24, 8, size.width - 36, size.height - 32),
        grid = Paint()
          ..color = accent.withValues(alpha: .13)
          ..strokeWidth = 1;
    canvas.drawRect(rect, Paint()..color = accent.withValues(alpha: .025));
    for (var i = 0; i <= 4; i++) {
      final x = rect.left + rect.width * i / 4,
          y = rect.top + rect.height * i / 4;
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), grid);
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), grid);
      text(
        (cx + (x - size.width / 2) / scale).toStringAsFixed(1),
        Offset((x - 9).clamp(0, size.width - 30), rect.bottom + 3),
      );
      if (i > 0) {
        text(
          (cy + ((size.height - 24) / 2 + 8 - y) / scale).toStringAsFixed(1),
          Offset(0, y - 6),
        );
      }
    }
    text('y ↑', Offset(1, 4));
    canvas.save();
    canvas.clipRect(rect);
    if (mean != null && axis != null) {
      final extent = max(xmax - xmin, ymax - ymin) * 2;
      final a = at([
            mean![0] - axis![0] * extent,
            mean![1] - axis![1] * extent,
          ]),
          b = at([mean![0] + axis![0] * extent, mean![1] + axis![1] * extent]);
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = accent.withValues(alpha: .4)
          ..strokeWidth = 1,
      );
    }
    const colors = [
      Color(0xff378a78),
      Color(0xffdb8e29),
      Color(0xff9b73d4),
      Color(0xff3f92ca),
      Color(0xffdd7287),
    ];
    for (var i = 0; i < points.length; i++) {
      final loc = at(points[i]),
          label = labels?[i] ?? 0,
          color = labels == null
              ? const Color(0xff888888).withValues(alpha: .65)
              : label < 0
              ? const Color(0xff888888)
              : colors[label % colors.length];
      final paint = Paint()
        ..color = color
        ..strokeWidth = 1.6;
      if (label < 0) {
        canvas.drawLine(
          loc - const Offset(3, 3),
          loc + const Offset(3, 3),
          paint,
        );
        canvas.drawLine(
          loc + const Offset(-3, 3),
          loc + const Offset(3, -3),
          paint,
        );
      } else {
        paint.style = core != null && !core![i]
            ? PaintingStyle.stroke
            : PaintingStyle.fill;
        canvas.drawCircle(loc, core != null && core![i] ? 4 : 3.3, paint);
      }
      if (restored.isNotEmpty) {
        canvas.drawCircle(at(restored[i]), 2.5, Paint()..color = accent);
      }
    }
    for (var i = 0; i < centers.length; i++) {
      final p = at(centers[i]),
          pen = Paint()
            ..color = accent
            ..strokeWidth = 2.5;
      canvas.drawCircle(p, 8, Paint()..color = accent.withValues(alpha: .12));
      canvas.drawLine(p - const Offset(7, 0), p + const Offset(7, 0), pen);
      canvas.drawLine(p - const Offset(0, 7), p + const Offset(0, 7), pen);
      text('C$i', p + const Offset(8, -10));
    }
    if (query != null) {
      final p = at(points[query!]),
          pen = Paint()
            ..color = accent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2;
      canvas.drawCircle(p, 8, pen);
      if (radius != null) {
        canvas.drawCircle(p, radius! * scale, pen..strokeWidth = 1);
      }
      if (restored.isNotEmpty) {
        canvas.drawLine(p, at(restored[query!]), pen..strokeWidth = 2);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ScatterPainter old) => true;
}
