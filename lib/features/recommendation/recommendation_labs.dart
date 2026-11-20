import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import 'recommendation_model.dart';

const _gap = SizedBox(height: 16),
    _bn = TextStyle(fontFamily: 'NotoSansBengali', height: 1.8),
    _title = TextStyle(fontSize: 24, fontWeight: FontWeight.w800);
String _n(num? x) => x == null ? 'undefined' : x.toStringAsFixed(4);
const _notice = Text(
  'বাস্তব MovieLens latest-small · GroupLens / Harper & Konstan (2015)। Pinned 2018 snapshot; source notice bundled। Non-commercial use, attribution ও same license conditions প্রযোজ্য। Ratings ≥4 থেকে preference signal তৈরি; click/impression logs নয়। Full metadata snapshot historically versioned নয়; offline diagnostic online satisfaction প্রমাণ নয়।',
  style: _bn,
);
Widget _asset(
  Future<RecommendationAssets> f,
  Widget Function(RecommendationAssets) body,
) => FutureBuilder<RecommendationAssets>(
  future: f,
  builder: (c, s) => s.hasError
      ? const Panel(
          child: Text('Bundled recommendation data could not be read.'),
        )
      : !s.hasData
      ? const Center(child: CircularProgressIndicator())
      : body(s.data!),
);

class FeedbackBaselineLab extends StatefulWidget {
  const FeedbackBaselineLab({super.key});
  @override
  State<FeedbackBaselineLab> createState() => _FeedbackBaselineLabState();
}

class _FeedbackBaselineLabState extends State<FeedbackBaselineLab> {
  final data = RecommendationAssets.load();
  bool bayesian = false;
  double strength = 20;
  int threshold = 4;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final counts = <int, int>{};
    for (final history in a.history.values) {
      for (final e in history.entries) {
        if (e.value >= threshold) counts[e.key] = (counts[e.key] ?? 0) + 1;
      }
    }
    final ordered = a.movies.keys.toList()
      ..sort((x, y) {
        final sx = bayesian
                ? a.bayesian(x, strength: strength)
                : (counts[x] ?? 0).toDouble(),
            sy = bayesian
                ? a.bayesian(y, strength: strength)
                : (counts[y] ?? 0).toDouble();
        final c = sy.compareTo(sx);
        return c != 0 ? c : x.compareTo(y);
      });
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag('RECOMMENDER SYSTEMS · CHAPTER 01 · FEEDBACK & BASELINES', icon: Icons.bar_chart),
          _gap,
          const Text('Observe the feedback. Build a baseline.', style: _title),
          _gap,
          const Text(
            'Rating explicit judgement; missing rating অজানা। Threshold দিয়ে binary preference বানালে তথ্য হারায়। Popularity এখানে positive user count; Bayesian mean-এ সব fit ratings ব্যবহার হয়। দুই score-এর unit আলাদা।',
            style: _bn,
          ),
          _gap,
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              ChoiceChip(
                key: const Key('rec-popularity'),
                label: const Text('Positive count'),
                selected: !bayesian,
                onSelected: (_) => setState(() => bayesian = false),
              ),
              ChoiceChip(
                key: const Key('rec-bayesian'),
                label: const Text('Bayesian mean'),
                selected: bayesian,
                onSelected: (_) => setState(() => bayesian = true),
              ),
            ],
          ),
          _gap,
          Text('Preference threshold: $threshold stars'),
          Slider(
            key: const Key('rec-threshold'),
            min: 3,
            max: 5,
            divisions: 2,
            value: threshold.toDouble(),
            onChanged: (v) => setState(() => threshold = v.round()),
          ),
          Text('Prior strength: ${strength.toInt()} ratings'),
          Slider(
            key: const Key('rec-strength'),
            min: 0,
            max: 100,
            divisions: 10,
            value: strength,
            onChanged: (v) => setState(() => strength = v),
          ),
          Text(
            bayesian
                ? 'Score = (rating sum + m × global mean) / (count + m). Threshold does not change this mean.'
                : 'Score = number of fit users with rating ≥ $threshold. Prior strength does not change this count.',
            style: _bn,
          ),
          _gap,
          Text(
            bayesian
                ? 'Bar scale: 0–5 stars'
                : 'Bar scale: 0–leading positive count',
            style: _bn,
          ),
          _gap,
          for (var j = 0; j < 5; j++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${j + 1}. ${a.movies[ordered[j]]!.title}\n${bayesian ? 'shrunk mean ${_n(a.bayesian(ordered[j], strength: strength))}' : 'positive users ${counts[ordered[j]] ?? 0}'} · all ratings ${a.counts[ordered[j]]} · raw mean ${_n(a.totals[ordered[j]]! / a.counts[ordered[j]]!)}',
                    style: _bn,
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: bayesian
                        ? a.bayesian(ordered[j], strength: strength) / 5
                        : (counts[ordered[j]] ?? 0) /
                              (counts[ordered.first] ?? 1),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(8),
                    semanticsLabel:
                        'Baseline score bar ${a.movies[ordered[j]]!.title}',
                  ),
                ],
              ),
            ),
          const Text(
            'এটি non-personalized catalog ranking; এই panel-এ কোনো user-এর seen items বাদ দেওয়া হয়নি। Workbench-এ full history filter আছে। Threshold/prior controls শেখার intervention; published scorecard কেবল threshold 4, prior 20-এর frozen run।',
            style: _bn,
          ),
          _gap,
          OutlinedButton(
            onPressed: () => setState(() {
              bayesian = false;
              strength = 20;
              threshold = 4;
            }),
            child: const Text('Reset feedback baseline'),
          ),
          _gap,
          _notice,
        ],
      ),
    );
  });
}

class RecommendationWorkbench extends StatefulWidget {
  const RecommendationWorkbench({super.key});
  @override
  State<RecommendationWorkbench> createState() =>
      _RecommendationWorkbenchState();
}

class _RecommendationWorkbenchState extends State<RecommendationWorkbench> {
  final data = RecommendationAssets.load();
  int? user;
  String method = 'user_cf';
  bool excludeSeen = true, showHistory = false;
  double shrink = 10;
  int neighbours = 20;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final cases = a.data['samples'] as List;
    user ??= cases.first['user'];
    final selected = user!, history = a.history[selected] ?? {};
    final results = a.recommend(
          selected,
          method,
          excludeSeen: excludeSeen,
          shrink: shrink,
          neighbourLimit: neighbours,
        ),
        ns = a.neighbours(selected, shrink: shrink, limit: neighbours);
    final row = (a.data['rows'] as List)
        .where((r) => r['user'] == selected)
        .firstOrNull;
    final eligible = row == null ? <int>{} : Set<int>.from(row['eligible']);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'RECOMMENDER SYSTEMS · CHAPTER 01 · RECOMMENDATION WORKBENCH',
            icon: Icons.people_outline,
          ),
          _gap,
          const Text('Find candidates. Explain the neighbors.', style: _title),
          _gap,
          const Text(
            'Full fit catalog-এর scores Dart-এ পুনরায় গণনা হয়। Content model normalized genre-IDF profile ব্যবহার করে; user CF shared positive items থেকে cosine ও overlap shrinkage নেয়। Ground truth নিচের inspection label-এ থাকে, score তৈরিতে নয়।',
            style: _bn,
          ),
          _gap,
          DropdownButtonFormField<int>(
            key: ValueKey('rec-user-$selected'),
            initialValue: selected,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Original source user',
            ),
            items: [
              for (final c in cases)
                DropdownMenuItem(
                  value: c['user'] as int,
                  child: Text(
                    'User ${c['user']} · ${(c['history'] as List).isEmpty ? 'cold' : 'warm'} history',
                  ),
                ),
            ],
            onChanged: (v) => setState(() => user = v),
          ),
          _gap,
          DropdownButtonFormField<String>(
            key: ValueKey('rec-method-$method'),
            initialValue: method,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Scoring method'),
            items: [
              for (final s in recommendationMethods)
                DropdownMenuItem(value: s, child: Text(s)),
            ],
            onChanged: (v) => setState(() => method = v!),
          ),
          _gap,
          Text(
            'History: ${history.length} observed ratings · ${a.likes[selected]?.length ?? 0} positive items',
            style: _bn,
          ),
          Text(
            history.isEmpty && (method == 'content' || method == 'user_cf')
                ? 'Fallback: popularity (no fit history)'
                : 'Scoring: $method${method == 'user_cf' && ns.isEmpty ? ' → popularity fallback (no usable neighbors)' : ''}',
            style: _bn,
          ),
          SwitchListTile(
            key: const Key('rec-seen'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Exclude all seen items'),
            subtitle: const Text(
              'Low ratings are seen too; missing items are not known negatives.',
            ),
            value: excludeSeen,
            onChanged: (v) => setState(() => excludeSeen = v),
          ),
          if (!excludeSeen)
            const Text(
              'Inspection mode: seen items included. Frozen scorecard uses seen filtering; these lists are not the same evaluation policy.',
              style: _bn,
            ),
          if (method == 'user_cf') ...[
            Text('Overlap shrinkage: ${shrink.toInt()}'),
            Slider(
              key: const Key('rec-shrink'),
              min: 0,
              max: 50,
              divisions: 5,
              value: shrink,
              onChanged: (v) => setState(() => shrink = v),
            ),
            Text('Neighbor limit: $neighbours'),
            Wrap(
              spacing: 12,
              children: [
                for (final k in [5, 20])
                  ChoiceChip(
                    key: Key('rec-neighbors-$k'),
                    label: Text('$k neighbors'),
                    selected: neighbours == k,
                    onSelected: (_) => setState(() => neighbours = k),
                  ),
              ],
            ),
            _gap,
            Text(
              'Usable neighbors: ${ns.length} · overlap ≥2 · self excluded',
              style: _bn,
            ),
            const Text('Similarity bars: 0–1, not probability', style: _bn),
            for (final n in ns.take(3)) ...[
              Text(
                'User ${n.user}: cosine × shrink = ${_n(n.similarity)} · shared likes ${n.overlap}',
                style: _bn,
              ),
              LinearProgressIndicator(
                value: n.similarity,
                minHeight: 6,
                borderRadius: BorderRadius.circular(8),
                semanticsLabel: 'Neighbor ${n.user} similarity',
              ),
              const SizedBox(height: 8),
            ],
            _gap,
          ],
          const Text(
            'Top 10 · full fit catalog',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          _gap,
          for (var j = 0; j < results.length; j++) ...[
            Text(
              '${j + 1}. ${a.movies[results[j].movie]!.title}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              'ID ${results[j].movie} · score ${_n(results[j].score)} · ${a.movies[results[j].movie]!.genres.join(' / ')}\n${history.containsKey(results[j].movie)
                  ? 'Seen rating ${history[results[j].movie]}'
                  : eligible.contains(results[j].movie)
                  ? 'Observed future positive (diagnostic only)'
                  : 'No observed future-positive annotation'}',
              style: _bn,
            ),
            _gap,
          ],
          TextButton(
            key: const Key('rec-history'),
            onPressed: () => setState(() => showHistory = !showHistory),
            child: Text(
              'History inspection: ${showHistory ? 'visible' : 'hidden'}',
            ),
          ),
          if (showHistory)
            for (final e in history.entries.take(12))
              Text('${a.movies[e.key]!.title} · ${e.value}', style: _bn),
          const Text(
            'Genre score thematic similarity; CF score weighted neighbor preference fraction, calibrated like probability নয়। Shrinkage/neighbor controls fixed data-তে scores বদলায়; no retraining বা offline report rewrite। Cold user-এর content/CF preferences নেই বলে popularity fallback হয়।',
            style: _bn,
          ),
          _gap,
          OutlinedButton(
            onPressed: () => setState(() {
              user = cases.first['user'];
              method = 'user_cf';
              excludeSeen = true;
              showHistory = false;
              shrink = 10;
              neighbours = 20;
            }),
            child: const Text('Reset recommendation workbench'),
          ),
          _gap,
          _notice,
        ],
      ),
    );
  });
}

class RecommendationEvaluationLab extends StatefulWidget {
  const RecommendationEvaluationLab({super.key});
  @override
  State<RecommendationEvaluationLab> createState() =>
      _RecommendationEvaluationLabState();
}

class _RecommendationEvaluationLabState
    extends State<RecommendationEvaluationLab> {
  final data = RecommendationAssets.load();
  bool warmOnly = true, showProtocol = false;
  int k = 10;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final r = a.data['report'];
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'RECOMMENDER SYSTEMS · CHAPTER 01 · TEMPORAL DIAGNOSTICS',
            icon: Icons.analytics_outlined,
          ),
          _gap,
          const Text(
            'Freeze the timeline. Audit the denominator.',
            style: _title,
          ),
          _gap,
          Text(
            'Fit: ${r['fit_count']} ratings · future: ${r['diagnostic_count']}\nCutoff UTC: ${r['cutoff_utc']}\nFit catalog: ${r['fit_catalog']} · future-only items: ${r['future_cold_items']}\nWarm eligible users: ${r['warm_eligible_users']} · cold positive users: ${r['cold_positive_users']}',
            style: _bn,
          ),
          _gap,
          const Text('Timeline by rating count · fit → future', style: _bn),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                Expanded(
                  flex: r['fit_count'],
                  child: Container(
                    height: 14,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                Expanded(
                  flex: r['diagnostic_count'],
                  child: Container(
                    height: 14,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                ),
              ],
            ),
          ),
          _gap,
          const Text(
            'একটি global cutoff; সমান timestamp-এর rows fit-এ একসঙ্গে। Model future window-তে update হয় না। Main cohort-এ fit history ও অন্তত একটি candidate-eligible future positive আছে। Broad cohort cold user/item অন্তর্ভুক্ত করে; denominators বদলে metric তুলনা করবেন না।',
            style: _bn,
          ),
          _gap,
          SwitchListTile(
            key: const Key('rec-cohort'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Warm eligible cohort'),
            value: warmOnly,
            onChanged: (v) => setState(() => warmOnly = v),
          ),
          Text(
            warmOnly
                ? 'Cohort: warm users / eligible positives'
                : 'Cohort: all future-positive users / all positives',
          ),
          Wrap(
            spacing: 12,
            children: [
              for (final n in [5, 10])
                ChoiceChip(
                  key: Key('rec-k-$n'),
                  label: Text('Top $n'),
                  selected: k == n,
                  onSelected: (_) => setState(() => k = n),
                ),
            ],
          ),
          _gap,
          for (final method in recommendationMethods) ...[
            Builder(
              builder: (_) {
                final s = recommendationScorecard(
                  a.data['rows'],
                  method,
                  k: k,
                  warmOnly: warmOnly,
                  catalogSize: a.movies.length,
                );
                return Text(
                  '$method · ${s['users']} users\nPrecision@$k ${_n(s['precision'])} · Recall@$k ${_n(s['recall'])}\nNDCG@$k ${_n(s['ndcg'])} · catalog coverage ${_n(s['catalog_coverage'])}',
                  style: _bn,
                );
              },
            ),
            _gap,
          ],
          Text(
            'Rating task, separate unit: Bayesian RMSE ${_n(r['bayesian_rmse'])}; global mean RMSE ${_n(r['global_mean_rmse'])}. All future observed ratings, cold items → global mean. This is not a ranking metric.',
            style: _bn,
          ),
          _gap,
          const Text(
            'No sampled negatives: full fit catalog minus all seen ratings। Unrated recommendations unknown, false positive প্রমাণ নয়। NDCG binary rating≥4, user-macro averaging। Catalog coverage recommendation union / fit catalog; user coverage বা satisfaction নয়। Hyperparameters fixed, no tuning; inspected diagnostic, blind test নয়।',
            style: _bn,
          ),
          _gap,
          TextButton(
            key: const Key('rec-protocol'),
            onPressed: () => setState(() => showProtocol = !showProtocol),
            child: Text(
              'Protocol audit: ${showProtocol ? 'visible' : 'hidden'}',
            ),
          ),
          if (showProtocol)
            Text(
              '${r['protocol']}\nSource hashes (recorded, not rehashed by this panel): ${r['source_hashes']}',
              style: _bn,
            ),
          OutlinedButton(
            onPressed: () => setState(() {
              warmOnly = true;
              k = 10;
              showProtocol = false;
            }),
            child: const Text('Reset recommendation evaluation'),
          ),
          _gap,
          _notice,
        ],
      ),
    );
  });
}
