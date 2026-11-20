import 'dart:math';

import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import 'capstone_model.dart';

const _bn = TextStyle(fontFamily: 'NotoSansBengali', height: 1.9);
const _title = TextStyle(fontSize: 24, fontWeight: FontWeight.w800);
const _gap = SizedBox(height: 16);
Color _accent(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? lime : forest;
Widget _asset(
  Future<CapstoneAssets> f,
  Widget Function(CapstoneAssets) build,
) => FutureBuilder<CapstoneAssets>(
  future: f,
  builder: (c, s) {
    if (s.hasError) {
      return const Panel(
        child: Text('Bundled capstone data could not be read. Reopen the lab.'),
      );
    }
    if (!s.hasData) return const Center(child: CircularProgressIndicator());
    return build(s.data!);
  },
);
Widget _source() => const Text(
  'UCI Wine Quality · Cortez et al. (2009) · CC BY 4.0. Actual red-wine source rows; target quality ≥ 6। Labs-এ fit-CV ও decision-validation data আছে, final-test rows নেই। Chemistry profiles verified bottle/batch identities নয়।',
  style: _bn,
);
String _percent(double? x) =>
    x == null ? 'undefined' : '${(x * 100).toStringAsFixed(1)}%';

class ExperimentLab extends StatefulWidget {
  const ExperimentLab({super.key});
  @override
  State<ExperimentLab> createState() => _ExperimentLabState();
}

class _ExperimentLabState extends State<ExperimentLab> {
  final data = CapstoneAssets.load();
  int inspected = -1;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final index = inspected < 0 ? a.selectedIndex : inspected,
        r = a.candidates[index];
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'CLASSICAL ML · CHAPTER 09 · EXPERIMENT BOARD',
            icon: Icons.science_outlined,
          ),
          _gap,
          const Text('Compare evidence. Lock the rule.', style: _title),
          _gap,
          const Text(
            '966 fit rows-এ তিনটি group-separated folds। একই folds-এ prior baseline ও ছয় learned candidates compare করা হয়েছে। Selection rule highest mean AP; exact tie হলে declared order। Dropdown শুধু stored evidence inspect করে, নতুন model train বা official winner বদলায় না।',
            style: _bn,
          ),
          _gap,
          DropdownButtonFormField<int>(
            key: ValueKey('experiment-candidate-$index'),
            initialValue: index,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Inspect a fixed-budget candidate',
            ),
            items: [
              for (var i = 0; i < a.candidates.length; i++)
                DropdownMenuItem(
                  value: i,
                  child: Text(
                    a.candidates[i].label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
            ],
            onChanged: (v) {
              if (v != null) setState(() => inspected = v);
            },
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Tag('Mean CV AP: ${r.meanAp.toStringAsFixed(4)}'),
              Tag('Fold SD: ${r.foldSd.toStringAsFixed(4)}'),
              Tag('Official winner: ${a.selectedId}'),
            ],
          ),
          _gap,
          Semantics(
            label: 'Training-only average precision per candidate. Accent outlines inspected row; bars on a zero-to-one scale. No final-test results used.',
            child: SizedBox(
              height: 310,
              width: double.infinity,
              child: CustomPaint(
                painter: _CandidatePainter(
                  a.candidates,
                  index,
                  _accent(context),
                ),
              ),
            ),
          ),
          Text(
            'Inspected: ${r.label}\nFold AP: ${r.foldAp.map((v) => v.toStringAsFixed(4)).join(' · ')}',
            style: const TextStyle(height: 1.8),
          ),
          _gap,
          const Text(
            'Fold SD একটি variability diagnostic, confidence interval নয়। Folds-এর training sets overlap করে। বেশি complex model এখানে automatic winner নয়। Test ফল দেখে candidate আবার বেছে নিলে নতুন untouched evaluation লাগবে।',
            style: _bn,
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                key: const Key('experiment-prior'),
                onPressed: () => setState(() => inspected = 0),
                child: const Text('Inspect prior baseline'),
              ),
              TextButton(
                onPressed: () => setState(() => inspected = -1),
                child: const Text('Return to winner'),
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

class DecisionLab extends StatefulWidget {
  const DecisionLab({super.key});
  @override
  State<DecisionLab> createState() => _DecisionLabState();
}

class _DecisionLabState extends State<DecisionLab> {
  final data = CapstoneAssets.load();
  double? threshold;
  int costFn = 4;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final tau = threshold ?? a.lockedThreshold,
        r = PolicyResult.compute(a.rows, tau, costFn: costFn.toDouble()),
        best = bestPolicyThreshold(a.rows, costFn: costFn.toDouble());
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag('CLASSICAL ML · CHAPTER 09 · DECISION POLICY', icon: Icons.tune_outlined),
          _gap,
          const Text('A probability still needs a policy.', style: _title),
          _gap,
          const Text(
            '313 actual decision-validation rows-এর fixed selected-model probabilities। Threshold বদলালে confusion counts ও illustrative FP1 / FN cost হিসাব হয়। What-if cost বাস্তব measured business cost নয়; এই controls final-test result retune করে না।',
            style: _bn,
          ),
          _gap,
          Text(
            'Decision threshold: ${tau.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Slider(
            key: const Key('policy-threshold'),
            value: tau,
            min: 0,
            max: 1,
            divisions: 20,
            label: tau.toStringAsFixed(2),
            onChanged: (v) => setState(() => threshold = v),
          ),
          Text(
            'Illustrative false-negative cost: $costFn · false-positive cost: 1',
          ),
          Slider(
            key: const Key('policy-fn-cost'),
            value: costFn.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            label: 'FN $costFn',
            onChanged: (v) => setState(() => costFn = v.round()),
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Tag('TP: ${r.tp} · FP: ${r.fp}'),
              Tag('FN: ${r.fn} · TN: ${r.tn}'),
              Tag('Mean cost: ${r.meanCost.toStringAsFixed(4)}'),
              Tag('Predicted positive: ${r.tp + r.fp} / ${r.n}'),
              Tag('Precision: ${_percent(r.precision)}'),
              Tag('Recall: ${_percent(r.recall)}'),
            ],
          ),
          _gap,
          Semantics(
            label: 'Decision validation mean cost versus threshold. Nineteen fixed grid points, inspected threshold line; lower cost preferred under the stated illustrative costs.',
            child: SizedBox(
              height: 260,
              width: double.infinity,
              child: CustomPaint(
                painter: _CostPainter(
                  a.rows,
                  tau,
                  costFn.toDouble(),
                  _accent(context),
                ),
              ),
            ),
          ),
          Text(
            'Grid minimum at threshold ${best.toStringAsFixed(2)} · locked release threshold ${a.lockedThreshold.toStringAsFixed(2)}',
            style: const TextStyle(height: 1.8),
          ),
          _gap,
          const Text(
            'Prediction rule p ≥ threshold; equality positive। Threshold0 সব row positive করে। Threshold1-এ exact p=1 থাকলে positive থাকতে পারে। No predicted positives হলে precision undefined। Grid ties-এ highest threshold বেছে নেওয়া হয়।',
            style: _bn,
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                key: const Key('policy-positive'),
                onPressed: () => setState(() => threshold = 0),
                child: const Text('Threshold 0.00'),
              ),
              OutlinedButton(
                key: const Key('policy-best'),
                onPressed: () => setState(() => threshold = best),
                child: const Text('Use grid minimum'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  threshold = null;
                  costFn = 4;
                }),
                child: const Text('Reset policy'),
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

class PipelineLab extends StatefulWidget {
  const PipelineLab({super.key});
  @override
  State<PipelineLab> createState() => _PipelineLabState();
}

class _PipelineLabState extends State<PipelineLab> {
  final data = CapstoneAssets.load();
  int query = 0;
  bool standardized = true;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final p = a.pipeline,
        q = p.queries[query],
        z = p.standardize(q.values),
        terms = p.contributions(q.values),
        score = p.logit(q.values),
        probability = p.probability(q.values);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'CLASSICAL ML · CHAPTER 09 · PIPELINE TRACE',
            icon: Icons.account_tree_outlined,
          ),
          _gap,
          const Text('Trace every transform to the score.', style: _title),
          _gap,
          const Text(
            'Actual decision-validation row বেছে raw values → fit-only StandardScaler → weighted contributions → logit → sigmoid অনুসরণ করুন। সব arithmetic Dart-এ। Coordinate-view switch display বদলায়; prediction সবসময় fitted scaling ব্যবহার করে।',
            style: _bn,
          ),
          _gap,
          Tag(
            p.modelId == a.selectedId
                ? 'Logistic C=1 · selected model in this run'
                : 'Logistic C=1 · secondary reference model',
          ),
          _gap,
          DropdownButtonFormField<int>(
            key: ValueKey('pipeline-query-$query'),
            initialValue: query,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Actual source observation',
            ),
            items: [
              for (var i = 0; i < p.queries.length; i++)
                DropdownMenuItem(
                  value: i,
                  child: Text(
                    'Row #${p.queries[i].sourceRow} · quality ${p.queries[i].quality}',
                  ),
                ),
            ],
            onChanged: (v) {
              if (v != null) setState(() => query = v);
            },
          ),
          _gap,
          SwitchListTile(
            key: const Key('pipeline-coordinate'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Display standardized features'),
            value: standardized,
            onChanged: (v) => setState(() => standardized = v),
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Tag('Logit: ${score.toStringAsFixed(4)}'),
              Tag('Probability: ${probability.toStringAsFixed(6)}'),
              Tag('Observed label: ${q.positive}'),
              Tag('Bias: ${p.bias.toStringAsFixed(4)}'),
            ],
          ),
          _gap,
          Semantics(
            label: 'Signed feature contributions to the fitted logistic logit. Positive bars raise score, negative bars lower score. Associational decomposition, not causal effects.',
            child: SizedBox(
              height: 340,
              width: double.infinity,
              child: CustomPaint(
                painter: _ContributionPainter(
                  p.features,
                  terms,
                  _accent(context),
                ),
              ),
            ),
          ),
          const Text(
            'Bars = standardized feature × coefficient, logit units। Bias আলাদা। বড় contribution causal importance নয়; correlated chemistry ও reference mean-এর ওপর interpretation নির্ভর করে।',
            style: _bn,
          ),
          _gap,
          for (var i = 0; i < p.features.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      p.features[i],
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  Text(
                    (standardized ? z[i] : q.values[i]).toStringAsFixed(4),
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          _gap,
          Text(
            standardized
                ? 'Coordinate view: standardized z'
                : 'Coordinate view: raw source units',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          _gap,
          const Text(
            'Full feature order ও scaler contract একই থাকতে হবে। Source row positions bottle ID নয়। Numeric reference checks model arithmetic যাচাই করে, sensory label certainty বা production utility নয়।',
            style: _bn,
          ),
          _gap,
          TextButton(
            onPressed: () => setState(() {
              query = 0;
              standardized = true;
            }),
            child: const Text('Reset pipeline'),
          ),
          _gap,
          _source(),
        ],
      ),
    );
  });
}

void _label(
  Canvas c,
  String text,
  Offset pos,
  Color color, {
  double size = 10,
}) {
  final t = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: 'Manrope',
        fontFamilyFallback: const ['NotoSansMath', 'NotoSans'],
        fontSize: size,
        color: color,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  t.paint(c, pos);
}

class _CandidatePainter extends CustomPainter {
  final List<CandidateResult> rows;
  final int selected;
  final Color accent;
  _CandidatePainter(this.rows, this.selected, this.accent);
  @override
  void paint(Canvas c, Size s) {
    final left = min(138.0, s.width * .44),
        width = s.width - left - 38,
        row = (s.height - 22) / rows.length;
    for (var i = 0; i < rows.length; i++) {
      final y = i * row + 8, r = rows[i];
      _label(c, r.id, Offset(0, y + 3), accent);
      c.drawRect(
        Rect.fromLTWH(left, y, width, 22),
        Paint()..color = accent.withValues(alpha: .08),
      );
      c.drawRect(
        Rect.fromLTWH(left, y, width * r.meanAp, 22),
        Paint()..color = accent.withValues(alpha: i == selected ? .9 : .4),
      );
      _label(
        c,
        r.meanAp.toStringAsFixed(3),
        Offset(left + width + 4, y + 4),
        accent,
        size: 9,
      );
    }
    _label(
      c,
      'FIT grouped CV average precision · scale 0 → 1',
      Offset(0, s.height - 14),
      accent,
      size: 9,
    );
  }

  @override
  bool shouldRepaint(covariant _CandidatePainter old) =>
      old.selected != selected || old.accent != accent;
}

class _CostPainter extends CustomPainter {
  final List<ValidationPrediction> rows;
  final double threshold, costFn;
  final Color accent;
  _CostPainter(this.rows, this.threshold, this.costFn, this.accent);
  @override
  void paint(Canvas c, Size s) {
    final costs = [
      for (var i = 1; i < 20; i++)
        PolicyResult.compute(rows, i / 20, costFn: costFn).meanCost,
    ];
    final top = max(1.0, costs.reduce(max)) * 1.1,
        rect = Rect.fromLTWH(38, 14, s.width - 52, s.height - 46);
    Offset at(double tau, double cost) => Offset(
      rect.left + tau * rect.width,
      rect.bottom - cost / top * rect.height,
    );
    for (var i = 0; i <= 4; i++) {
      final value = top * i / 4, y = at(0, value).dy;
      c.drawLine(
        Offset(rect.left, y),
        Offset(rect.right, y),
        Paint()..color = accent.withValues(alpha: .14),
      );
      _label(c, value.toStringAsFixed(1), Offset(0, y - 6), accent);
      _label(
        c,
        (i / 4).toStringAsFixed(2),
        Offset(rect.left + rect.width * i / 4 - 8, rect.bottom + 6),
        accent,
      );
    }
    for (var i = 0; i < costs.length; i++) {
      final point = at((i + 1) / 20, costs[i]);
      if (i > 0) {
        c.drawLine(
          at(i / 20, costs[i - 1]),
          point,
          Paint()
            ..color = accent
            ..strokeWidth = 2,
        );
      }
      c.drawCircle(point, 2.5, Paint()..color = accent);
    }
    final x = at(threshold, 0).dx;
    c.drawLine(
      Offset(x, rect.top),
      Offset(x, rect.bottom),
      Paint()
        ..color = const Color(0xffdb8e29)
        ..strokeWidth = 1.8,
    );
    _label(
      c,
      'x: threshold · y: mean illustrative cost',
      Offset(rect.left, 0),
      accent,
      size: 9,
    );
  }

  @override
  bool shouldRepaint(covariant _CostPainter old) =>
      old.threshold != threshold ||
      old.costFn != costFn ||
      old.accent != accent;
}

class _ContributionPainter extends CustomPainter {
  final List<String> names;
  final List<double> terms;
  final Color accent;
  _ContributionPainter(this.names, this.terms, this.accent);
  @override
  void paint(Canvas c, Size s) {
    final left = min(156.0, s.width * .47),
        center = (left + s.width - 12) / 2,
        span = (s.width - 12 - left) / 2,
        maximum = max(.001, terms.map((v) => v.abs()).reduce(max)),
        row = (s.height - 20) / terms.length;
    c.drawLine(
      Offset(center, 4),
      Offset(center, s.height - 20),
      Paint()..color = accent.withValues(alpha: .3),
    );
    for (var i = 0; i < terms.length; i++) {
      final y = i * row + 7, end = center + span * terms[i] / maximum;
      _label(c, names[i], Offset(0, y + 2), accent, size: 9);
      c.drawRect(
        Rect.fromLTRB(min(center, end), y, max(center, end), y + 18),
        Paint()..color = terms[i] >= 0 ? accent : const Color(0xffdb8e29),
      );
    }
    _label(
      c,
      'Signed logit contribution · amber negative',
      Offset(0, s.height - 14),
      accent,
      size: 9,
    );
  }

  @override
  bool shouldRepaint(covariant _ContributionPainter old) =>
      old.terms != terms || old.accent != accent;
}
