import 'dart:convert';

import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import 'reliability_model.dart';

const _gap = SizedBox(height: 16),
    _bn = TextStyle(fontFamily: 'NotoSansBengali', height: 1.8),
    _title = TextStyle(fontSize: 24, fontWeight: FontWeight.w800);
Widget _asset(
  Future<ReliabilityAssets> f,
  Widget Function(ReliabilityAssets) body,
) => FutureBuilder<ReliabilityAssets>(
  future: f,
  builder: (c, s) {
    if (s.hasError) {
      return const Panel(
        child: Text('Bundled reliability evidence could not be read.'),
      );
    }
    if (!s.hasData) {
      return const Center(child: CircularProgressIndicator());
    }
    return body(s.data!);
  },
);
Widget _source() => const Text(
  'Chapter 25-এর frozen tiny models · বাস্তব SciFact-এর 188টি annotated dev query, যা আগে দেখা হয়েছে। Claims/annotations: CC BY 4.0; source notices bundled। Labels source evidence থেকে এসেছে, কিন্তু model input-এ evidence নেই। এই diagnostic generative LLM factuality, medical verification বা fresh blind evaluation নয়। Serving replay-তে assumed costs ব্যবহৃত, measured latency নয়।',
  style: _bn,
);
Widget _models(String model, void Function(String) change, String name) =>
    DropdownButtonFormField<String>(
      key: ValueKey('$name-$model'),
      initialValue: model,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Frozen model variant'),
      items: [
        for (final m in ['base', 'full', 'lora'])
          DropdownMenuItem(value: m, child: Text(m.toUpperCase())),
      ],
      onChanged: (v) {
        if (v != null) change(v);
      },
    );
String _n(dynamic x) => x == null ? 'undefined' : (x as num).toStringAsFixed(6);

class EvaluationScoreLab extends StatefulWidget {
  const EvaluationScoreLab({super.key});
  @override
  State<EvaluationScoreLab> createState() => _EvaluationScoreLabState();
}

class _EvaluationScoreLabState extends State<EvaluationScoreLab> {
  final data = ReliabilityAssets.load();
  String model = 'lora';
  bool longOnly = false;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final rows = a.variants[model]!
            .where((r) => !longOnly || utf8.encode(r.text).length > 80)
            .toList(),
        r = reliabilityAudit(rows);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'LLMS & GENAI · CHAPTER 05 · EVALUATION SCORECARD',
            icon: Icons.analytics_outlined,
          ),
          _gap,
          const Text('Choose the task. Audit the failures.', style: _title),
          _gap,
          const Text(
            'Accuracy, confusion matrix, Brier ও confidence-bin ECE এক জিনিস নয়। SUPPORT positive label; p = 0.5 হলে SUPPORT বেছে নিই। Full/LoRA majority prediction baseline ছাড়ায়নি। Conditional S/C probability কোনো claim-এর truth confidence নয়। Slice বদলালে denominator বদলায়; model নতুন করে train হয় না।',
            style: _bn,
          ),
          _gap,
          _models(model, (v) => setState(() => model = v), 'score'),
          _gap,
          Tag(longOnly ? 'Slice: long claims' : 'Slice: all claims'),
          _gap,
          Text(
            'Queries: ${rows.length} · accuracy ${_n(r['accuracy'])}',
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
          _gap,
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              Text('TP ${r['tp']}'),
              Text('TN ${r['tn']}'),
              Text('FP ${r['fp']}'),
              Text('FN ${r['fn']}'),
            ],
          ),
          _gap,
          Text('SUPPORT recall: ${_n(r['support_recall'])}'),
          Text('CONTRADICT recall: ${_n(r['contradict_recall'])}'),
          Text('SUPPORT precision: ${_n(r['precision'])}'),
          Text('Brier: ${_n(r['brier'])}'),
          Text('Binary NLL: ${_n(r['binary_nll_clipped'])}'),
          Text('Confidence-bin ECE: ${_n(r['ece'])}'),
          _gap,
          const Text(
            'Fixed 5 equal-width bins over [0,1]; confidence = max(p,1-p)। Upper boundary পরের bin-এ যায়; 1 শেষ bin-এ থাকে। Empty bin undefined, perfect calibration নয়। Brier-এ calibration ও discrimination দুটির প্রভাব থাকে; ছোট ECE একা reliability-এর প্রমাণ নয়।',
            style: _bn,
          ),
          _gap,
          for (final b in r['bins'])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Bin ${b['index']} · n${b['count']} · accuracy ${_n(b['accuracy'])} · confidence ${_n(b['mean_confidence'])}',
              ),
            ),
          _gap,
          Wrap(
            spacing: 12,
            children: [
              OutlinedButton(
                key: const Key('reliability-slice'),
                onPressed: () => setState(() => longOnly = !longOnly),
                child: const Text('Inspect long-claim slice'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  model = 'lora';
                  longOnly = false;
                }),
                child: const Text('Reset scorecard'),
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

class SelectiveRiskLab extends StatefulWidget {
  const SelectiveRiskLab({super.key});
  @override
  State<SelectiveRiskLab> createState() => _SelectiveRiskLabState();
}

class _SelectiveRiskLabState extends State<SelectiveRiskLab> {
  final data = ReliabilityAssets.load();
  String model = 'lora';
  double threshold = .5;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final r = selectiveAudit(a.variants[model]!, threshold);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'LLMS & GENAI · CHAPTER 05 · SELECTIVE RISK',
            icon: Icons.filter_alt_outlined,
          ),
          _gap,
          const Text('Abstain with a denominator.', style: _title),
          _gap,
          const Text(
            'Confidence ≥ threshold হলে prediction রাখি; অন্যথায় abstain করি। Coverage = accepted/all; conditional risk = errors/accepted। Accepted 0 হলে accuracy/risk undefined; তাকে zero error বা perfect reliability বলা যায় না। এটি observed dev-এর diagnostic sweep; threshold selection বা unanswerable detection নয়।',
            style: _bn,
          ),
          _gap,
          _models(model, (v) => setState(() => model = v), 'risk'),
          _gap,
          Tag('Threshold: ${threshold.toStringAsFixed(2)}'),
          _gap,
          Slider(
            key: const Key('reliability-threshold'),
            value: threshold,
            min: .5,
            max: 1,
            divisions: 10,
            onChanged: (v) => setState(() => threshold = v),
          ),
          Text('Accepted: ${r['accepted']} / 188 · correct ${r['correct']}'),
          Text(
            'Coverage: ${_n(r['coverage'])}',
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
          ),
          Text('Conditional accuracy: ${_n(r['accuracy'])}'),
          Text('Conditional risk: ${_n(r['risk'])}'),
          _gap,
          LinearProgressIndicator(
            value: (r['coverage'] as num).toDouble(),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          _gap,
          Wrap(
            spacing: 12,
            children: [
              OutlinedButton(
                key: const Key('reliability-strict'),
                onPressed: () => setState(() => threshold = 1),
                child: const Text('Inspect threshold 1.00'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  model = 'lora';
                  threshold = .5;
                }),
                child: const Text('Reset selective audit'),
              ),
            ],
          ),
          _gap,
          const Text(
            'Higher threshold-এ coverage কমে, কিন্তু accepted-set error সবসময় কমবে এমন guarantee নেই। ভালো confidence rule যাচাই করতে আলাদা selection/calibration protocol ও fresh confirmation দরকার। Labels, group dependence ও slice coverage বিবেচনা করুন; এখানে scientific truth estimate হচ্ছে না।',
            style: _bn,
          ),
          _gap,
          _source(),
        ],
      ),
    );
  });
}

class ServingReplayLab extends StatefulWidget {
  const ServingReplayLab({super.key});
  @override
  State<ServingReplayLab> createState() => _ServingReplayLabState();
}

class _ServingReplayLabState extends State<ServingReplayLab> {
  final data = ReliabilityAssets.load();
  int batch = 1;
  bool changedScope = false;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final r = servingReplay(a.requests, batchSize: batch),
        q = a.variants['lora']!.first.text,
        old = reliabilityCacheKey(
          q,
          'model-v1',
          'corpus-v1',
          'prompt-v1',
          'scope-a',
          'greedy',
        ),
        current = reliabilityCacheKey(
          q,
          'model-v1',
          'corpus-v1',
          'prompt-v1',
          changedScope ? 'scope-b' : 'scope-a',
          'greedy',
        ),
        cache = {old: 'original source response'};
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag('LLMS & GENAI · CHAPTER 05 · SERVING REPLAY', icon: Icons.speed_outlined),
          _gap,
          const Text('Separate queueing from compute.', style: _title),
          _gap,
          const Text(
            'First 40 actual source requests supply input lengths and one output label token। Assumptions: arrivals every 5 ms, prefill 0.4 ms/input token, decode 1.2 ms/output token, overhead 2 ms/batch। One worker; consecutive fixed groups wait for the last arrival; ideal padded batch cost। No network/GPU timing or continuous batching/PagedAttention implementation।',
            style: _bn,
          ),
          _gap,
          Tag('Batch size: $batch'),
          _gap,
          Text(
            'Simulated p50: ${_n(r['p50_ms'])} ms',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          Text('Simulated p95: ${_n(r['p95_ms'])} ms'),
          Text('Mean simulated TTFT: ${_n(r['mean_ttft_ms'])} ms'),
          Text(
            'Simulated throughput: ${_n(r['throughput_per_second'])} requests/s',
          ),
          _gap,
          for (final row in (r['rows'] as List).take(4))
            Text(
              'Query ${row['id']}:arrival ${_n(row['arrival_ms'])},queue ${_n(row['queue_ms'])},finish ${_n(row['finish_ms'])}ms',
            ),
          _gap,
          Wrap(
            spacing: 12,
            children: [
              OutlinedButton(
                key: const Key('reliability-batch'),
                onPressed: () => setState(
                  () => batch = batch == 1
                      ? 4
                      : batch == 4
                      ? 8
                      : 1,
                ),
                child: const Text('Compare batch 1 / 4 / 8'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  batch = 1;
                  changedScope = false;
                }),
                child: const Text('Reset serving replay'),
              ),
            ],
          ),
          _gap,
          const Divider(),
          _gap,
          const Text(
            'Version/scope-aware exact cache-key demonstration',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          _gap,
          Tag(changedScope ? 'Cache: miss' : 'Cache: hit'),
          _gap,
          SelectableText(current),
          _gap,
          Text(
            cache[current] == null
                ? 'No cached response in the changed scope.'
                : 'Exact key matches this in-memory demonstration entry.',
          ),
          _gap,
          OutlinedButton(
            key: const Key('reliability-scope'),
            onPressed: () => setState(() => changedScope = !changedScope),
            child: const Text('Change permission scope'),
          ),
          _gap,
          const Text(
            'Key fields: query, model, corpus, prompt, permission scope, decoding। এটি local key-equality demonstration; authorization enforcement, persistent response cache বা KV reuse নয়। Prefix KV caching কিছু prefill কাজ বাঁচাতে পারে; পুরো answer cache করে না এবং decode কাজ বাদ দেয় না।',
            style: _bn,
          ),
          _gap,
          _source(),
        ],
      ),
    );
  });
}
