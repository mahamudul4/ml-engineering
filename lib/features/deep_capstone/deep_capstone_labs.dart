import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import 'deep_capstone_model.dart';

const _gap = SizedBox(height: 16),
    _bn = TextStyle(fontFamily: 'NotoSansBengali', height: 1.85),
    _title = TextStyle(fontSize: 24, fontWeight: FontWeight.w800);
String _vec(List<double> values) =>
    '[${values.map((v) => v.toStringAsFixed(5)).join(', ')}]';
Widget _asset(
  Future<DeepCapstoneAssets> future,
  Widget Function(DeepCapstoneAssets) build,
) => FutureBuilder<DeepCapstoneAssets>(
  future: future,
  builder: (c, s) {
    if (s.hasError) {
      return const Panel(
        child: Text(
          'Bundled capstone evidence could not be read. Reopen the lab.',
        ),
      );
    }
    if (!s.hasData) {
      return const Center(child: CircularProgressIndicator());
    }
    return build(s.data!);
  },
);
Widget _source() => const Text(
  'White Wine Quality · Cortez et al. (2009) · UCI · CC BY4.0। 4898 actual observations; exact chemistry profiles grouped। quality≥6 একটি educational target, commercial grading নয়। Final-test rows এই labs-এ নেই; published test results এখন observed। App Python train করে না।',
  style: _bn,
);

class DeepExperimentLab extends StatefulWidget {
  const DeepExperimentLab({super.key});
  @override
  State<DeepExperimentLab> createState() => _DeepExperimentLabState();
}

class _DeepExperimentLabState extends State<DeepExperimentLab> {
  final data = DeepCapstoneAssets.load();
  String recipe = 'scaled';
  int epoch = 80;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final pipeline = a.pipelines[recipe]!;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'DEEP LEARNING & RL · CHAPTER 07 · EXPERIMENT LEDGER',
            icon: Icons.science_outlined,
          ),
          _gap,
          const Text(
            'Select on fit. Diagnose without reselection.',
            style: _title,
          ),
          _gap,
          const Text(
            'Prior, Logistic ও MLP তিনটি fixed candidate-এর fit-only grouped CV mean AP দিয়ে model lock হয়। Decision validation বা test দেখে candidate বদলায় না। No-scale MLP একই initialization/budget-এর separately trained diagnostic ablation; selection candidate নয়।',
            style: _bn,
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Tag('Locked model: ${a.winner.toUpperCase()}'),
              Tag('Fit rows: ${a.roleRows['fit']}'),
              const Tag('CV folds: 3'),
            ],
          ),
          _gap,
          for (final c in a.candidates)
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${c.id.toUpperCase()} · mean AP ${c.meanAp.toStringAsFixed(6)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  for (var i = 0; i < 3; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 50,
                            child: Text(
                              'Fold ${i + 1}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          Expanded(
                            child: LinearProgressIndicator(
                              value: c.foldAp[i],
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            c.foldAp[i].toStringAsFixed(4),
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Tag('Recipe: $recipe'),
              Tag('Epoch: $epoch / 80'),
              const Tag('105 parameters'),
            ],
          ),
          _gap,
          Slider(
            key: const Key('deep-epoch'),
            value: epoch.toDouble(),
            min: 0,
            max: 80,
            divisions: 80,
            label: '$epoch',
            onChanged: (v) => setState(() => epoch = v.round()),
          ),
          Text(
            'Actual fit-role BCE at update $epoch: ${pipeline.loss[epoch].toStringAsFixed(6)}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          _gap,
          SizedBox(
            height: 160,
            width: double.infinity,
            child: CustomPaint(
              painter: _LossPainter(
                a.pipelines['scaled']!.loss,
                a.pipelines['no_scale']!.loss,
                epoch,
                Theme.of(context).brightness == Brightness.dark ? lime : forest,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Updates 0 → 80 · green=scaled · orange=no-scale · y=training BCE',
            style: TextStyle(fontSize: 11),
          ),
          _gap,
          Text(
            'Decision AP · scaled MLP ${a.mlpDecisionAp.toStringAsFixed(6)}\nDecision AP · no-scale ablation ${a.noScaleDecisionAp.toStringAsFixed(6)}',
            style: const TextStyle(height: 1.9),
          ),
          _gap,
          const Text(
            'Curve হলো actual stored training evidence; slider replay করে, app training চালায় না। Same seed21,105 parameters,AdamW.01/decay.001,80 full-batch updates,clip1। Scaling বদলালে optimization path ও effective feature units বদলায়। এক seed/recipe থেকে universal scaling বা neural superiority দাবি নয়।',
            style: _bn,
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                key: const Key('deep-ablation'),
                onPressed: () => setState(() => recipe = 'no_scale'),
                child: const Text('Inspect no-scale run'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  recipe = 'scaled';
                  epoch = 80;
                }),
                child: const Text('Reset experiment'),
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

class _LossPainter extends CustomPainter {
  final List<double> scaled, raw;
  final int epoch;
  final Color primary;
  _LossPainter(this.scaled, this.raw, this.epoch, this.primary);
  @override
  void paint(Canvas c, Size s) {
    final high = math.max(.01, [...scaled, ...raw].reduce(math.max));
    for (var i = 0; i < 4; i++) {
      final y = 8 + i * (s.height - 16) / 3;
      c.drawLine(
        Offset(0, y),
        Offset(s.width, y),
        Paint()..color = Colors.grey.withValues(alpha: .18),
      );
    }
    Offset point(int i, double v) =>
        Offset(i / 80 * s.width, s.height - 8 - v / high * (s.height - 16));
    for (final pair in [(scaled, primary), (raw, Colors.deepOrange)]) {
      final path = Path();
      for (var i = 0; i < 81; i++) {
        final p = point(i, pair.$1[i]);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      c.drawPath(
        path,
        Paint()
          ..color = pair.$2
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );
      c.drawCircle(point(epoch, pair.$1[epoch]), 4, Paint()..color = pair.$2);
    }
  }

  @override
  bool shouldRepaint(covariant _LossPainter old) =>
      old.epoch != epoch || old.primary != primary;
}

class DeepPolicyLab extends StatefulWidget {
  const DeepPolicyLab({super.key});
  @override
  State<DeepPolicyLab> createState() => _DeepPolicyLabState();
}

class _DeepPolicyLabState extends State<DeepPolicyLab> {
  final data = DeepCapstoneAssets.load();
  double? inspect;
  double costFn = 4;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final t = inspect ?? a.threshold,
        result = a.policy(t, costFn: costFn),
        costs = [
          for (var i = 1; i < 20; i++)
            a.policy(i / 20, costFn: costFn).meanCost,
        ],
        high = math.max(.001, costs.reduce(math.max));
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag('DEEP LEARNING & RL · CHAPTER 07 · LOCKED POLICY', icon: Icons.tune_outlined),
          _gap,
          const Text(
            'Move the threshold. Keep the test locked.',
            style: _title,
          ),
          _gap,
          const Text(
            'Model fit/CV-এর পরে decision validation threshold বেছে নেয়। FP1/FN4 illustrative costs; বাস্তব business costs নয়। Slider ও cost control what-if inspection, recorded final-test policy বদলায় না। AP ranking metric; threshold বদলালে confusion/cost বদলায়, fixed probability ranking নয়।',
            style: _bn,
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Tag('Locked threshold: ${a.threshold.toStringAsFixed(2)}'),
              Tag('Inspect threshold: ${t.toStringAsFixed(2)}'),
              Tag('Cost FN: ${costFn.toInt()}'),
              Tag('Decision rows: ${a.decisions.length}'),
            ],
          ),
          _gap,
          Slider(
            key: const Key('deep-threshold'),
            value: t,
            min: 0,
            max: 1,
            divisions: 20,
            label: t.toStringAsFixed(2),
            onChanged: (v) => setState(() => inspect = v),
          ),
          _gap,
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final pair in [
                ('TN', result.tn),
                ('FP', result.fp),
                ('FN', result.fn),
                ('TP', result.tp),
              ])
                Container(
                  width: 100,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: forest.withValues(alpha: .09),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${pair.$1}\n${pair.$2}',
                    style: const TextStyle(
                      fontSize: 18,
                      height: 1.8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          _gap,
          Text(
            'Mean cost: ${result.meanCost.toStringAsFixed(6)}\nPrecision: ${result.precision?.toStringAsFixed(4) ?? 'undefined'} · Recall: ${result.recall?.toStringAsFixed(4) ?? 'undefined'}\nDecision-only best under inspected costs: ${a.inspectBestThreshold(costFn: costFn).toStringAsFixed(2)}',
            style: const TextStyle(height: 1.9),
          ),
          _gap,
          const Text(
            'Decision cost curve · thresholds .05 → .95 · tap a bar',
            style: TextStyle(fontSize: 11),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 100,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < 19; i++)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => inspect = (i + 1) / 20),
                      child: Container(
                        height: 8 + costs[i] / high * 92,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: ((i + 1) / 20 - t).abs() < 1e-9
                              ? Colors.deepOrange
                              : forest.withValues(alpha: .55),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _gap,
          const Text(
            'Prediction rule p≥threshold। Lowest mean cost wins; grid ties-এ highest threshold। Threshold0 সব rows positive, threshold1 সাধারণত none—but p=1 হলে inclusive rule positive রাখে। Undefined precision/recall denominatorকে fake0 বানাই না। Final-test rows এই lab-এ দেওয়া হয়নি।',
            style: _bn,
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                key: const Key('deep-policy-zero'),
                onPressed: () => setState(() => inspect = 0),
                child: const Text('Inspect all-positive policy'),
              ),
              OutlinedButton(
                key: const Key('deep-policy-cost'),
                onPressed: () => setState(() => costFn = 8),
                child: const Text('Inspect FN cost 8'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  inspect = null;
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

class DeepArtifactLab extends StatefulWidget {
  const DeepArtifactLab({super.key});
  @override
  State<DeepArtifactLab> createState() => _DeepArtifactLabState();
}

class _DeepArtifactLabState extends State<DeepArtifactLab> {
  final data = DeepCapstoneAssets.load();
  String pipeline = 'scaled';
  int sample = 0;
  bool wrongOrder = false;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final row = a.samples[sample];
    DeepTrace? trace;
    try {
      trace = a.pipelines[pipeline]!.forward(
        row.raw,
        names: wrongOrder ? a.features.reversed.toList() : a.features,
      );
    } on FormatException {
      trace = null;
    }
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'DEEP LEARNING & RL · CHAPTER 07 · ARTIFACT CONTRACT',
            icon: Icons.inventory_2_outlined,
          ),
          _gap,
          const Text(
            'Reload the pipeline. Verify the prediction.',
            style: _title,
          ),
          _gap,
          const Text(
            'First3 decision rows in source order—correct predictions দেখে বাছা নয়। Numeric MLP weights, fit-only scaler, ordered feature names ও sigmoid মিলে complete inference pipeline। Same dimension11 থাকলেও wrong column order reject হয়। Main selected model ও diagnostic MLP pipeline identity ledger-এ আলাদা।',
            style: _bn,
          ),
          _gap,
          DropdownButtonFormField<int>(
            key: ValueKey('artifact-row-$sample'),
            initialValue: sample,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Actual decision observation',
            ),
            items: [
              for (var i = 0; i < 3; i++)
                DropdownMenuItem(
                  value: i,
                  child: Text(
                    'Source row ${a.samples[i].sourceRow} · score ${a.samples[i].quality}',
                  ),
                ),
            ],
            onChanged: (v) {
              if (v != null) {
                setState(() => sample = v);
              }
            },
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Tag('Pipeline: $pipeline'),
              Tag(trace == null ? 'Schema: rejected' : 'Schema: accepted'),
              Tag('Source row: ${row.sourceRow}'),
            ],
          ),
          _gap,
          if (trace == null)
            const Text(
              'Ordered feature names do not match the saved schema. Prediction stopped before arithmetic. Shape[11] alone cannot protect against column permutation.',
              style: TextStyle(height: 1.9, fontWeight: FontWeight.w700),
            )
          else ...[
            Text(
              'Logit: ${trace.logit.toStringAsFixed(6)}\nSigmoid probability: ${trace.probability.toStringAsFixed(6)}\nSensory score: ${row.quality} · educational label: ${row.quality >= 6 ? 1 : 0}',
              style: const TextStyle(height: 1.9, fontWeight: FontWeight.w700),
            ),
            _gap,
            for (var i = 0; i < 11; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(
                  '${i + 1}. ${a.features[i]} · raw ${row.raw[i]} → model input ${trace.standardized[i].toStringAsFixed(5)}',
                  style: const TextStyle(fontSize: 12, height: 1.8),
                ),
              ),
            _gap,
            Text(
              'Hidden preactivation:\n${_vec(trace.pre)}\nReLU hidden:\n${_vec(trace.hidden)}',
              style: const TextStyle(height: 1.9),
            ),
            _gap,
          ],
          const Text(
            'Local CLI exports mlp.pt,no_scale.pt,logistic.joblib,schema,selection manifest,model card,golden rows ও checksums। App trusted numeric JSON forward চালায়; arbitrary pickle/checkpoint load করে না। Only own trusted compatible Python artifacts load করুন। Feature/schema hashes integrity জানায়, generalization বা safety guarantee নয়।',
            style: _bn,
          ),
          _gap,
          const Text(
            'No-scale mode একটি separately trained raw-input MLP; scaled model-এ ভুল করে scaler বাদ দেওয়া নয়। Package contract test-এ saved scaler+weights reload করে golden predictions match করি। Published final test future tuning-এর validation source নয়।',
            style: _bn,
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                key: const Key('deep-artifact-order'),
                onPressed: () => setState(() => wrongOrder = true),
                child: const Text('Inspect wrong feature order'),
              ),
              OutlinedButton(
                key: const Key('deep-artifact-raw'),
                onPressed: () => setState(() => pipeline = 'no_scale'),
                child: const Text('Inspect raw-input MLP'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  pipeline = 'scaled';
                  sample = 0;
                  wrongOrder = false;
                }),
                child: const Text('Reset artifact'),
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
