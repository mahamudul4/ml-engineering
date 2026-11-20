import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import 'retrieval_model.dart';

const _gap = SizedBox(height: 16);
const _bn = TextStyle(fontFamily: 'NotoSansBengali', height: 1.8);
const _heading = TextStyle(fontSize: 24, fontWeight: FontWeight.w800);
Widget _asset(
  Future<RetrievalAssets> future,
  Widget Function(RetrievalAssets) body,
) => FutureBuilder<RetrievalAssets>(
  future: future,
  builder: (context, snapshot) {
    if (snapshot.hasError) {
      return const Panel(
        child: Text(
          'Bundled retrieval index could not be read. Reopen the lab.',
        ),
      );
    }
    if (!snapshot.hasData) {
      return const Center(child: CircularProgressIndicator());
    }
    return body(snapshot.data!);
  },
);
Widget _source() => const Text(
  'SciFact · Wadden et al. (2020), BEIR distribution · 5,183 original documents। Claims/annotations: CC BY 4.0; abstract database: ODC-By 1.0। Source, attribution ও notices bundled। Claim text ভুল হতে পারে; retrieved evidence মানেই claim সমর্থিত নয়। English corpus; Bangla teaching ভাষা। LSA একটি corpus-fitted linear baseline, pretrained neural semantic encoder নয়।',
  style: _bn,
);
String _method(String name) => {
  'tfidf': 'TF-IDF cosine',
  'lsa': 'LSA cosine · 32D',
  'hybrid': 'Hybrid RRF',
}[name]!;
Widget _samples(
  RetrievalAssets a,
  int selected,
  void Function(int) change,
  String name,
) => DropdownButtonFormField<int>(
  key: ValueKey('$name-$selected'),
  initialValue: selected,
  isExpanded: true,
  decoration: const InputDecoration(labelText: 'Original SciFact query'),
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
Widget _methods(String selected, void Function(String) change, String name) =>
    DropdownButtonFormField<String>(
      key: ValueKey('$name-$selected'),
      initialValue: selected,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Retrieval method'),
      items: [
        for (final m in retrievalMethods)
          DropdownMenuItem(value: m, child: Text(_method(m))),
      ],
      onChanged: (v) {
        if (v != null) change(v);
      },
    );
Widget _metricCards(Map<String, double> values, int k) => Wrap(
  spacing: 16,
  runSpacing: 12,
  children: [
    for (final name in ['recall', 'mrr', 'ndcg'])
      SizedBox(
        width: 130,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${{'recall': 'Recall', 'mrr': 'MRR', 'ndcg': 'nDCG'}[name]}@$k',
            ),
            const SizedBox(height: 6),
            Text(
              values[name]!.toStringAsFixed(4),
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
  ],
);

class EmbeddingGeometryLab extends StatefulWidget {
  const EmbeddingGeometryLab({super.key});
  @override
  State<EmbeddingGeometryLab> createState() => _EmbeddingGeometryLabState();
}

class _EmbeddingGeometryLabState extends State<EmbeddingGeometryLab> {
  final data = RetrievalAssets.load();
  int sample = 0;
  double scale = 1;
  bool cosine = true;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final query = a.samples[sample];
    final encoded = a.index.encode(query.text);
    final doc = a.index.byId[query.relevant.first]!;
    final scaled = encoded.raw.map((v) => v * scale).toList();
    final score = cosine
        ? retrievalCosine(scaled, doc.dense)
        : retrievalDot(scaled, doc.dense);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'LLMS & GENAI · CHAPTER 02 · EMBEDDING GEOMETRY',
            icon: Icons.scatter_plot_outlined,
          ),
          _gap,
          const Text('Same direction. Different magnitude.', style: _heading),
          _gap,
          const Text(
            'বাস্তব source query → sublinear TF-IDF → 32D LSA projection। Selected document একটি judged relevant evidence document; তার stored vector unit length। Raw query vector scale করলে dot product বদলায়, cosine একই থাকে। Zero vector-এর angle সংজ্ঞায়িত নয়; retrieval convention-এ score 0।',
            style: _bn,
          ),
          _gap,
          _samples(a, sample, (v) => setState(() => sample = v), 'geometry'),
          _gap,
          SelectableText(query.text),
          _gap,
          Text('Matched vocabulary terms: ${encoded.indices.length} / 4096'),
          Text('Document ${doc.id}: ${doc.title}'),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Tag(cosine ? 'Metric: cosine' : 'Metric: dot'),
              Tag('Query scale: ${scale.toStringAsFixed(2)}'),
              const Tag('Projection: LSA · 32D'),
            ],
          ),
          _gap,
          Text('Query scale: ${scale.toStringAsFixed(2)}'),
          Slider(
            key: const Key('retrieval-scale'),
            value: scale,
            min: .5,
            max: 3,
            divisions: 10,
            onChanged: (v) => setState(() => scale = v),
          ),
          Text(
            'Similarity: ${score.toStringAsFixed(6)}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          _gap,
          const Text(
            'First 8 unit-query coordinates · signed values',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const Text(
            'Bars are coordinate inspection, not a semantic map or feature explanation.',
          ),
          _gap,
          for (var i = 0; i < 8; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(width: 30, child: Text('d${i + 1}')),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: ((encoded.unit[i] + 1) / 2).clamp(0, 1),
                      minHeight: 7,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 72,
                    child: Text(
                      encoded.unit[i].toStringAsFixed(5),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
          _gap,
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton(
                key: const Key('retrieval-dot'),
                onPressed: () => setState(() => cosine = !cosine),
                child: const Text('Compare dot / cosine'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  sample = 0;
                  scale = 1;
                  cosine = true;
                }),
                child: const Text('Reset geometry'),
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

class SemanticSearchLab extends StatefulWidget {
  const SemanticSearchLab({super.key});
  @override
  State<SemanticSearchLab> createState() => _SemanticSearchLabState();
}

class _SemanticSearchLabState extends State<SemanticSearchLab> {
  final data = RetrievalAssets.load(), text = TextEditingController();
  int sample = 0;
  String method = 'tfidf', executed = '';
  bool cellOnly = false, initialized = false;
  List<RetrievalHit> hits = [];
  void run(RetrievalAssets a) {
    executed = text.text;
    if (executed.length > 4096) {
      hits = [];
      return;
    }
    hits = a.index.search(
      executed,
      method: method,
      allowed: cellOnly
          ? {
              for (final d in a.index.documents)
                if (retrievalTokens(d.title).contains('cell')) d.id,
            }
          : null,
    );
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
    final judged = executed == a.samples[sample].text;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'LLMS & GENAI · CHAPTER 02 · EXACT RETRIEVAL',
            icon: Icons.manage_search_outlined,
          ),
          _gap,
          const Text(
            'Retrieve evidence. Inspect the ranking.',
            style: _heading,
          ),
          _gap,
          const Text(
            'সব 5,183 documents-এর উপর exact scan চলে। TF-IDF lexical overlap, LSA low-rank dense geometry, hybrid rank fusion দেখায়। এখানে neural model বা ANN index চলে না। Free query লিখতে পারেন; original query বদলালে তার source judgments আর প্রযোজ্য নয়। Unsupported English vocabulary বা Bangla-only query zero vector দিতে পারে।',
            style: _bn,
          ),
          _gap,
          _samples(
            a,
            sample,
            (v) => setState(() {
              sample = v;
              text.text = a.samples[v].text;
              run(a);
            }),
            'search',
          ),
          _gap,
          TextField(
            key: const Key('retrieval-query'),
            controller: text,
            maxLines: 3,
            maxLength: 512,
            decoration: const InputDecoration(
              labelText: 'Search text · press Search to run',
            ),
          ),
          _gap,
          _methods(
            method,
            (v) => setState(() {
              method = v;
              run(a);
            }),
            'search-method',
          ),
          _gap,
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            key: const Key('retrieval-filter'),
            title: const Text('Filter: title has token “cell”'),
            subtitle: const Text(
              'Applied before ranking; an example metadata rule, not authorization.',
            ),
            value: cellOnly,
            onChanged: (v) => setState(() {
              cellOnly = v;
              run(a);
            }),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Tag('Method: ${method.toUpperCase()}'),
              Tag(
                judged ? 'Judgments: source query' : 'Judgments: unavailable',
              ),
              Tag(cellOnly ? 'Filter: cell' : 'Filter: all'),
            ],
          ),
          _gap,
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton(
                key: const Key('retrieval-run'),
                onPressed: () => setState(() => run(a)),
                child: const Text('Search corpus'),
              ),
              OutlinedButton(
                key: const Key('retrieval-hybrid'),
                onPressed: () => setState(() {
                  method = 'hybrid';
                  run(a);
                }),
                child: const Text('Compare hybrid RRF'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  sample = 0;
                  method = 'tfidf';
                  cellOnly = false;
                  text.text = a.samples.first.text;
                  run(a);
                }),
                child: const Text('Reset search'),
              ),
            ],
          ),
          _gap,
          Text('Executed query: $executed'),
          _gap,
          if (executed.length > 4096)
            const Text('Use a query within 4096 UTF16 units.', style: _bn)
          else if (hits.isEmpty)
            const Text(
              'No candidates. Check vocabulary coverage or metadata filter.',
              style: _bn,
            ),
          for (var i = 0; i < math.min(5, hits.length); i++)
            Card(
              child: ExpansionTile(
                key: ValueKey('search-hit-$i-${hits[i].id}'),
                tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                title: Text(
                  '${i + 1}. ${a.index.byId[hits[i].id]!.title}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  'ID ${hits[i].id} · ${hits[i].score.toStringAsFixed(6)}${judged && a.samples[sample].relevant.contains(hits[i].id) ? ' · judged relevant' : ''}',
                ),
                childrenPadding: const EdgeInsets.all(16),
                children: [SelectableText(a.index.byId[hits[i].id]!.text)],
              ),
            ),
          _gap,
          const Text(
            'Top 5 displayed from a top-10 result. Cosine and RRF scores have different scales; neither is a relevance probability. RRF uses top100 candidates from each branch, 1-based ranks and constant60. Unjudged does not mean proven irrelevant.',
            style: _bn,
          ),
          _gap,
          _source(),
        ],
      ),
    );
  });
}

class RetrievalEvaluationLab extends StatefulWidget {
  const RetrievalEvaluationLab({super.key});
  @override
  State<RetrievalEvaluationLab> createState() => _RetrievalEvaluationLabState();
}

class _RetrievalEvaluationLabState extends State<RetrievalEvaluationLab> {
  final data = RetrievalAssets.load();
  int sample = 0, k = 10, depth = 100;
  String method = 'hybrid';
  List<RetrievalHit>? hits;
  void run(RetrievalAssets a) => hits = a.index.search(
    a.samples[sample].text,
    method: method,
    depth: depth,
  );
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    if (hits == null) run(a);
    final query = a.samples[sample];
    final values = retrievalMetrics(
      hits!.map((h) => h.id).toList(),
      query.relevant,
      k,
    );
    final role = a.report['evaluation'][query.role];
    final macro = Map<String, double>.from(
      (role['methods'][method]['$k'] as Map).map(
        (key, value) => MapEntry(key as String, (value as num).toDouble()),
      ),
    );
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'LLMS & GENAI · CHAPTER 02 · RETRIEVAL AUDIT',
            icon: Icons.fact_check_outlined,
          ),
          _gap,
          const Text('Measure the misses. Keep the baseline.', style: _heading),
          _gap,
          const Text(
            'Recall সব judged relevant documents-এর কত অংশ পাওয়া গেল বলে; MRR প্রথম hit-এর rank দেখে; nDCG rank discount দিয়ে সব hits মাপে। Binary source qrels ব্যবহার হচ্ছে। Unjudged documents metric-এ nonrelevant ধরা হয়েছে, কিন্তু judgments অসম্পূর্ণ হতে পারে। Relevant evidence একটি claim সমর্থনও করতে পারে, খণ্ডনও করতে পারে।',
            style: _bn,
          ),
          _gap,
          _samples(
            a,
            sample,
            (v) => setState(() {
              sample = v;
              run(a);
            }),
            'audit',
          ),
          _gap,
          SelectableText(query.text),
          _gap,
          _methods(
            method,
            (v) => setState(() {
              method = v;
              run(a);
            }),
            'audit-method',
          ),
          _gap,
          DropdownButtonFormField<int>(
            key: ValueKey('audit-k-$k'),
            initialValue: k,
            decoration: const InputDecoration(labelText: 'Evaluation cutoff'),
            items: [
              for (final n in [5, 10])
                DropdownMenuItem(value: n, child: Text('Top $n')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => k = v);
            },
          ),
          _gap,
          Tag('Candidate depth: $depth'),
          _gap,
          const Text(
            'Current query · live exact ranking',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          _gap,
          _metricCards(values, k),
          _gap,
          Text('Judged relevant IDs: ${query.relevant.join(', ')}'),
          Text('Returned IDs: ${hits!.take(k).map((h) => h.id).join(', ')}'),
          _gap,
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton(
                key: const Key('retrieval-shallow'),
                onPressed: () => setState(() {
                  method = 'hybrid';
                  depth = 5;
                  run(a);
                }),
                child: const Text('Inspect depth 5'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  sample = 0;
                  method = 'hybrid';
                  depth = 100;
                  k = 10;
                  run(a);
                }),
                child: const Text('Reset audit'),
              ),
            ],
          ),
          _gap,
          const Divider(),
          _gap,
          Text(
            'Bundled macro reference · BEIR ${query.role} · ${role['queries']} judged queries',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          _gap,
          _metricCards(macro, k),
          _gap,
          const Text(
            'Macro reference uses the fixed full recipe: depth100 for hybrid, no metadata filter. The shallow live query above does not change that stored dataset-level experiment. No parameter selection used these test results.',
            style: _bn,
          ),
          _gap,
          const Text(
            'Observed limitation: TF-IDF outperforms this 32D LSA baseline and its hybrid on the terminal BEIR test. Dense compression and rank fusion can lose exact scientific terms. Keep failed results; diagnose vocabulary, ranks and candidate coverage before changing a future recipe.',
            style: _bn,
          ),
          _gap,
          _source(),
        ],
      ),
    );
  });
}
