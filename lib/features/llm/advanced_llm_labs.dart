import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import 'llm_model.dart';

double passAtK({
  required int samples,
  required int correct,
  required int picks,
}) {
  if (samples < 1 ||
      correct < 0 ||
      correct > samples ||
      picks < 1 ||
      picks > samples) {
    throw const FormatException('Invalid pass@k counts');
  }
  if (picks > samples - correct) return 1;
  var allWrong = 1.0;
  for (var draw = 0; draw < picks; draw++) {
    allWrong *= (samples - correct - draw) / (samples - draw);
  }
  return 1 - allWrong;
}

class PassAtKLab extends StatefulWidget {
  const PassAtKLab({super.key});

  @override
  State<PassAtKLab> createState() => _PassAtKLabState();
}

class _PassAtKLabState extends State<PassAtKLab> {
  int correct = 2;
  int picks = 2;

  @override
  Widget build(BuildContext context) {
    const samples = 5;
    final score = passAtK(samples: samples, correct: correct, picks: picks);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'পরীক্ষা করুন: pass@k',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Text(
            '৫টি নির্দিষ্ট output থেকে replacement ছাড়া kটি বাছুন। অন্তত একটি correct পাওয়ার কতটা সুযোগ আছে?',
          ),
          const SizedBox(height: 12),
          Text('Correct outputs: $correct / $samples'),
          Slider(
            value: correct.toDouble(),
            max: samples.toDouble(),
            divisions: samples,
            label: '$correct',
            semanticFormatterCallback: (value) => 'Correct: ${value.round()}',
            onChanged: (value) => setState(() => correct = value.round()),
          ),
          Text('Draws: $picks'),
          Slider(
            value: picks.toDouble(),
            min: 1,
            max: samples.toDouble(),
            divisions: samples - 1,
            label: '$picks',
            semanticFormatterCallback: (value) => 'Draws: ${value.round()}',
            onChanged: (value) => setState(() => picks = value.round()),
          ),
          Text(
            'pass@$picks = ${score.toStringAsFixed(3)}',
            semanticsLabel: 'pass at $picks: ${score.toStringAsFixed(3)}',
          ),
          const SizedBox(height: 8),
          const Text(
            'এটি হিসাবের fixture। নতুন code model চালানো হয়নি; retry budget বাড়ালে score-এর সঙ্গে cost-ও দেখুন।',
          ),
        ],
      ),
    );
  }
}

enum PatchTrial { receiver, patch, reference, reverse }

class ActivationPatchLab extends StatefulWidget {
  const ActivationPatchLab({super.key});

  @override
  State<ActivationPatchLab> createState() => _ActivationPatchLabState();
}

class _ActivationPatchLabState extends State<ActivationPatchLab> {
  late final Future<LLMAssets> assets = LLMAssets.load();
  PatchTrial trial = PatchTrial.receiver;

  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'পরীক্ষা করুন: FFN activation patch',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const Text(
          'Alice-এর দুটি source prefix। Residual একই রেখে শেষ position-এর FFN update বদলালে H ও d-এর logit gap কী হয়?',
        ),
        const SizedBox(height: 12),
        FutureBuilder<LLMAssets>(
          future: assets,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Text('Bundled decoder খোলা যায়নি।');
            }
            final data = snapshot.data;
            if (data == null) return const LinearProgressIndicator();
            final reference = data.samples[0];
            final receiver = data.samples[1];
            final useRefResidual =
                trial == PatchTrial.reference || trial == PatchTrial.reverse;
            final useRefUpdate =
                trial == PatchTrial.reference || trial == PatchTrial.patch;
            final residualSource = useRefResidual ? reference : receiver;
            final updateSource = useRefUpdate ? reference : receiver;
            final residual = data.model
                .run(residualSource.ids)
                .matrices['residual1']!
                .last;
            final update = data.model
                .run(updateSource.ids)
                .matrices['ff_output']!
                .last;
            final gap = data.model.lastTokenLogitGap(
              residual: residual,
              ffnUpdate: update,
              target: reference.targets.last,
              contrast: receiver.targets.last,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final (value, label) in const [
                      (PatchTrial.receiver, 'Receiver baseline'),
                      (PatchTrial.patch, 'Patch receiver'),
                      (PatchTrial.reference, 'Reference baseline'),
                      (PatchTrial.reverse, 'Reverse patch'),
                    ])
                      ChoiceChip(
                        label: Text(label),
                        selected: trial == value,
                        onSelected: (_) => setState(() => trial = value),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Residual: source ${residualSource.sourceChapter} · FFN: source ${updateSource.sourceChapter}',
                ),
                Text('Logit gap H − d: ${gap.toStringAsFixed(6)}'),
                const SizedBox(height: 8),
                const Text(
                  'দুটি prefix একই দৈর্ঘ্যের, কিন্তু matched minimal pair নয়। ফল এই model, position ও intervention-এর জন্য।',
                ),
              ],
            );
          },
        ),
      ],
    ),
  );
}
