import 'dart:math';

import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import 'classical_model.dart';

class SvmLab extends StatefulWidget {
  const SvmLab({super.key});
  @override
  State<SvmLab> createState() => _SvmLabState();
}

class _SvmLabState extends State<SvmLab> {
  final data = ClassicalAssets.load();
  int fit = 0, query = 0;
  @override
  Widget build(BuildContext context) => FutureBuilder<ClassicalAssets>(
    future: data,
    builder: (context, s) {
      if (s.hasError) {
        return const Panel(
          child: Text('Bundled margin data could not be read. Reopen the lab.'),
        );
      }
      if (!s.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final a = s.data!,
          m = a.snapshots[fit],
          q = a.svmQueries[query],
          z = a.standardize(q.values),
          score = m.score(z),
          margin = m.signedMargin(z, q.positive);
      return Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Tag('CLASSICAL ML · CHAPTER 06 · SVM GEOMETRY', icon: Icons.linear_scale),
            const SizedBox(height: 18),
            const Text(
              'A score is not a probability.',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            const Text(
              'Real Adult age/education_num: training-only standardized coordinates-এ fixed balanced-weight linear SVC fits। C বেছে আগে Train করা Model-টি দেখুন। এখানে আবার Training হয় না।',
              style: TextStyle(fontFamily: 'NotoSansBengali', height: 2),
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<int>(
              key: ValueKey('svm-fit-$fit'),
              initialValue: fit,
              decoration: const InputDecoration(
                labelText: 'Fitted C · balanced class weights',
              ),
              items: [
                for (var i = 0; i < a.snapshots.length; i++)
                  DropdownMenuItem(
                    value: i,
                    child: Text(a.snapshots[i].c.toString()),
                  ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => fit = v);
              },
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              key: ValueKey('svm-query-$query'),
              initialValue: '$query',
              decoration: const InputDecoration(
                labelText: 'Actual validation observation',
              ),
              items: [
                for (var i = 0; i < a.svmQueries.length; i++)
                  DropdownMenuItem(
                    value: '$i',
                    child: Text('Row #${a.svmQueries[i].sourceRow}'),
                  ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => query = int.parse(v));
              },
            ),
            const SizedBox(height: 12),
            Tag(
              'Query #${q.sourceRow} · age ${q.values[0].toInt()} · education_num ${q.values[1].toInt()}',
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Tag('Score f(x): ${score.toStringAsFixed(3)}'),
                Tag('Signed margin y·f: ${margin.toStringAsFixed(3)}'),
                Tag('Hinge loss: ${max(0, 1 - margin).toStringAsFixed(3)}'),
                Tag('Margin width 2/||w||: ${m.width.toStringAsFixed(3)}'),
                Tag(
                  'Support vectors: ${m.supportCount} / ${a.svmTrainingRows}',
                ),
              ],
            ),
            const SizedBox(height: 18),
            Semantics(
              label: 'Equal-unit standardized SVM plot. Solid line score0, thin lines score plus/minus1; diamond query, outlined training support vectors.',
              child: SizedBox(
                height: 320,
                width: double.infinity,
                child: CustomPaint(
                  painter: _GeometryPainter(
                    a,
                    fit,
                    query,
                    Theme.of(context).brightness == Brightness.dark
                        ? lime
                        : forest,
                  ),
                ),
              ),
            ),
            const Text(
              'Green: >50K · Amber: ≤50K · Diamond: held-out query. Solid boundary f=0; parallel lines f=±1. Axes use equal standardized units. Plot shows 48 training observations; support count uses the full bounded fit.',
              style: TextStyle(fontSize: 10, height: 1.8),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  key: const Key('svm-large'),
                  onPressed: () => setState(() => fit = a.snapshots.length - 1),
                  child: const Text('Show larger C'),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    fit = 0;
                    query = 0;
                  }),
                  child: const Text('Reset margin'),
                ),
              ],
            ),
            const Text(
              'Query label শুধু signed margin/loss diagnose করে, prediction-এ ঢোকে না। Balanced weights C_i বদলায়; this is not a calibrated posterior. Support vectors training rows-এর property, held-out query-এর নয়।',
              style: TextStyle(
                fontFamily: 'NotoSansBengali',
                fontSize: 12,
                height: 2,
              ),
            ),
          ],
        ),
      );
    },
  );
}

class KnnLab extends StatefulWidget {
  const KnnLab({super.key});
  @override
  State<KnnLab> createState() => _KnnLabState();
}

class _KnnLabState extends State<KnnLab> {
  final data = ClassicalAssets.load();
  int query = 0, k = 5, p = 2;
  bool standardized = true, weighted = false, exact = false;
  @override
  Widget build(BuildContext context) => FutureBuilder<ClassicalAssets>(
    future: data,
    builder: (context, s) {
      if (s.hasError) {
        return const Panel(
          child: Text('Bundled neighbors could not be read. Reopen the lab.'),
        );
      }
      if (!s.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final a = s.data!, q = exact ? a.pool.first : a.knnQueries[query];
      final r = NeighborResult.compute(
        a.pool,
        q.values,
        k: k,
        scale: a.knnScale,
        standardized: standardized,
        weighted: weighted,
        p: p,
      );
      return Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Tag(
              'CLASSICAL ML · CHAPTER 06 · NEAREST NEIGHBORS',
              icon: Icons.scatter_plot_outlined,
            ),
            const SizedBox(height: 18),
            const Text(
              'Distance defines the neighborhood.',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            const Text(
              '64টি actual training rows-এর age ও education_num pool। Training-fitted scales, metric ও weighting বদলে neighbors দেখুন। এটি bounded calculator, full model validation score নয়।',
              style: TextStyle(fontFamily: 'NotoSansBengali', height: 2),
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<int>(
              key: ValueKey('knn-query-$query-$exact'),
              initialValue: query,
              decoration: InputDecoration(
                labelText: exact
                    ? 'Exact-match control active'
                    : 'Actual validation query',
              ),
              items: [
                for (var i = 0; i < a.knnQueries.length; i++)
                  DropdownMenuItem(
                    value: i,
                    child: Text('Row #${a.knnQueries[i].sourceRow}'),
                  ),
              ],
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    query = v;
                    exact = false;
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            Tag(
              'Query #${q.sourceRow} · age ${q.values[0].toInt()} · education_num ${q.values[1].toInt()}',
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              key: ValueKey(p),
              initialValue: '$p',
              decoration: const InputDecoration(
                labelText: 'Minkowski distance',
              ),
              items: const [
                DropdownMenuItem(value: '2', child: Text('Euclidean · p=2')),
                DropdownMenuItem(value: '1', child: Text('Manhattan · p=1')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => p = int.parse(v));
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Neighbors k: $k',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Slider(
              key: const Key('knn-k'),
              value: k.toDouble(),
              min: 1,
              max: 15,
              divisions: 14,
              label: '$k',
              onChanged: (v) => setState(() => k = v.round()),
            ),
            SwitchListTile(
              key: const Key('knn-scale'),
              contentPadding: EdgeInsets.zero,
              value: standardized,
              onChanged: (v) => setState(() => standardized = v),
              title: const Text(
                'Use training-standardized distance',
                style: TextStyle(fontSize: 12),
              ),
            ),
            SwitchListTile(
              key: const Key('knn-weight'),
              contentPadding: EdgeInsets.zero,
              value: weighted,
              onChanged: (v) => setState(() => weighted = v),
              title: const Text(
                'Inverse-distance weighting',
                style: TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Neighbor positive fraction: ${r.probability.toStringAsFixed(4)}',
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Tag(
              r.exactOnly
                  ? 'Only zero-distance neighbors contribute'
                  : 'All selected neighbors contribute',
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final n in r.neighbors)
                  Tag(
                    '#${n.point.sourceRow} · d=${n.distance.toStringAsFixed(3)} · y=${n.point.positive} · w=${n.weight.toStringAsFixed(2)}',
                    color: n.point.positive == 1
                        ? null
                        : const Color(0xFFB36D28),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 280,
              width: double.infinity,
              child: CustomPaint(
                painter: _NeighborPainter(
                  a.pool,
                  q,
                  r.neighbors,
                  Theme.of(context).brightness == Brightness.dark
                      ? lime
                      : forest,
                ),
              ),
            ),
            const Text(
              'Plot uses raw feature coordinates for identity; ranking uses the chosen distance. Lines connect selected neighbors. Equal distances keep pool order; cutoff ties may differ from a library ordering.',
              style: TextStyle(fontSize: 10, height: 1.8),
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  key: const Key('knn-exact'),
                  onPressed: () => setState(() {
                    exact = true;
                    weighted = true;
                  }),
                  child: const Text('Query a training point'),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    query = 0;
                    k = 5;
                    p = 2;
                    standardized = true;
                    weighted = false;
                    exact = false;
                  }),
                  child: const Text('Reset neighbors'),
                ),
              ],
            ),
            const Text(
              'Zero distance হলে selected exact matches-ই weight পায়; epsilon দিয়ে arbitrary huge weight নয়। দুটি Row-এর Feature মিললেও সেগুলো একই ব্যক্তির বলে ধরে নেওয়া যায় না। Soft neighbor fraction calibrated deployment probability ধরে নেবেন না।',
              style: TextStyle(
                fontFamily: 'NotoSansBengali',
                fontSize: 12,
                height: 2,
              ),
            ),
          ],
        ),
      );
    },
  );
}

class NaiveBayesLab extends StatefulWidget {
  const NaiveBayesLab({super.key});
  @override
  State<NaiveBayesLab> createState() => _NaiveBayesLabState();
}

class _NaiveBayesLabState extends State<NaiveBayesLab> {
  final data = ClassicalAssets.load();
  int query = 0, mode = 0;
  double? prior;
  @override
  Widget build(BuildContext context) => FutureBuilder<ClassicalAssets>(
    future: data,
    builder: (context, s) {
      if (s.hasError) {
        return const Panel(
          child: Text('Bundled likelihoods could not be read. Reopen the lab.'),
        );
      }
      if (!s.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final a = s.data!,
          q = a.nbQueries[query],
          pi = prior ?? a.priors[1],
          r = GaussianResult.compute(
            q.values,
            a.means,
            a.variances,
            pi,
            mode: mode,
          );
      return Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Tag(
              'CLASSICAL ML · CHAPTER 06 · GAUSSIAN NAIVE BAYES',
              icon: Icons.account_tree_outlined,
            ),
            const SizedBox(height: 18),
            const Text(
              'Add log evidence. Normalize once.',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            const Text(
              'Actual validation observations, training-fitted Gaussian means/variances। Per-feature log density ও log prior যোগ করে log-sum-exp দিয়ে normalize করি। Conditional independence একটি model assumption।',
              style: TextStyle(fontFamily: 'NotoSansBengali', height: 2),
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              key: ValueKey('nb-query-$query'),
              initialValue: '$query',
              decoration: const InputDecoration(
                labelText: 'Actual validation observation',
              ),
              items: [
                for (var i = 0; i < a.nbQueries.length; i++)
                  DropdownMenuItem(
                    value: '$i',
                    child: Text('Row #${a.nbQueries[i].sourceRow}'),
                  ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => query = int.parse(v));
              },
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<int>(
              key: ValueKey('nb-mode-$mode'),
              initialValue: mode,
              decoration: const InputDecoration(labelText: 'Included evidence'),
              items: const [
                DropdownMenuItem(value: 0, child: Text('Age + education')),
                DropdownMenuItem(value: 1, child: Text('Age only')),
                DropdownMenuItem(value: 2, child: Text('Education only')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => mode = v);
              },
            ),
            const SizedBox(height: 12),
            Tag(
              'Query #${q.sourceRow} · age ${q.values[0].toInt()} · education_num ${q.values[1].toInt()}',
            ),
            const SizedBox(height: 18),
            Text(
              'Prior P(>50K): ${(100 * pi).toStringAsFixed(2)}%',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Slider(
              key: const Key('nb-prior'),
              value: pi,
              min: .01,
              max: .99,
              divisions: 98,
              label: pi.toStringAsFixed(2),
              onChanged: (v) => setState(() => prior = v),
            ),
            const Text(
              'Prior slider = what-if sensitivity; likelihoods stay fixed. Default prior is training frequency.',
              style: TextStyle(fontSize: 10, height: 1.8),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var c = 0; c < 2; c++)
                  Tag(
                    '${c == 1 ? '>50K' : '≤50K'} log joint: ${r.joint[c].toStringAsFixed(3)}',
                  ),
              ],
            ),
            const SizedBox(height: 14),
            for (var c = 0; c < 2; c++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${c == 1 ? '>50K' : '≤50K'} · log age ${r.contributions[c][0].toStringAsFixed(3)} · log education ${r.contributions[c][1].toStringAsFixed(3)}',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            const Text(
              'Raw log-density components above are shown for audit; excluded features do not enter the joint score.',
              style: TextStyle(fontSize: 10, height: 1.8),
            ),
            const SizedBox(height: 14),
            Text(
              'Posterior P(>50K | x): ${(100 * r.positiveProbability).toStringAsFixed(2)}%',
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            Semantics(
              label: 'Posterior positive probability ${r.positiveProbability}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: r.positiveProbability,
                  minHeight: 24,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? lime
                      : forest,
                  backgroundColor: const Color(0xFFB36D28),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Green: >50K · Amber: ≤50K. A density is not a point probability; the normalized class posterior is model-dependent.',
              style: TextStyle(fontSize: 10, height: 1.8),
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  key: const Key('nb-high'),
                  onPressed: () => setState(() => prior = .9),
                  child: const Text('Set prior to 90%'),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    query = 0;
                    mode = 0;
                    prior = null;
                  }),
                  child: const Text('Restore fitted prior'),
                ),
              ],
            ),
            Text(
              'Variance epsilon: ${a.epsilon.toStringAsExponential(3)}. Prior changes require justified deployment assumptions; this sensitivity calculator is not a calibrated production classifier. No Python runs in the app.',
              style: const TextStyle(fontSize: 10, height: 1.8),
            ),
          ],
        ),
      );
    },
  );
}

void _label(Canvas canvas, String text, Offset at, {Color color = forest}) {
  (TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(fontFamily: 'Manrope', fontSize: 10, color: color),
    ),
    textDirection: TextDirection.ltr,
  )..layout()).paint(canvas, at);
}

class _GeometryPainter extends CustomPainter {
  final ClassicalAssets a;
  final int fit, query;
  final Color accent;
  _GeometryPainter(this.a, this.fit, this.query, this.accent);
  @override
  void paint(Canvas canvas, Size size) {
    void label(Canvas canvas, String text, Offset at) =>
        _label(canvas, text, at, color: accent);
    final points = [for (final p in a.svmPoints) a.standardize(p.values)],
        q = a.standardize(a.svmQueries[query].values),
        m = a.snapshots[fit];
    final all = [...points, q];
    final low = min(-3.0, all.expand((p) => p).reduce(min) - .3),
        high = max(3.0, all.expand((p) => p).reduce(max) + .3);
    final side = min(size.width - 55, size.height - 40),
        left = (size.width - side) / 2,
        top = 12.0;
    Offset xy(double x, double y) => Offset(
      left + (x - low) * side / (high - low),
      top + (high - y) * side / (high - low),
    );
    final rect = Rect.fromLTWH(left, top, side, side);
    canvas.drawRect(rect, Paint()..color = accent.withValues(alpha: .08));
    for (final t in [low, 0.0, high]) {
      canvas.drawLine(
        xy(t, low),
        xy(t, high),
        Paint()..color = accent.withValues(alpha: .15),
      );
      canvas.drawLine(
        xy(low, t),
        xy(high, t),
        Paint()..color = accent.withValues(alpha: .15),
      );
      label(canvas, t.toStringAsFixed(1), xy(t, low) + const Offset(-8, 5));
    }
    canvas.save();
    canvas.clipRect(rect);
    for (final level in [-1.0, 0.0, 1.0]) {
      final hits = <Offset>[];
      final w = m.weights;
      if (w[1].abs() > 1e-12) {
        for (final x in [low, high]) {
          final y = (level - m.bias - w[0] * x) / w[1];
          if (y >= low && y <= high) hits.add(xy(x, y));
        }
      }
      if (w[0].abs() > 1e-12) {
        for (final y in [low, high]) {
          final x = (level - m.bias - w[1] * y) / w[0];
          if (x >= low && x <= high) hits.add(xy(x, y));
        }
      }
      if (hits.length >= 2) {
        canvas.drawLine(
          hits.first,
          hits.last,
          Paint()
            ..color = accent
            ..strokeWidth = level == 0 ? 2.5 : 1,
        );
      }
    }
    for (var i = 0; i < points.length; i++) {
      final color = a.svmPoints[i].positive == 1
          ? accent
          : const Color(0xFFB36D28);
      canvas.drawCircle(
        xy(points[i][0], points[i][1]),
        3,
        Paint()..color = color,
      );
      if (m.supportFlags[i]) {
        canvas.drawCircle(
          xy(points[i][0], points[i][1]),
          5,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke,
        );
      }
    }
    final c = xy(q[0], q[1]);
    canvas.drawPath(
      Path()
        ..moveTo(c.dx, c.dy - 8)
        ..lineTo(c.dx + 8, c.dy)
        ..lineTo(c.dx, c.dy + 8)
        ..lineTo(c.dx - 8, c.dy)
        ..close(),
      Paint()..color = const Color(0xFF748BCA),
    );
    canvas.restore();
    label(canvas, 'z(age)', Offset(left + side / 2 - 15, top + side + 20));
    label(canvas, 'z(education)', Offset(left, 0));
  }

  @override
  bool shouldRepaint(covariant _GeometryPainter old) =>
      old.fit != fit ||
      old.query != query ||
      old.a != a ||
      old.accent != accent;
}

class _NeighborPainter extends CustomPainter {
  final List<ClassicalPoint> pool;
  final ClassicalPoint query;
  final List<Neighbor> neighbors;
  final Color accent;
  _NeighborPainter(this.pool, this.query, this.neighbors, this.accent);
  @override
  void paint(Canvas canvas, Size size) {
    void label(Canvas canvas, String text, Offset at) =>
        _label(canvas, text, at, color: accent);
    final all = [...pool, query],
        minX = all.map((p) => p.values[0]).reduce(min) - 2,
        maxX = all.map((p) => p.values[0]).reduce(max) + 2,
        minY = all.map((p) => p.values[1]).reduce(min) - 1,
        maxY = all.map((p) => p.values[1]).reduce(max) + 1;
    Offset xy(ClassicalPoint p) => Offset(
      40 + (p.values[0] - minX) * (size.width - 60) / (maxX - minX),
      12 + (maxY - p.values[1]) * (size.height - 45) / (maxY - minY),
    );
    for (final n in neighbors) {
      canvas.drawLine(
        xy(n.point),
        xy(query),
        Paint()..color = accent.withValues(alpha: .3),
      );
    }
    for (final p in pool) {
      canvas.drawCircle(
        xy(p),
        3,
        Paint()..color = (p.positive == 1 ? accent : const Color(0xFFB36D28)),
      );
    }
    for (final n in neighbors) {
      canvas.drawCircle(
        xy(n.point),
        6,
        Paint()
          ..color = accent
          ..style = PaintingStyle.stroke,
      );
    }
    canvas.drawCircle(
      xy(query),
      8,
      Paint()
        ..color = const Color(0xFF748BCA)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    label(
      canvas,
      'Age: ${minX.toInt()} … ${maxX.toInt()}',
      Offset(40, size.height - 20),
    );
    label(
      canvas,
      'Education_num: ${minY.toInt()} … ${maxY.toInt()}',
      const Offset(40, 0),
    );
  }

  @override
  bool shouldRepaint(covariant _NeighborPainter old) =>
      old.query != query || old.neighbors != neighbors || old.accent != accent;
}
