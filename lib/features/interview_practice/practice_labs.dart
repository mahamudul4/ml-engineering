import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';

import '../../ui/theme.dart';
import 'practice_model.dart';

const _gap = SizedBox(height: 16);
const _body = TextStyle(fontFamily: 'NotoSansBengali', height: 1.8);
const _heading = TextStyle(fontSize: 24, fontWeight: FontWeight.w800);
String _n(num? n) => n == null ? 'undefined' : n.toStringAsFixed(6);
const _source = Text(
  'Real MovieLens/GroupLens fit-only ratings ও UCI Spambase development predictions; original notices/licenses bundled। No new holdout scoring। Algorithm counts, JOIN/metric bugs ও practice prompts authored; production timing বা observed hiring outcome নয়।',
  style: _body,
);

Widget _choices<T>(
  String name,
  Iterable<T> options,
  T selected,
  ValueChanged<T> change,
) => Wrap(
  spacing: 10,
  runSpacing: 8,
  children: [
    for (final v in options)
      ChoiceChip(
        key: Key('$name-$v'),
        label: Text('$v'),
        selected: v == selected,
        onSelected: (_) => change(v),
      ),
  ],
);
Widget _assets(
  Future<PracticeAssets> data,
  Widget Function(PracticeAssets) body,
) => FutureBuilder<PracticeAssets>(
  future: data,
  builder: (context, s) => s.hasError
      ? const Panel(
          child: Text('Bundled interview evidence could not be loaded.'),
        )
      : s.hasData
      ? body(s.data!)
      : const Center(child: CircularProgressIndicator()),
);

class TopKPracticeLab extends StatefulWidget {
  const TopKPracticeLab({super.key});
  @override
  State<TopKPracticeLab> createState() => _TopKPracticeLabState();
}

class _TopKPracticeLabState extends State<TopKPracticeLab> {
  final data = PracticeAssets.load();
  int k = 10, minimum = 10;
  String method = 'heap';
  @override
  Widget build(BuildContext context) => _assets(data, (a) {
    final result = practiceTopK(
      a.catalog,
      k: k,
      minimum: minimum,
      method: method,
    );
    final lookup = {for (final row in a.catalog) row['id']: row};
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag('ML SYSTEMS & INTERVIEWS · CHAPTER 05 · DSA & DETERMINISTIC TOP-K', icon: Icons.sort),
          _gap,
          const Text('State the invariant. Then select.', style: _heading),
          _gap,
          const Text(
            'Frozen MovieLens fit snapshot: 80,668 ratings, 522 users, 7,867 movies। Minimum support দিয়ে eligible items filter করুন; mean rating descending, 12-decimal quantized tie, movie ID ascending। এটি interview algorithm task; personalized quality বা popularity bias সমাধান নয়।',
            style: _body,
          ),
          _gap,
          const Text('Selection method'),
          _choices(
            'topk-method',
            ['heap', 'merge'],
            method,
            (v) => setState(() => method = v),
          ),
          _gap,
          const Text('Minimum fit ratings per movie'),
          _choices(
            'topk-min',
            [1, 10, 50],
            minimum,
            (v) => setState(() => minimum = v),
          ),
          _gap,
          const Text('Return K movies'),
          _choices('topk-k', [5, 10, 20], k, (v) => setState(() => k = v)),
          _gap,
          Text(
            'Eligible movies: ${result['eligible']}\nRanking comparisons: ${result['comparisons']}\nSelection buffer slots: ${result['selection_slots']}\nReturned items: ${(result['ids'] as List).length}',
            style: _body,
          ),
          _gap,
          LinearProgressIndicator(
            value:
                (result['selection_slots'] as int) /
                (result['eligible'] as int),
          ),
          _gap,
          Text(
            method == 'heap'
                ? 'Invariant: root হলো retained items-এর worst। Better candidate root replace করে; শেষে retained K items sort হয়। O(n log K + K log K), selection buffer O(K)।'
                : 'Merge দুই sorted half-এর best head নেয়। Full eligible list sort করে first K রাখা হয়। O(n log n), auxiliary selection buffer O(n)।',
            style: _body,
          ),
          _gap,
          const Text(
            'Measured counts শুধু এই authored comparator calls; filter, allocation, stack, input/output ও runtime overhead বাদ। Small K-এ কম comparisons হলেও wall-clock speedup দাবি নয়।',
            style: _body,
          ),
          _gap,
          for (var j = 0; j < (result['ids'] as List).length; j++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${j + 1}. ${lookup[result['ids'][j]]!['title']}\nMovie ${result['ids'][j]} · n=${lookup[result['ids'][j]]!['n']} · mean ${_n((lookup[result['ids'][j]]!['total'] as num) / (lookup[result['ids'][j]]!['n'] as num))}',
                style: _body,
              ),
            ),
          _gap,
          OutlinedButton(
            onPressed: () => setState(() {
              k = 10;
              minimum = 10;
              method = 'heap';
            }),
            child: const Text('Reset Top-K practice'),
          ),
          _gap,
          _source,
        ],
      ),
    );
  });
}

class SqlInterviewLab extends StatefulWidget {
  const SqlInterviewLab({super.key});
  @override
  State<SqlInterviewLab> createState() => _SqlInterviewLabState();
}

class _SqlInterviewLabState extends State<SqlInterviewLab> {
  late final Future<PracticeSqlStore> store;
  late Future<List<Map<String, Object?>>> result;
  String task = 'summary', variant = 'fixed', genre = 'All';
  int minimum = 10, k = 10;
  PracticeSqlPlan get plan => practiceSqlPlan(
    task: task,
    variant: variant,
    genre: genre,
    minimum: minimum,
    k: k,
  );
  @override
  void initState() {
    super.initState();
    store = PracticeAssets.load().then((a) => PracticeSqlStore.open(a));
    result = store.then((s) => s.query(plan));
  }

  void refresh() {
    final request = plan;
    setState(() {
      result = store.then((s) => s.query(request));
    });
  }

  @override
  void dispose() {
    unawaited(store.then((s) => s.close()).catchError((Object _) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Tag(
          'ML SYSTEMS & INTERVIEWS · CHAPTER 05 · ACTUAL SQLITE QUERY',
          icon: Icons.table_chart_outlined,
        ),
        _gap,
        const Text('Declare the grain. Inspect the join.', style: _heading),
        _gap,
        const Text(
          'Original fit ratings-এর immutable relational snapshot-এ actual SQLite SELECT চলে। movies, ratings ও movie_genres tables; rating grain=(user_id,movie_id)। Learner notes/progress database এখানে খোলা হয় না। Controls fixed query templates বেছে নেয়; arbitrary SQL editor নয়।',
          style: _body,
        ),
        _gap,
        DropdownButtonFormField<String>(
          key: ValueKey('sql-task-$task'),
          initialValue: task,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Interview task'),
          items: const [
            DropdownMenuItem(
              value: 'summary',
              child: Text('Aggregate at rating grain'),
            ),
            DropdownMenuItem(
              value: 'top_movies',
              child: Text('Top movies with HAVING'),
            ),
            DropdownMenuItem(
              value: 'latest_user',
              child: Text('Latest rating per user'),
            ),
          ],
          onChanged: (v) {
            task = v!;
            refresh();
          },
        ),
        _gap,
        const Text('Query implementation'),
        _choices('sql-variant', ['fixed', 'fanout'], variant, (v) {
          variant = v;
          refresh();
        }),
        _gap,
        const Text('Genre scope before aggregation/window'),
        _choices('sql-genre', ['All', 'Comedy', 'Drama', 'Action'], genre, (v) {
          genre = v;
          refresh();
        }),
        _gap,
        if (task == 'top_movies') ...[
          const Text('HAVING minimum rating count'),
          _choices('sql-min', [1, 10, 50], minimum, (v) {
            minimum = v;
            refresh();
          }),
          _gap,
        ],
        if (task != 'summary') ...[
          const Text('LIMIT rows'),
          _choices('sql-k', [5, 10, 20], k, (v) {
            k = v;
            refresh();
          }),
          _gap,
        ],
        Text(
          variant == 'fixed'
              ? 'EXISTS filters genre membership without multiplying rating rows। All scope empty-genre movies-ও রাখে।'
              : 'Authored fanout bug: one rating × each genre। All scope-এ count বাড়ে, global mean reweighted হয় এবং empty-genre items বাদ পড়ে। Single genre filter-এ এই particular multiplicity নাও থাকতে পারে।',
          style: _body,
        ),
        _gap,
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: HighlightView(
            plan.sql
                .replaceAll(' SELECT ', '\nSELECT ')
                .replaceAll(' FROM ', '\nFROM ')
                .replaceAll(' GROUP BY ', '\nGROUP BY ')
                .replaceAll(' ORDER BY ', '\nORDER BY '),
            language: 'sql',
            theme: atomOneDarkTheme,
            padding: const EdgeInsets.all(16),
            textStyle: const TextStyle(
              fontFamily: 'JetBrainsMono',
              fontFamilyFallback: ['NotoSansBengali'],
              fontSize: 12,
              height: 1.6,
            ),
          ),
        ),
        _gap,
        Text('Bound parameters: ${plan.parameters}', style: _body),
        _gap,
        FutureBuilder<List<Map<String, Object?>>>(
          future: result,
          builder: (context, s) {
            if (s.hasError) {
              return const Text(
                'SQLite practice query could not run. Reopen the lab to retry.',
                style: _body,
              );
            }
            if (s.connectionState != ConnectionState.done || !s.hasData) {
              return const Text('Running local SQLite query…', style: _body);
            }
            final rows = s.data!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SQLite returned ${rows.length} rows', style: _body),
                if (task == 'summary' && rows.isNotEmpty)
                  Text(
                    'Ratings counted: ${rows.first['n']}\nDistinct users: ${rows.first['users']} · movies: ${rows.first['movies']}\nMean rating: ${_n(rows.first['mean'] as num?)}',
                    style: _body,
                  ),
                if (task != 'summary' && rows.isNotEmpty)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: [
                        for (final key in rows.first.keys)
                          DataColumn(label: Text(key)),
                      ],
                      rows: [
                        for (final row in rows)
                          DataRow(
                            cells: [
                              for (final value in row.values)
                                DataCell(
                                  Text(value is double ? _n(value) : '$value'),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                if (rows.isEmpty)
                  const Text(
                    'No rows satisfy this query; empty result is valid.',
                    style: _body,
                  ),
              ],
            );
          },
        ),
        _gap,
        const Text(
          'ROW_NUMBER partitions user_id; ties use ts DESC, movie_id DESC। Genre scope আগে filter হয়, তাই latest within selected genre। COUNT(DISTINCT user_id) ঠিক থাকলেও rating grain ঠিক হয়েছে প্রমাণ নয়। DISTINCT rating দিয়ে repair করলে আলাদা events-এর equal numeric values-ও মুছে যাবে। Query results empirical historical counts; latency benchmark নয়।',
          style: _body,
        ),
        _gap,
        OutlinedButton(
          onPressed: () {
            task = 'summary';
            variant = 'fixed';
            genre = 'All';
            minimum = 10;
            k = 10;
            refresh();
          },
          child: const Text('Reset SQL practice'),
        ),
        _gap,
        _source,
      ],
    ),
  );
}

class MetricDebugLab extends StatefulWidget {
  const MetricDebugLab({super.key});
  @override
  State<MetricDebugLab> createState() => _MetricDebugLabState();
}

class _MetricDebugLabState extends State<MetricDebugLab> {
  final data = PracticeAssets.load();
  double threshold = .5;
  String bug = 'none';
  int cost = 10;
  @override
  Widget build(BuildContext context) => _assets(data, (a) {
    final r = practiceMetrics(
          a.diagnostics,
          threshold: threshold,
          bug: bug,
          fpCost: cost,
        ),
        correct = practiceMetrics(
          a.diagnostics,
          threshold: threshold,
          fpCost: cost,
        );
    final pass =
        r['tp'] == correct['tp'] &&
        r['fp'] == correct['fp'] &&
        r['reported_precision'] == correct['precision'];
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'ML SYSTEMS & INTERVIEWS · CHAPTER 05 · ML CODING & DEBUGGING',
            icon: Icons.bug_report_outlined,
          ),
          _gap,
          const Text('Find the violated contract.', style: _heading),
          _gap,
          const Text(
            'Real738 Spambase development rows-এর features ও frozen train-only model থেকে logits/probabilities Dart-এ recompute হয়। No fitting or reserved680 scoring। Bugs explicitly authored fixtures: precision denominator বদলানো, অথবা probability threshold সরাসরি logit-এ প্রয়োগ করা।',
            style: _body,
          ),
          _gap,
          const Text('Probability threshold'),
          _choices(
            'debug-threshold',
            [.2, .5, .8],
            threshold,
            (v) => setState(() => threshold = v),
          ),
          _gap,
          const Text('Injected implementation'),
          _choices(
            'debug-bug',
            ['none', 'precision_swap', 'logit_threshold'],
            bug,
            (v) => setState(() => bug = v),
          ),
          _gap,
          const Text('False-positive symbolic cost'),
          _choices(
            'debug-cost',
            [1, 10, 100],
            cost,
            (v) => setState(() => cost = v),
          ),
          _gap,
          Text(
            'Contract check: ${pass ? 'PASS' : 'FAIL'}\nTP ${r['tp']} · FP ${r['fp']} · TN ${r['tn']} · FN ${r['fn']}\nReported precision: ${_n(r['reported_precision'])}\nActual precision for these decisions: ${_n(r['precision'])}\nRecall: ${_n(r['recall'])}\nAccuracy: ${_n(r['accuracy'])}\nSymbolic cost: ${r['symbolic_cost']}\nStable mean BCE: ${_n(r['bce'])}',
            style: _body,
          ),
          _gap,
          Text(
            'Expected at probability threshold $threshold: TP ${correct['tp']} · FP ${correct['fp']} · TN ${correct['tn']} · FN ${correct['fn']}\nExpected precision: ${_n(correct['precision'])}',
            style: _body,
          ),
          _gap,
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: HighlightView(
              bug == 'precision_swap'
                  ? '# BUG: recall is mislabeled as precision\nreported_precision = tp / (tp + fn)\n# FIX\nprecision = tp / (tp + fp) if tp + fp else None'
                  : bug == 'logit_threshold'
                  ? '# BUG: probability threshold on raw logits\npred = logit >= threshold\n# FIX: sigmoid first, or equivalent logit threshold\npred = sigmoid(logit) >= threshold'
                  : '# Correct contract\npred = sigmoid(logit) >= threshold\nprecision = tp / (tp + fp) if tp + fp else None\nloss = max(z, 0) - z*y + log1p(exp(-abs(z)))',
              language: 'python',
              theme: atomOneDarkTheme,
              padding: const EdgeInsets.all(16),
              textStyle: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontFamilyFallback: ['NotoSansBengali'],
                fontSize: 12,
                height: 1.6,
              ),
            ),
          ),
          _gap,
          const Text(
            'At probability 0.5, equivalent logit threshold = 0 — not 0.5। BCE fixed scores/labels-এর loss, তাই decision threshold বা reporting bug বদলালেও BCE বদলায় না। Cost proxy = FP × weight + FN; no calibration/current-domain utility claim। Failing fixture explain করা practice, automated interview grade নয়।',
            style: _body,
          ),
          _gap,
          OutlinedButton(
            onPressed: () => setState(() {
              threshold = .5;
              bug = 'none';
              cost = 10;
            }),
            child: const Text('Reset metric debugging'),
          ),
          _gap,
          _source,
        ],
      ),
    );
  });
}
