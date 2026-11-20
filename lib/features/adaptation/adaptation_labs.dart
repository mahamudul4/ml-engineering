import 'dart:convert';

import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import 'adaptation_model.dart';

const _gap = SizedBox(height: 16),
    _bn = TextStyle(fontFamily: 'NotoSansBengali', height: 1.8),
    _title = TextStyle(fontSize: 24, fontWeight: FontWeight.w800);
Widget _asset(
  Future<AdaptationAssets> f,
  Widget Function(AdaptationAssets) body,
) => FutureBuilder<AdaptationAssets>(
  future: f,
  builder: (c, s) {
    if (s.hasError) {
      return const Panel(
        child: Text('Bundled adaptation evidence could not be read.'),
      );
    }
    if (!s.hasData) {
      return const Center(child: CircularProgressIndicator());
    }
    return body(s.data!);
  },
);
Widget _source() => const Text(
  'Real SciFact labels/source notices bundled · CC BY4.0 claims/annotations; ODC-By1.0 abstract database। Base: Chapter22 Alice decoder5019 parameters,not a large pretrained LLM। First24 claim bytes only,no evidence text; this is not fact verification,chat or instruction following। Diagnostic roles already observed;no fresh blind test। Python fitting local;app Dart forward।',
  style: _bn,
);
Widget _picker(
  AdaptationAssets a,
  int index,
  void Function(int) change,
  String name,
) => DropdownButtonFormField<int>(
  key: ValueKey('$name-$index'),
  initialValue: index,
  isExpanded: true,
  decoration: const InputDecoration(labelText: 'Original annotated claim'),
  items: [
    for (var i = 0; i < a.samples.length; i++)
      DropdownMenuItem(
        value: i,
        child: Text('Query ${a.samples[i].id} · ${a.samples[i].role}'),
      ),
  ],
  onChanged: (v) {
    if (v != null) change(v);
  },
);

class ResponseMaskLab extends StatefulWidget {
  const ResponseMaskLab({super.key});
  @override
  State<ResponseMaskLab> createState() => _ResponseMaskLabState();
}

class _ResponseMaskLabState extends State<ResponseMaskLab> {
  final data = AdaptationAssets.load();
  int sample = 0;
  bool full = false;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final s = a.samples[sample],
        mode = full ? 'full' : 'base',
        trace = a.models[mode]!.run(s.ids),
        logits = trace.matrices['logits']!.last,
        target = s.label == 'SUPPORT' ? 83 : 67;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'LLMS & GENAI · CHAPTER 04 · RESPONSE-ONLY OBJECTIVE',
            icon: Icons.rule_outlined,
          ),
          _gap,
          const Text('Mask the prompt. Score the response.', style: _title),
          _gap,
          const Text(
            'Actual claim-এরfirst24 UTF8 bytes+BOS+newline input। Single next-byte response S বা C supervised; prompt token losses বাদ। No evidence passage input,so prediction scientific verification নয়। Source label response input-এরভিতরে দেওয়া হয়নি। Classifier selects only S/C;NLL uses all257 legal output classes।',
            style: _bn,
          ),
          _gap,
          _picker(a, sample, (v) => setState(() => sample = v), 'mask'),
          _gap,
          SelectableText(s.text),
          _gap,
          Text('Actual source label: ${s.label}'),
          Text('Input IDs: ${s.ids.join(', ')}'),
          Text(
            'Byte prefix display: ${utf8.decode(s.ids.where((id) => id < 256).toList(), allowMalformed: true)}',
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Tag(full ? 'Model: full' : 'Model: base'),
              const Tag('Supervised positions: 1'),
              Tag('Prompt positions ignored: ${s.ids.length - 1}'),
            ],
          ),
          _gap,
          Text(
            'Raw response NLL: ${responseNLL(logits, target).toStringAsFixed(6)}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          Text(
            'P(S | S or C): ${supportProbability(logits).toStringAsFixed(6)}',
          ),
          _gap,
          const Text(
            'Restricted verbalizer probability is not calibrated truth confidence. Prompt and PAD losses must not dilute the valid-response denominator. Teacher-forced loss improvement does not imply instruction competence.',
            style: _bn,
          ),
          _gap,
          Wrap(
            spacing: 12,
            children: [
              OutlinedButton(
                key: const Key('adapt-full'),
                onPressed: () => setState(() => full = !full),
                child: const Text('Compare full update'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  sample = 0;
                  full = false;
                }),
                child: const Text('Reset response mask'),
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

class LoRAUpdateLab extends StatefulWidget {
  const LoRAUpdateLab({super.key});
  @override
  State<LoRAUpdateLab> createState() => _LoRAUpdateLabState();
}

class _LoRAUpdateLabState extends State<LoRAUpdateLab> {
  final data = AdaptationAssets.load();
  int sample = 0;
  double scale = 1;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final s = a.samples[sample],
        model = a.scaledAdapter(scale),
        logits = model.run(s.ids).matrices['logits']!.last,
        p = supportProbability(logits);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'LLMS & GENAI · CHAPTER 04 · LOW-RANK UPDATE',
            icon: Icons.layers_outlined,
          ),
          _gap,
          const Text('Freeze the base. Inspect the update.', style: _title),
          _gap,
          const Text(
            'Actual trained output-head adapter: A[2,8],B[259,2],alpha/r=1। Wmerged=Wbase+BA;534 trainable parameters versus5019 full-update parameters। Other weights/bias frozen for LoRA। Scale slider is inference ablation,not retraining or a selected optimum। Rank and alpha are different knobs।',
            style: _bn,
          ),
          _gap,
          _picker(a, sample, (v) => setState(() => sample = v), 'lora'),
          _gap,
          SelectableText(s.text),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              const Tag('Adapter rank: 2'),
              const Tag('Trainable: 534'),
              Tag('Adapter scale: ${scale.toStringAsFixed(1)}'),
            ],
          ),
          _gap,
          Slider(
            key: const Key('adapt-scale'),
            value: scale,
            min: 0,
            max: 2,
            divisions: 20,
            onChanged: (v) => setState(() => scale = v),
          ),
          Text(
            'P(S | S or C): ${p.toStringAsFixed(6)}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          Text('Restricted prediction: ${p >= .5 ? 'SUPPORT' : 'CONTRADICT'}'),
          _gap,
          const Text(
            'Scale0 recovers the base;scale1 matches the merged trained head. Unmerged and merged forwards are checked against Python. An adapter needs its exact compatible base/tokenizer;matching dimensions alone is insufficient. Trainable-count reduction is not a measured peak-memory or latency result.',
            style: _bn,
          ),
          _gap,
          Wrap(
            spacing: 12,
            children: [
              OutlinedButton(
                key: const Key('adapt-zero'),
                onPressed: () => setState(() => scale = 0),
                child: const Text('Inspect base only'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  sample = 0;
                  scale = 1;
                }),
                child: const Text('Reset adapter'),
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

class AdaptationAuditLab extends StatefulWidget {
  const AdaptationAuditLab({super.key});
  @override
  State<AdaptationAuditLab> createState() => _AdaptationAuditLabState();
}

class _AdaptationAuditLabState extends State<AdaptationAuditLab> {
  final data = AdaptationAssets.load();
  int sample = 0;
  bool quant = false;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final s = a.samples[sample],
        mode = quant ? 'int8_head_demo' : 'lora',
        logits = a.models[mode]!.run(s.ids).matrices['logits']!.last;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'LLMS & GENAI · CHAPTER 04 · ADAPTATION AUDIT',
            icon: Icons.fact_check_outlined,
          ),
          _gap,
          const Text('Lower loss. Check the baseline.', style: _title),
          _gap,
          const Text(
            'Fixed12-epoch full update ওhead-only LoRA run train loss কমিয়েছে,কিন্তুসব188 diagnostic queries-এSUPPORT predict করেছে। Accuracy124/188≈.659574,the same as the train-majority baseline। Learned task discrimination বাfact verification claim নয়। Class balance,prediction counts ওbaseline inspect করুন।',
            style: _bn,
          ),
          _gap,
          for (final name in ['base', 'full', 'lora']) ...[
            Text(
              '${name.toUpperCase()} · diagnostic accuracy ${(a.report['runs'][name]['diagnostic']['accuracy'] as num).toStringAsFixed(6)}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              'NLL ${(a.report['runs'][name]['diagnostic']['response_nll'] as num).toStringAsFixed(6)} · S predictions ${a.report['runs'][name]['diagnostic']['support_predictions']} · C predictions ${a.report['runs'][name]['diagnostic']['contradict_predictions']}',
            ),
            _gap,
          ],
          _picker(a, sample, (v) => setState(() => sample = v), 'quant'),
          _gap,
          Tag(quant ? 'Head: int8 round-trip' : 'Head: float64'),
          _gap,
          Text(
            'Sample P(S | S/C): ${supportProbability(logits).toStringAsFixed(6)}',
          ),
          _gap,
          const Text(
            'Quantization control: trained merged head rowwise symmetric int8 round/dequant,then float64 forward. Codes2072 bytes+float64 scales2072 bytes versus original head16576 bytes. Other layers,JSON packaging,activations andruntime overhead excluded. This is not QLoRA,NF4 or a native int8 speed benchmark.',
            style: _bn,
          ),
          _gap,
          Wrap(
            spacing: 12,
            children: [
              OutlinedButton(
                key: const Key('adapt-quant'),
                onPressed: () => setState(() => quant = !quant),
                child: const Text('Inspect int8 round-trip'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  sample = 0;
                  quant = false;
                }),
                child: const Text('Reset adaptation audit'),
              ),
            ],
          ),
          _gap,
          const Text(
            'Real labels:505 annotated train/188 dev queries;full-text overlap exclusion checks remove0 annotated train rows. Other unannotated role texts repeat;shared documents/related claims and identical24-byte prefixes can remain. Dev is already observed anddiagnostic only;no new seed/rank/epoch search or retuning.',
            style: _bn,
          ),
          _gap,
          _source(),
        ],
      ),
    );
  });
}
