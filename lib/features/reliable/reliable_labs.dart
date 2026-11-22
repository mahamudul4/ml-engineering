import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import 'reliable_model.dart';

const _gap = SizedBox(height: 16),
    _bn = TextStyle(fontFamily: 'NotoSansBengali', height: 1.85),
    _title = TextStyle(fontSize: 24, fontWeight: FontWeight.w800);
Widget _asset(
  Future<ReliableAssets> f,
  Widget Function(ReliableAssets) build,
) => FutureBuilder<ReliableAssets>(
  future: f,
  builder: (c, s) {
    if (s.hasError) {
      return const Panel(
        child: Text(
          'Bundled training-state evidence could not be read. Reopen the lab.',
        ),
      );
    }
    if (!s.hasData) return const Center(child: CircularProgressIndicator());
    return build(s.data!);
  },
);
Widget _source() => const Text(
  'UCI Wine Quality · Cortez et al. (2009) · CC BY 4.0. Existing inner train 776 / diagnostic validation 190; preprocessing inner training-এ fit। CPU float64 PyTorch references; app Dart দিয়ে mechanics গণনা করে, Python train করে না। পুরোনো decision/test roles পুনরায় score হয়নি।',
  style: _bn,
);

class OptimizerLab extends StatefulWidget {
  const OptimizerLab({super.key});
  @override
  State<OptimizerLab> createState() => _OptimizerLabState();
}

class _OptimizerLabState extends State<OptimizerLab> {
  final data = ReliableAssets.load();
  String kind = 'sgd';
  int steps = 0;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final r = OptimizerReplay.compute(
          a.initial,
          a.gradient,
          kind,
          steps: steps,
        ),
        p = r.values.last;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag('DEEP LEARNING & RL · CHAPTER 03 · OPTIMIZER STATE', icon: Icons.tune_outlined),
          _gap,
          const Text('The gradient is only part of the update.', style: _title),
          _gap,
          const Text(
            'বাস্তব Data-র 8টি Row থেকে হিসাব করা Mean BCE Gradient-এর তিনটি নির্দিষ্ট Coordinate বারবার প্রয়োগ করে Optimizer State তুলনা করি। এখানে fixed gradient replay; পরিবর্তিত model-এ gradient recompute বা retraining হচ্ছে না। সব তিন coordinates-এ illustrative decay .1, main recipe-এর parameter-group policy আলাদা।',
            style: _bn,
          ),
          _gap,
          DropdownButtonFormField<String>(
            key: ValueKey('optimizer-kind-$kind'),
            initialValue: kind,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Optimizer mechanics'),
            items: const [
              DropdownMenuItem(
                value: 'sgd',
                child: Text('SGD · coupled decay'),
              ),
              DropdownMenuItem(
                value: 'momentum',
                child: Text('Momentum .9 · coupled decay'),
              ),
              DropdownMenuItem(
                value: 'adam',
                child: Text('Adam · coupled decay'),
              ),
              DropdownMenuItem(
                value: 'adamw',
                child: Text('AdamW · decoupled decay'),
              ),
            ],
            onChanged: (v) {
              if (v != null) {
                setState(() {
                  kind = v;
                  steps = 0;
                });
              }
            },
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Tag('Optimizer: $kind'),
              Tag('Replay steps: $steps / 3'),
              const Tag('Learning rate: 0.01'),
              const Tag('Decay: 0.1'),
            ],
          ),
          _gap,
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '${['hidden.weight[0,0]', 'hidden.weight[1,1]', 'output.bias[0]'][i]}\nInitial ${a.initial[i].toStringAsFixed(7)} · frozen gradient ${a.gradient[i].toStringAsFixed(7)}\nCurrent ${p[i].toStringAsFixed(7)} · Δ ${(p[i] - a.initial[i]).toStringAsFixed(7)}',
                style: const TextStyle(height: 1.8),
              ),
            ),
          _gap,
          const Text(
            'SGD/momentum/Adam-এ এখানে decay gradient-এ যোগ হয়। AdamW-তে Parameter Shrinkage, Adaptive Moment Update থেকে আলাদাভাবে হয়। Adam-এর bias correction ও epsilon-ও update নির্ধারণ করে; একই gradient মানেই একই parameter step নয়।',
            style: _bn,
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                key: const Key('optimizer-step'),
                onPressed: steps < 3 ? () => setState(() => steps++) : null,
                child: const Text('Replay one step'),
              ),
              OutlinedButton(
                key: const Key('optimizer-adamw'),
                onPressed: () => setState(() {
                  kind = 'adamw';
                  steps = 3;
                }),
                child: const Text('Inspect AdamW step 3'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  kind = 'sgd';
                  steps = 0;
                }),
                child: const Text('Reset optimizer'),
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

class NormalizationLab extends StatefulWidget {
  const NormalizationLab({super.key});
  @override
  State<NormalizationLab> createState() => _NormalizationLabState();
}

class _NormalizationLabState extends State<NormalizationLab> {
  final data = ReliableAssets.load();
  String mode = 'batch_train';
  int row = 0;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final r = NormalizedBatch.compute(
      a.activations,
      mode,
      runningMean: a.runningMean,
      runningVariance: a.runningVariance,
    );
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'DEEP LEARNING & RL · CHAPTER 03 · NORMALIZATION AXES',
            icon: Icons.view_array_outlined,
          ),
          _gap,
          const Text('Choose the axes. Check the mode.', style: _title),
          _gap,
          const Text(
            'প্রথম আটটি actual inner-training rows-এর initial hidden preactivations [8,4]। BatchNorm training-এ প্রতি channel batch statistics, eval-এ running statistics; LayerNorm প্রতি Row-তে চারটি Feature Normalize করে। Affine=False, epsilon1e−5। এটি layer mechanics audit; main trained model-এ BN/LN যোগ করা হয়নি।',
            style: _bn,
          ),
          _gap,
          DropdownButtonFormField<String>(
            key: ValueKey('normalization-mode-$mode'),
            initialValue: mode,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Normalization contract',
            ),
            items: const [
              DropdownMenuItem(
                value: 'batch_train',
                child: Text('BatchNorm · train statistics'),
              ),
              DropdownMenuItem(
                value: 'batch_eval',
                child: Text('BatchNorm · eval running statistics'),
              ),
              DropdownMenuItem(
                value: 'layer',
                child: Text('LayerNorm · each row, 4 features'),
              ),
            ],
            onChanged: (v) {
              if (v != null) setState(() => mode = v);
            },
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Tag('Mode: $mode'),
              Tag(
                mode == 'layer'
                    ? 'Reduction axes: features'
                    : 'Reduction axes: batch (train)',
              ),
              const Tag('Shape: [8, 4]'),
            ],
          ),
          _gap,
          DropdownButtonFormField<int>(
            key: ValueKey('normalization-row-$row'),
            initialValue: row,
            decoration: const InputDecoration(
              labelText: 'Actual training source row',
            ),
            items: [
              for (var i = 0; i < 8; i++)
                DropdownMenuItem(
                  value: i,
                  child: Text('Source #${a.sourceRows[i]}'),
                ),
            ],
            onChanged: (v) {
              if (v != null) setState(() => row = v);
            },
          ),
          _gap,
          for (var j = 0; j < 4; j++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Text(
                'Hidden channel $j\nInput ${a.activations[row][j].toStringAsFixed(6)} → normalized ${r.values[row][j].toStringAsFixed(6)}\nMean ${r.mean[mode == 'layer' ? row : j].toStringAsFixed(6)} · variance ${r.variance[mode == 'layer' ? row : j].toStringAsFixed(6)}',
                style: const TextStyle(height: 1.8),
              ),
            ),
          _gap,
          Text(
            'Running mean after one batch: [${a.runningMean.map((v) => v.toStringAsFixed(4)).join(', ')}]\nRunning variance: [${a.runningVariance.map((v) => v.toStringAsFixed(4)).join(', ')}]',
            style: const TextStyle(height: 1.8),
          ),
          _gap,
          const Text(
            'BatchNorm forward train variance denominator N; running variance update-এ unbiased N−1 estimate। Momentum .1: new=.9×old+.1×batch_stat। একটি Batch-এর Running Statistics-কে Population-এর Calibrated Estimate হিসেবে ধরা যায় না। no_grad() একা train-mode BN-এর running updates বন্ধ করে না।',
            style: _bn,
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                key: const Key('normalization-eval'),
                onPressed: () => setState(() => mode = 'batch_eval'),
                child: const Text('Inspect eval statistics'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  mode = 'batch_train';
                  row = 0;
                }),
                child: const Text('Reset normalization'),
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

class ResumeLab extends StatefulWidget {
  const ResumeLab({super.key});
  @override
  State<ResumeLab> createState() => _ResumeLabState();
}

class _ResumeLabState extends State<ResumeLab> {
  final data = ReliableAssets.load();
  bool weightsOnly = false;
  int epoch = 40;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final continuous = a.continuous[epoch],
        branch = (weightsOnly ? a.weightsOnly : a.resumed)[epoch];
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'DEEP LEARNING & RL · CHAPTER 03 · CHECKPOINT AUDIT',
            icon: Icons.restore_outlined,
          ),
          _gap,
          const Text('Resume the state, not just the weights.', style: _title),
          _gap,
          const Text(
            'Actual 40-epoch mini-batch AdamW run epoch20-এ save/load করা হয়েছে। Full branch model, optimizer, scheduler, dropout RNG ও shuffle generator restore করে। Weights-only branch একই RNG/order পায়, কিন্তু optimizer/scheduler reset করে—state loss-এর controlled illustration, candidate ranking নয়।',
            style: _bn,
          ),
          _gap,
          SwitchListTile(
            key: const Key('resume-weights-only'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Reset optimizer/scheduler (weights only)'),
            value: weightsOnly,
            onChanged: (v) => setState(() => weightsOnly = v),
          ),
          _gap,
          DropdownButtonFormField<int>(
            key: ValueKey('resume-epoch-$epoch'),
            initialValue: epoch,
            decoration: const InputDecoration(
              labelText: 'Recorded boundary / endpoint',
            ),
            items: [
              for (final n in [0, 20, 21, 40])
                DropdownMenuItem(value: n, child: Text('Epoch $n')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => epoch = v);
            },
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Tag(
                weightsOnly
                    ? 'Restore: weights only'
                    : 'Restore: complete state',
              ),
              Tag('Epoch: $epoch / 40'),
              Tag('Next LR: ${branch.nextLr.toStringAsFixed(4)}'),
            ],
          ),
          _gap,
          Text(
            'Uninterrupted train BCE: ${continuous.train.toStringAsFixed(8)}\nBranch train BCE: ${branch.train.toStringAsFixed(8)}\nUninterrupted validation BCE: ${continuous.validation.toStringAsFixed(8)}\nBranch validation BCE: ${branch.validation.toStringAsFixed(8)}\nValidation difference: ${(branch.validation - continuous.validation).toStringAsExponential(3)}',
            style: const TextStyle(height: 2),
          ),
          _gap,
          Text(
            weightsOnly
                ? 'Endpoint parameter difference: ${a.weightsOnlyError.toStringAsExponential(4)}'
                : 'Endpoint parameter difference: 0 (exact local match)',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          _gap,
          const Text(
            'Endpoint-এ Parameter-এর পার্থক্য Epoch 40-এর সংরক্ষিত Audit থেকে এসেছে। Selected Epoch-এর Parameter Distance এখানে দেখানো হয়নি। Exact match এই same-version CPU environment ও epoch boundary-এর evidence। Mid-epoch cursor, multi-worker queues, CUDA/MPS/AMP বা cross-version identity এখানে যাচাই হয়নি।',
            style: _bn,
          ),
          _gap,
          const Text(
            'Checkpoint contract\n✓ copied model state + buffers\n✓ optimizer moments / steps / groups\n✓ scheduler epoch + next learning rate\n✓ CPU dropout RNG + shuffle generator\n✓ completed epoch, history, recipe\n✓ feature order, split rows, scaler, source hash',
            style: TextStyle(height: 2),
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                key: const Key('resume-warm'),
                onPressed: () => setState(() {
                  weightsOnly = true;
                  epoch = 40;
                }),
                child: const Text('Inspect weights-only restart'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  weightsOnly = false;
                  epoch = 40;
                }),
                child: const Text('Reset resume'),
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
