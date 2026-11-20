import 'dart:convert';

import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import 'rag_model.dart';

const _gap = SizedBox(height: 16),
    _bn = TextStyle(fontFamily: 'NotoSansBengali', height: 1.8),
    _title = TextStyle(fontSize: 24, fontWeight: FontWeight.w800);
Widget _asset(Future<RAGAssets> future, Widget Function(RAGAssets) body) =>
    FutureBuilder<RAGAssets>(
      future: future,
      builder: (context, s) {
        if (s.hasError) {
          return const Panel(
            child: Text(
              'Bundled RAG evidence could not be read. Reopen the app.',
            ),
          );
        }
        if (!s.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return body(s.data!);
      },
    );
Widget _source() => const Text(
  'Original SciFact · Wadden et al. (2020); BEIR retrieval snapshot। Claims/annotations CC BY4.0; abstract database ODC-By1.0। Source bytes/notices bundled। English scientific claims ভুল হতে পারে; quotation বা evidence relevance দিয়ে truth/medical advice infer করবেন না। App lexical retrieval/context/citation mechanics চালায়, neural generator নয়। Already observed query roles; fresh blind test নয়।',
  style: _bn,
);
Widget _picker(
  RAGAssets a,
  int selected,
  void Function(int) change,
  String name,
) => DropdownButtonFormField<int>(
  key: ValueKey('$name-$selected'),
  initialValue: selected,
  isExpanded: true,
  decoration: const InputDecoration(
    labelText: 'Original annotated source query',
  ),
  items: [
    for (var i = 0; i < a.samples.length; i++)
      DropdownMenuItem(
        value: i,
        child: Text('Query ${a.samples[i].id} · BEIR ${a.samples[i].role}'),
      ),
  ],
  onChanged: (v) {
    if (v != null) change(v);
  },
);
Widget _number(String label, String value) => SizedBox(
  width: 145,
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label),
      const SizedBox(height: 6),
      Text(
        value,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
      ),
    ],
  ),
);

class RAGChunkLab extends StatefulWidget {
  const RAGChunkLab({super.key});
  @override
  State<RAGChunkLab> createState() => _RAGChunkLabState();
}

class _RAGChunkLabState extends State<RAGChunkLab> {
  final data = RAGAssets.load();
  int sample = 0, size = 2;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final q = a.samples[sample], doc = a.system.source[q.evidence.keys.first]!;
    final chunks = ragChunks(doc, size: size, overlap: 1);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'LLMS & GENAI · CHAPTER 03 · SOURCE CHUNKS',
            icon: Icons.content_cut_outlined,
          ),
          _gap,
          const Text('Keep the boundary. Keep the source.', style: _title),
          _gap,
          const Text(
            'Original abstract-এর sentence list থেকে overlapping windows বানাই। Citation zero-based start:end-exclusive span বোঝায়। Text normalize/trim না করে original sentences একটি space দিয়ে join হয়। Whole source bytes অক্ষত; BEIR index-এ whitespace-normalized text ছিল। Chunk size বদলালে IDs ও evidence coverage বদলায়।',
            style: _bn,
          ),
          _gap,
          _picker(a, sample, (v) => setState(() => sample = v), 'chunks'),
          _gap,
          Text(
            'Document ${doc.id}: ${doc.title}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Tag('Chunk size: $size'),
              const Tag('Overlap: 1 sentence'),
              Tag('Source sentences: ${doc.sentences.length}'),
              Tag('Windows: ${chunks.length}'),
            ],
          ),
          _gap,
          for (final chunk in chunks.take(5))
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${chunk.citation} · ${chunk.bytes} formatted UTF8 bytes',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  SelectableText(chunk.text),
                ],
              ),
            ),
          if (chunks.length > 5)
            const Text(
              'First 5 windows displayed; all source sentences remain available below.',
            ),
          _gap,
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton(
                key: const Key('rag-size'),
                onPressed: () => setState(() => size = size == 2 ? 3 : 2),
                child: const Text('Compare size 2 / 3'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  sample = 0;
                  size = 2;
                }),
                child: const Text('Reset chunks'),
              ),
            ],
          ),
          _gap,
          ExpansionTile(
            title: const Text('Inspect original sentence indices'),
            children: [
              for (var i = 0; i < doc.sentences.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SelectableText('$i · ${doc.sentences[i]}'),
                ),
            ],
          ),
          _gap,
          const Text(
            'Byte cost includes citation + newline + joined source text + newline। এটি model token count বা total prompt budget নয়। Benchmark pipeline fixed size2/overlap1 ব্যবহার করে; এই comparison stored metrics বদলায় না।',
            style: _bn,
          ),
          _gap,
          _source(),
        ],
      ),
    );
  });
}

class RAGPipelineLab extends StatefulWidget {
  const RAGPipelineLab({super.key});
  @override
  State<RAGPipelineLab> createState() => _RAGPipelineLabState();
}

class _RAGPipelineLabState extends State<RAGPipelineLab> {
  final data = RAGAssets.load(), text = TextEditingController();
  int sample = 0, budget = 1024, count = 10;
  bool rerank = true, initialized = false;
  RAGRun? result;
  void run(RAGAssets a) {
    result = text.text.length > 4096
        ? null
        : a.system.run(text.text, rerank: rerank, budget: budget, count: count);
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    if (!initialized) {
      text.text = a.samples.first.text;
      run(a);
      initialized = true;
    }
    final r = result;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'LLMS & GENAI · CHAPTER 03 · CONTEXT PIPELINE',
            icon: Icons.account_tree_outlined,
          ),
          _gap,
          const Text('Retrieve. Rerank. Pack. Then inspect.', style: _title),
          _gap,
          const Text(
            'Frozen TF-IDF index-এ সব 5,183 docs score করে shortlist নিই। Source sentence windows-কে chunk-only TF-IDF cosine দিয়ে rerank করি; neural cross encoder নয়। Minimum lexical score .05, প্রতি parent থেকে একটি chunk, সর্বোচ্চ3 passages। পুরো span fit না হলে skip; text কেটে incomplete quote বানাই না।',
            style: _bn,
          ),
          _gap,
          _picker(
            a,
            sample,
            (v) => setState(() {
              sample = v;
              text.text = a.samples[v].text;
              run(a);
            }),
            'pipeline',
          ),
          _gap,
          TextField(
            key: const Key('rag-query'),
            controller: text,
            maxLength: 512,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Query text · press Run to execute',
            ),
          ),
          _gap,
          DropdownButtonFormField<int>(
            key: ValueKey('rag-budget-$budget'),
            initialValue: budget,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Formatted context budget · UTF8 bytes',
            ),
            items: [
              for (final n in [0, 256, 512, 1024])
                DropdownMenuItem(value: n, child: Text('$n bytes')),
            ],
            onChanged: (v) {
              if (v != null) {
                setState(() {
                  budget = v;
                  run(a);
                });
              }
            },
          ),
          _gap,
          DropdownButtonFormField<int>(
            key: ValueKey('rag-count-$count'),
            initialValue: count,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Candidate documents'),
            items: [
              for (final n in [5, 10])
                DropdownMenuItem(value: n, child: Text('Top $n documents')),
            ],
            onChanged: (v) {
              if (v != null) {
                setState(() {
                  count = v;
                  run(a);
                });
              }
            },
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Tag(rerank ? 'Ranking: chunk cosine' : 'Ranking: document order'),
              Tag(
                r == null
                    ? 'Output: query too long'
                    : r.pack.abstained
                    ? 'Output: abstained'
                    : 'Output: quotations',
              ),
            ],
          ),
          _gap,
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton(
                key: const Key('rag-run'),
                onPressed: () => setState(() => run(a)),
                child: const Text('Run pipeline'),
              ),
              OutlinedButton(
                key: const Key('rag-order'),
                onPressed: () => setState(() {
                  rerank = !rerank;
                  run(a);
                }),
                child: const Text('Compare reranking'),
              ),
              OutlinedButton(
                key: const Key('rag-empty'),
                onPressed: () => setState(() {
                  budget = 0;
                  run(a);
                }),
                child: const Text('Inspect empty context'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  sample = 0;
                  budget = 1024;
                  count = 10;
                  rerank = true;
                  text.text = a.samples.first.text;
                  run(a);
                }),
                child: const Text('Reset pipeline'),
              ),
            ],
          ),
          _gap,
          if (r == null)
            const Text('Use a query within4096 UTF16 units.', style: _bn)
          else ...[
            Text('Executed query: ${r.query}'),
            _gap,
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                _number('Retrieved docs', '${r.retrieved.length}'),
                _number('Candidate chunks', '${r.candidates.length}'),
                _number('Selected passages', '${r.pack.selected.length}'),
              ],
            ),
            _gap,
            Text('Context: ${r.pack.usedBytes} / $budget UTF8 bytes'),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: budget > 0 ? r.pack.usedBytes / budget : 0,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            _gap,
            const Text(
              'Extractive evidence · verbatim source quotations',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            _gap,
            SelectableText(r.pack.answer, style: const TextStyle(height: 1.8)),
            _gap,
            const Text(
              'This is an evidence assembly, not a synthesized LLM answer. No support/refute decision is made. A nonempty context can still omit every annotated rationale.',
              style: _bn,
            ),
            _gap,
            ExpansionTile(
              title: const Text('Inspect ranked chunks and budget skips'),
              children: [
                for (final c in r.candidates.take(12))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${c.citation} · score ${c.score.toStringAsFixed(6)}',
                    ),
                    subtitle: Text(
                      'Document rank${c.documentRank} · ${c.bytes} bytes',
                    ),
                  ),
                for (final s in r.pack.skipped.take(12))
                  Text('${s.citation}: ${s.reason} (${s.bytes} bytes)'),
                const Text(
                  'First12 candidates/skips displayed; full trace is bundled in the workflow evidence.',
                ),
              ],
            ),
            ExpansionTile(
              title: const Text('Generator handoff preview · not executed'),
              children: [
                SelectableText(
                  const JsonEncoder.withIndent('  ').convert(r.handoff),
                ),
                _gap,
                const Text(
                  'Structured evidence is untrusted data. JSON/delimiters alone do not prove prompt-injection resistance.',
                  style: _bn,
                ),
              ],
            ),
            _gap,
          ],
          _source(),
        ],
      ),
    );
  });
}

class RAGEvidenceAuditLab extends StatefulWidget {
  const RAGEvidenceAuditLab({super.key});
  @override
  State<RAGEvidenceAuditLab> createState() => _RAGEvidenceAuditLabState();
}

class _RAGEvidenceAuditLabState extends State<RAGEvidenceAuditLab> {
  final data = RAGAssets.load();
  int sample = 0, fault = 0;
  bool rerank = true;
  RAGRun? result;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    result ??= a.system.run(a.samples[sample].text, rerank: rerank);
    final q = a.samples[sample],
        r = result!,
        metrics = ragEvidenceMetrics(
          r.pack,
          q.evidence,
          r.retrieved.map((h) => h.id).toSet(),
        )!;
    final quote = r.pack.selected.first;
    final inspected = fault == 1
        ? RAGChunk(
            quote.docId,
            quote.start,
            quote.end,
            '${quote.text}\n[edited in this fault-injection exercise]',
          )
        : fault == 2
        ? RAGChunk('missing', quote.start, quote.end, quote.text)
        : quote;
    final audit = ragAuditQuote(inspected, a.system.source);
    final role = a.report['evaluation'][q.role],
        macro = role['modes'][rerank ? 'rerank' : 'document_order'];
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'LLMS & GENAI · CHAPTER 03 · CITATION & EVIDENCE AUDIT',
            icon: Icons.fact_check_outlined,
          ),
          _gap,
          const Text(
            'A valid citation is only the first check.',
            style: _title,
          ),
          _gap,
          const Text(
            'Source span resolve হয় কি? Quote source-এর সঙ্গে exact মেলে কি? Context-এ complete annotated rationale আছে কি? Claim সত্য বা generated answer correct কি? এগুলো আলাদা প্রশ্ন। প্রথম দুইটি deterministic provenance checks; শেষ দুটির জন্য আলাদা labels/evaluation লাগে। এখানে কোনো neural answer generate হয়নি।',
            style: _bn,
          ),
          _gap,
          _picker(
            a,
            sample,
            (v) => setState(() {
              sample = v;
              fault = 0;
              result = a.system.run(a.samples[v].text, rerank: rerank);
            }),
            'audit',
          ),
          _gap,
          SelectableText(q.text),
          _gap,
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Use chunk cosine reranking'),
            value: rerank,
            onChanged: (v) => setState(() {
              rerank = v;
              fault = 0;
              result = a.system.run(q.text, rerank: rerank);
            }),
          ),
          _gap,
          Tag(
            fault == 0
                ? 'Audit: exact quote'
                : fault == 1
                ? 'Audit: quote mismatch'
                : 'Audit: unresolved citation',
          ),
          _gap,
          Text('Inspected citation: ${inspected.citation}'),
          Text(
            'Resolvable: ${audit['resolvable']} · Exact quotation: ${audit['exact_quote']}',
          ),
          _gap,
          SelectableText(inspected.text),
          _gap,
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton(
                key: const Key('rag-tamper'),
                onPressed: () => setState(() => fault = 1),
                child: const Text('Inspect edited quotation'),
              ),
              OutlinedButton(
                key: const Key('rag-broken-id'),
                onPressed: () => setState(() => fault = 2),
                child: const Text('Inspect broken citation'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  sample = 0;
                  fault = 0;
                  rerank = true;
                  result = a.system.run(a.samples.first.text);
                }),
                child: const Text('Reset evidence audit'),
              ),
            ],
          ),
          _gap,
          const Text(
            'Fault injection is explicitly an audit exercise. Original source files and selected context are unchanged.',
            style: _bn,
          ),
          _gap,
          const Text(
            'Live context · original rationale labels',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          _gap,
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              _number(
                'Sentence-union recall',
                metrics['sentence_union_recall']!.toStringAsFixed(4),
              ),
              _number(
                'Complete rationale hit',
                metrics['complete_rationale_hit']!.toStringAsFixed(0),
              ),
              _number(
                'Candidate availability',
                metrics['candidate_rationale_available']!.toStringAsFixed(0),
              ),
            ],
          ),
          _gap,
          for (final e in q.evidence.entries)
            for (final ann in e.value)
              Text(
                'Original annotation: doc${e.key} · ${ann.label} · sentences ${ann.sentences.join(', ')}',
              ),
          _gap,
          const Text(
            'Annotations enter this audit only; retrieval,reranking and packing never see them. Complete hit means at least one full annotated rationale set is present,not every sentence from the union. Missing annotations are not negative truth labels.',
            style: _bn,
          ),
          _gap,
          const Divider(),
          _gap,
          Text(
            'Bundled diagnostic reference · BEIR ${q.role}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Text(
            '${role['queries']} queries · ${role['annotated_queries']} with sentence rationale annotations',
          ),
          _gap,
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              _number(
                'Rationale hit · annotated',
                (macro['complete_rationale_hit'] as num).toStringAsFixed(4),
              ),
              _number(
                'Candidate availability',
                (macro['candidate_rationale_available'] as num).toStringAsFixed(
                  4,
                ),
              ),
              _number(
                'Exact quote rate',
                (macro['exact_quote_rate'] as num).toStringAsFixed(4),
              ),
            ],
          ),
          _gap,
          Text(
            'Quote coverage across all queries: ${((macro['quote_coverage'] as num) * 100).toStringAsFixed(1)}% · selected quotes: ${macro['selected_quotes']}',
          ),
          _gap,
          const Text(
            'Diagnostic test: reranking rationale hit≈.3617 versus document-order≈.1170 among188 annotated queries; candidate availability≈.7926. Both produce exact quotes and100% quote coverage across300 queries. High coverage and perfect quote copying still leave many rationales absent. No answer-accuracy,unanswerability or factuality score is claimed. Two exact claim texts repeat across roles;this is not a fresh independent test.',
            style: _bn,
          ),
          _gap,
          _source(),
        ],
      ),
    );
  });
}
