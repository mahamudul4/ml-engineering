import 'dart:convert';

import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import '../rag/rag_model.dart';
import 'gen_capstone_model.dart';

const _gap = SizedBox(height: 16),
    _bn = TextStyle(fontFamily: 'NotoSansBengali', height: 1.8),
    _title = TextStyle(fontSize: 24, fontWeight: FontWeight.w800);
const _source = Text(
  'বাস্তব SciFact · Wadden et al.2020 / BEIR snapshot। Claims/annotations CC BY4.0; abstracts ODC-By1.0; notices bundled। Already observed505 fit/188 annotated diagnostic claims; fresh blind test নয়। Tiny task-specific decoder বড় LLM, free-form answer generator বা scientific verifier নয়। Exact source quotes entailment বা medical advice প্রমাণ করে না।',
  style: _bn,
);
String _n(dynamic x) => x == null ? 'undefined' : (x as num).toStringAsFixed(4);
Widget _asset(
  Future<GenCapstoneAssets> f,
  Widget Function(GenCapstoneAssets) body,
) => FutureBuilder<GenCapstoneAssets>(
  future: f,
  builder: (c, s) {
    if (s.hasError) {
      return const Panel(
        child: Text('Bundled capstone evidence could not be read.'),
      );
    }
    if (!s.hasData) {
      return const Center(child: CircularProgressIndicator());
    }
    return body(s.data!);
  },
);

class EvidenceWorkbench extends StatefulWidget {
  const EvidenceWorkbench({super.key});
  @override
  State<EvidenceWorkbench> createState() => _EvidenceWorkbenchState();
}

class _EvidenceWorkbenchState extends State<EvidenceWorkbench> {
  final data = GenCapstoneAssets.load(), query = TextEditingController();
  bool initialized = false;
  String current = '';
  int budget = 1024, selected = 3;
  RAGRun? cached;
  String? queryError;
  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    if (!initialized) {
      current = a.samples[3]['text'];
      query.text = current;
      initialized = true;
    }
    final run = cached ??= a.rag.system.run(current, budget: budget);
    final text = run.pack.selected.map((q) => q.text).join('\n');
    final generation = a.generate(capstoneFeatures(current, text));
    final exact = run.pack.selected.every(
      (q) => ragAuditQuote(q, a.rag.system.source)['exact_quote']!,
    );
    final decision = capstoneDecision(
      hasContext: !run.pack.abstained,
      quotesExact: exact,
      formatValid: generation.formatValid,
      confidence: generation.confidence,
    );
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'LLMS & GENAI · CHAPTER 10 · EVIDENCE WORKBENCH',
            icon: Icons.account_tree_outlined,
          ),
          _gap,
          const Text(
            'Retrieve. Generate a hypothesis. Check the source.',
            style: _title,
          ),
          _gap,
          const Text(
            'Full corpus-এ lexical retrieval ও exact quote packing হয়। Small GRU source text-এর hashed features নিয়ে letter-by-letter support/contradict response-word generate করে। Model hypothesis সঠিক verdict নয়; quotes থেকে নিজের evidence audit করুন। Input English source task; Bangla interface multilingual capability প্রমাণ নয়।',
            style: _bn,
          ),
          _gap,
          DropdownButtonFormField<int>(
            key: ValueKey('case-$selected'),
            initialValue: selected,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Original source case',
            ),
            items: [
              for (var i = 0; i < a.samples.length; i++)
                DropdownMenuItem(
                  value: i,
                  child: Text(
                    'Claim ${a.samples[i]['id']} · ${a.samples[i]['role']} role',
                  ),
                ),
            ],
            onChanged: (v) {
              if (v != null) {
                setState(() {
                  selected = v;
                  query.text = a.samples[v]['text'];
                  current = query.text;
                  cached = null;
                  queryError = null;
                });
              }
            },
          ),
          _gap,
          TextField(
            key: const Key('capstone-query'),
            controller: query,
            maxLines: 3,
            maxLength: 4096,
            decoration: InputDecoration(
              labelText: 'Claim / retrieval query',
              helperText: 'Full offline corpus · 5183 documents',
              errorText: queryError,
            ),
          ),
          _gap,
          FilledButton(
            onPressed: () => setState(() {
              if (query.text.length > 4096) {
                queryError = 'Query exceeds 4096 UTF16 units. Shorten it.';
                return;
              }
              queryError = null;
              current = query.text;
              cached = null;
            }),
            child: const Text('Run offline pipeline'),
          ),
          _gap,
          Tag('Context budget: $budget bytes'),
          _gap,
          Text(
            'Retrieved documents: ${run.retrieved.length} · selected passages: ${run.pack.selected.length}',
          ),
          Text('Packed UTF8 bytes: ${run.pack.usedBytes}'),
          _gap,
          Tag('Policy: $decision'),
          _gap,
          if (decision == 'unverified_hypothesis')
            Text(
              'Unverified model hypothesis: ${generation.text}',
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            )
          else
            const Text(
              'No hypothesis released under the current runtime gate.',
              style: _bn,
            ),
          _gap,
          Text(
            'Raw decoder: ${generation.text} · EOS ${generation.ended} · valid format ${generation.formatValid}',
          ),
          Text(
            'First-token max probability: ${_n(generation.confidence)} (uncalibrated)',
          ),
          Text('Generated tokens: ${generation.ids.length} / 12'),
          _gap,
          ExpansionTile(
            title: const Text('Inspect actual autoregressive trace'),
            children: [
              for (final step in generation.trace)
                ListTile(
                  dense: true,
                  title: Text(
                    '${a.vocabulary[step.previous]} → ${a.vocabulary[step.chosen]}',
                  ),
                  subtitle: Text(
                    'Chosen probability ${_n(step.probabilities[step.chosen])}',
                  ),
                ),
            ],
          ),
          _gap,
          const Text(
            'Exact source context · not a verified answer',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          _gap,
          SelectableText(
            run.pack.context.isEmpty
                ? 'No packed source context.'
                : run.pack.context,
            style: _bn,
          ),
          _gap,
          FilledButton.tonal(
            key: const Key('capstone-budget'),
            onPressed: () => setState(() {
              budget = budget == 1024 ? 0 : 1024;
              cached = null;
            }),
            child: const Text('Switch 1024 / 0 byte budget'),
          ),
          _gap,
          TextButton(
            onPressed: () => setState(() {
              budget = 1024;
              queryError = null;
              selected = 3;
              query.text = a.samples[3]['text'];
              current = query.text;
              cached = null;
            }),
            child: const Text('Reset evidence workbench'),
          ),
          _gap,
          _source,
        ],
      ),
    );
  });
}

class CapstoneScorecard extends StatefulWidget {
  const CapstoneScorecard({super.key});
  @override
  State<CapstoneScorecard> createState() => _CapstoneScorecardState();
}

class _CapstoneScorecardState extends State<CapstoneScorecard> {
  final data = GenCapstoneAssets.load();
  String mode = 'retrieved';
  double threshold = 0;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final rows = a.data['variants'][mode]['rows'] as List;
    final score = capstoneScore(rows, threshold: threshold);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'LLMS & GENAI · CHAPTER 10 · PAIRED DIAGNOSTICS',
            icon: Icons.analytics_outlined,
          ),
          _gap,
          const Text(
            'Score each stage. Keep the failed controls.',
            style: _title,
          ),
          _gap,
          const Text(
            'একই188 observed claims,একই frozen decoder। Query-only context block শূন্য করে; rotated-context next claim-এর retrieved context দেয়। এগুলো separately trained baselines বা causal proof নয়। Rationale/joint counts original retrieval pack-এর; decoder control input-এর entailment score নয়।',
            style: _bn,
          ),
          _gap,
          DropdownButtonFormField<String>(
            key: ValueKey('variant-$mode'),
            initialValue: mode,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Frozen input control',
            ),
            items: [
              for (final m in ['retrieved', 'query_only', 'rotated_context'])
                DropdownMenuItem(value: m, child: Text(m)),
            ],
            onChanged: (v) {
              if (v != null) setState(() => mode = v);
            },
          ),
          _gap,
          Tag('Confidence threshold: ${threshold.toStringAsFixed(2)}'),
          _gap,
          Wrap(
            spacing: 20,
            runSpacing: 12,
            children: [
              Text('Claims: ${score['n']}'),
              Text('Valid format: ${score['valid']}'),
              Text('Correct words: ${score['correct']}'),
              Text('Accuracy: ${_n(score['accuracy'])}'),
              Text(
                'Complete rationale hits: ${score['complete_rationale_hits']}',
              ),
              Text('Joint label + rationale hits: ${score['joint_hits']}'),
            ],
          ),
          _gap,
          Text(
            'Majority diagnostic accuracy: ${_n(a.report['majority_accuracy'])}',
          ),
          Text(
            'Emitted: ${score['accepted']} / ${score['n']} · coverage ${_n(score['coverage'])}',
          ),
          Text(
            'Accepted accuracy: ${_n(score['accepted_accuracy'])} · risk ${_n(score['accepted_risk'])}',
          ),
          _gap,
          const Text(
            'First-token max confidence sequence correctness বা truth probability নয়। Threshold0/.90/1 exploratory controls; diagnostic থেকে production threshold বাছা হয়নি। Empty accepted set-এর accuracy/risk undefined। Quote fidelity, generated label correctness ও complete rationale hit আলাদা metrics।',
            style: _bn,
          ),
          _gap,
          FilledButton.tonal(
            key: const Key('capstone-strict'),
            onPressed: () => setState(() => threshold = .9),
            child: const Text('Inspect threshold 0.90'),
          ),
          _gap,
          OutlinedButton(
            key: const Key('capstone-empty'),
            onPressed: () => setState(() => threshold = 1),
            child: const Text('Inspect threshold 1.00'),
          ),
          _gap,
          TextButton(
            onPressed: () => setState(() {
              threshold = 0;
              mode = 'retrieved';
            }),
            child: const Text('Reset capstone scorecard'),
          ),
          _gap,
          _source,
        ],
      ),
    );
  });
}

class CapstoneReleaseAudit extends StatefulWidget {
  const CapstoneReleaseAudit({super.key});
  @override
  State<CapstoneReleaseAudit> createState() => _CapstoneReleaseAuditState();
}

class _CapstoneReleaseAuditState extends State<CapstoneReleaseAudit> {
  final data = GenCapstoneAssets.load();
  bool tampered = false, manifest = false;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final sample = a.samples[3], j = sample['cases']['retrieved'];
    final c = j['pack']['selected'][0];
    final original = RAGChunk(c['doc_id'], c['start'], c['end'], c['text']);
    final quote = RAGChunk(
      original.docId,
      original.start,
      original.end,
      tampered ? '${original.text} [edited]' : original.text,
    );
    final audit = ragAuditQuote(quote, a.rag.system.source);
    final gen = a.generate(GenCapstoneAssets.vector(j['features']));
    final decision = capstoneDecision(
      hasContext: true,
      quotesExact: audit['exact_quote']!,
      formatValid: gen.formatValid,
      confidence: gen.confidence,
    );
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'LLMS & GENAI · CHAPTER 10 · RELEASE AUDIT',
            icon: Icons.fact_check_outlined,
          ),
          _gap,
          const Text(
            'Pin the contract. Reject altered evidence.',
            style: _title,
          ),
          _gap,
          const Text(
            'একটি actual source span-এর text বদলে runtime provenance gate পরীক্ষা করি। Citation ID resolve হওয়া এবং exact quote থাকা আলাদা checks। Model word ঠিক দেখালেও altered quote release হয় না। Exact quote gate semantic entailment বা prompt-injection defense নয়।',
            style: _bn,
          ),
          _gap,
          Tag(tampered ? 'Quote integrity: changed' : 'Quote integrity: exact'),
          _gap,
          Text(
            'Citation: ${quote.citation} · resolvable ${audit['resolvable']}',
          ),
          Text('Exact source match: ${audit['exact_quote']}'),
          Text('Runtime gate: $decision'),
          _gap,
          SelectableText(quote.text, style: _bn),
          _gap,
          FilledButton.tonal(
            key: const Key('capstone-tamper'),
            onPressed: () => setState(() => tampered = !tampered),
            child: const Text('Change / restore quote text'),
          ),
          _gap,
          const Text(
            'Artifact contract',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          _gap,
          SelectableText(
            'Corpus SHA256: ${a.report['source_sha256']}\nIndex SHA256: ${a.report['index_sha256']}\nCanonical weights SHA256: ${a.report['weights_sha256']}',
            style: const TextStyle(fontSize: 12),
          ),
          _gap,
          const Text(
            'Fingerprints pinned by Python source verification/release byte checks। UI displays recorded hashes; it does not recompute a file checksum here। Canonical weights hash excludes optimizer/runtime state। Reproduction metadata is not full training resume or security attestation।',
            style: _bn,
          ),
          _gap,
          FilledButton.tonal(
            key: const Key('capstone-manifest'),
            onPressed: () => setState(() => manifest = !manifest),
            child: const Text('Show / hide model card'),
          ),
          Text(manifest ? 'Model card: visible' : 'Model card: hidden'),
          if (manifest) ...[
            _gap,
            SelectableText(
              const JsonEncoder.withIndent('  ').convert(a.report),
              style: const TextStyle(fontSize: 12),
            ),
          ],
          _gap,
          TextButton(
            onPressed: () => setState(() {
              tampered = false;
              manifest = false;
            }),
            child: const Text('Reset release audit'),
          ),
          _gap,
          _source,
        ],
      ),
    );
  });
}
