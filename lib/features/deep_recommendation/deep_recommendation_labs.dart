import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import '../recommendation/recommendation_model.dart';
import 'deep_recommendation_model.dart';

const _gap = SizedBox(height: 16),
    _bn = TextStyle(fontFamily: 'NotoSansBengali', height: 1.8),
    _title = TextStyle(fontSize: 24, fontWeight: FontWeight.w800);
String _n(num? x) => x == null ? 'undefined' : x.toStringAsFixed(4);
const _source = Text(
  'বাস্তব MovieLens latest-small · GroupLens; source license/attribution bundled, non-commercial conditions প্রযোজ্য। একই outer temporal cutoff, 28 warm eligible/116 broad users। Metadata historically versioned নয়; inspected diagnostics, blind benchmark নয়। Runtime সম্পূর্ণ offline; app Python চালায় না।',
  style: _bn,
);
Widget _asset(
  Future<DeepRecommendationAssets> f,
  Widget Function(DeepRecommendationAssets) body,
) => FutureBuilder<DeepRecommendationAssets>(
  future: f,
  builder: (c, s) => s.hasError
      ? const Panel(
          child: Text('Bundled deep recommendation model could not be read.'),
        )
      : !s.hasData
      ? const Center(child: CircularProgressIndicator())
      : body(s.data!),
);
Widget _bar(String label, double value) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text('$label: ${_n(value)}', style: _bn),
    LinearProgressIndicator(
      value: value.clamp(0, 1),
      minHeight: 7,
      borderRadius: BorderRadius.circular(6),
    ),
    _gap,
  ],
);

class DeepRetrievalLab extends StatefulWidget {
  const DeepRetrievalLab({super.key});
  @override
  State<DeepRetrievalLab> createState() => _DeepRetrievalLabState();
}

class _DeepRetrievalLabState extends State<DeepRetrievalLab> {
  final data = DeepRecommendationAssets.load();
  int? user;
  int budget = 50;
  bool hybrid = false, rerank = true;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final cases = a.data['samples'] as List;
    user ??= cases.first['user'];
    final uid = user!,
        run = a.run(uid, budget: budget, hybrid: hybrid),
        shown = rerank ? run.ranked : run.candidates.take(10).toList(),
        row = (a.data['rows'] as List).firstWhere((r) => r['user'] == uid),
        gold = Set<int>.from(row['eligible']),
        hits = run.candidates.where(gold.contains).length,
        finalHits = shown.where(gold.contains).length;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'RECOMMENDER SYSTEMS · CHAPTER 03 · RETRIEVAL → RANKING',
            icon: Icons.filter_alt_outlined,
          ),
          _gap,
          const Text('Retrieve candidates. Rank the shortlist.', style: _title),
          _gap,
          const Text(
            'Two-tower query/item vectors ও ranker logits Dart-এ গণনা হয়। Exact full-catalog scan; ANN বা measured latency নয়। Relevant কোনো Movie Candidate List-এ না এলে Reranker সেটি ফেরত আনতে পারে না। Gold Label শুধু ফল যাচাইয়ের Metric-এ ব্যবহার হয়। Model-এর Score হিসাব করতে এগুলো লাগে না।',
            style: _bn,
          ),
          _gap,
          DropdownButtonFormField<int>(
            key: ValueKey('deep-user-$uid'),
            initialValue: uid,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Original source user',
            ),
            items: [
              for (final c in cases)
                DropdownMenuItem(
                  value: c['user'] as int,
                  child: Text(
                    'User ${c['user']} · ${a.isCold(c['user']) ? 'cold' : 'warm'}',
                  ),
                ),
            ],
            onChanged: (v) => setState(() => user = v),
          ),
          _gap,
          Text('Neural budget: $budget'),
          Wrap(
            spacing: 12,
            children: [
              for (final n in [20, 50, 100])
                ChoiceChip(
                  key: Key('deep-budget-$n'),
                  label: Text('$n candidates'),
                  selected: budget == n,
                  onSelected: (_) => setState(() => budget = n),
                ),
            ],
          ),
          SwitchListTile(
            key: const Key('deep-hybrid'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Union with popularity candidates'),
            subtitle: const Text(
              'Same per-source budget; deduplicated union can be up to 2× larger.',
            ),
            value: hybrid,
            onChanged: (v) => setState(() => hybrid = v),
          ),
          SwitchListTile(
            key: const Key('deep-rerank'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Apply frozen MLP ranker'),
            value: rerank,
            onChanged: (v) => setState(() => rerank = v),
          ),
          Text(
            run.fallback
                ? 'Fallback: popularity; neural ranker bypassed'
                : 'Pipeline: normalized towers → candidate union → MLP',
            style: _bn,
          ),
          Text(
            'Actual candidates: ${run.candidates.length} · returned ${shown.length}',
            style: _bn,
          ),
          _gap,
          if (gold.isNotEmpty) ...[
            _bar('Candidate recall / eligible positives', hits / gold.length),
            _bar('Oracle Recall@10 ceiling', math.min(10, hits) / gold.length),
            _bar('Displayed Recall@10', finalHits / gold.length),
          ] else
            const Text(
              'Eligible future-positive set empty: recall undefined.',
              style: _bn,
            ),
          for (var j = 0; j < shown.length; j++) ...[
            Text(
              '${j + 1}. ${a.base.movies[shown[j]]!.title}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              'ID ${shown[j]} · ${gold.contains(shown[j]) ? 'observed eligible future positive' : 'no observed future-positive annotation'}${run.fallback ? '' : '\nTower dot ${_n(deepDot(a.queries[a.userIndex[uid]!], a.vectors[a.itemIndex[shown[j]]!]))} · ranker logit ${_n(a.logit(a.features(uid, shown[j])))}'}',
              style: _bn,
            ),
            _gap,
          ],
          const Text(
            'Reranker off দেখায় candidate source order; hybrid হলে neural list আগে, নতুন popularity IDs পরে। Candidate pool বদলালে compute budget-ও বদলায়। এই display control নতুন training বা frozen report rewrite নয়। Missing annotation সত্যিকার dislike প্রমাণ করে না।',
            style: _bn,
          ),
          _gap,
          OutlinedButton(
            onPressed: () => setState(() {
              user = cases.first['user'];
              budget = 50;
              hybrid = false;
              rerank = true;
            }),
            child: const Text('Reset deep retrieval'),
          ),
          _gap,
          _source,
        ],
      ),
    );
  });
}

class ContrastiveBatchLab extends StatefulWidget {
  const ContrastiveBatchLab({super.key});
  @override
  State<ContrastiveBatchLab> createState() => _ContrastiveBatchLabState();
}

class _ContrastiveBatchLabState extends State<ContrastiveBatchLab> {
  final data = DeepRecommendationAssets.load();
  double temperature = .2;
  int anchor = 0;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final b = a.data['first_batch'],
        users = b['users'] as List,
        candidates = List<int>.from(b['candidates']),
        positive = Set<int>.from(b['positive_columns'][anchor]),
        q = a.queries[a.userIndex[users[anchor]]!],
        logits = [
          for (final i in candidates)
            deepDot(q, a.vectors[a.itemIndex[i]!]) / temperature,
        ],
        logz = deepLogSumExp(logits),
        loss = a.batchLoss(temperature: temperature),
        order = List.generate(candidates.length, (i) => i)
          ..sort((x, y) => logits[y].compareTo(logits[x]));
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'RECOMMENDER SYSTEMS · CHAPTER 03 · CONTRASTIVE BATCH',
            icon: Icons.grid_view_outlined,
          ),
          _gap,
          const Text(
            'Inspect the candidates. Fix the positives.',
            style: _title,
          ),
          _gap,
          Text(
            'প্রথম actual training batch-এর ${users.length} anchors, ${candidates.length} unique candidates ও 64 uniform draws। এখানে final trained weights দিয়ে সেই batch inspect হচ্ছে; first-step loss নয়। Duplicate IDs collapse হয়েছে; retrieval-role-এর সব known positives target probability সমান ভাগ পায়।',
            style: _bn,
          ),
          _gap,
          DropdownButtonFormField<int>(
            key: ValueKey('deep-anchor-$anchor'),
            initialValue: anchor,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Actual batch anchor'),
            items: [
              for (var j = 0; j < 3; j++)
                DropdownMenuItem(
                  value: j,
                  child: Text('Anchor $j · User ${users[j]}'),
                ),
            ],
            onChanged: (v) => setState(() => anchor = v!),
          ),
          _gap,
          Text('Temperature: ${temperature.toStringAsFixed(1)}'),
          Wrap(
            spacing: 12,
            children: [
              for (final v in [.1, .2, 1.0])
                ChoiceChip(
                  key: Key('deep-temperature-$v'),
                  label: Text('τ $v'),
                  selected: temperature == v,
                  onSelected: (_) => setState(() => temperature = v),
                ),
            ],
          ),
          _gap,
          Text(
            'Known positive columns: ${positive.length}\nSelected row CE: ${_n(loss[anchor])}\nFull batch mean CE: ${_n(loss.reduce((x, y) => x + y) / loss.length)}',
            style: _bn,
          ),
          _gap,
          for (final j in order.take(6)) ...[
            _bar(
              'Movie ${candidates[j]} · ${positive.contains(j) ? 'known positive' : 'contrast class'} · softmax mass',
              math.exp(logits[j] - logz),
            ),
          ],
          const Text(
            'Target = uniform distribution over known positive columns; loss = mean negative log-probability of those positives। এটি set-mass logsumexp loss নয়। Temperature probabilities/loss বদলায়, positive τ-তে dot ranking বদলায় না। Unknown contrast item verified dislike নয়।',
            style: _bn,
          ),
          _gap,
          const Text(
            'Actual objective uncorrected in-batch + uniform sampled contrast। No logQ correction বা unbiased full-catalog likelihood দাবি নেই। Batch-dependent probability calibrated preference/CTR নয়। Reported experiment fixed τ.2; controls do not retrain।',
            style: _bn,
          ),
          _gap,
          OutlinedButton(
            onPressed: () => setState(() {
              temperature = .2;
              anchor = 0;
            }),
            child: const Text('Reset contrastive batch'),
          ),
          _gap,
          _source,
        ],
      ),
    );
  });
}

class DeepRankingAuditLab extends StatefulWidget {
  const DeepRankingAuditLab({super.key});
  @override
  State<DeepRankingAuditLab> createState() => _DeepRankingAuditLabState();
}

class _DeepRankingAuditLabState extends State<DeepRankingAuditLab> {
  final data = DeepRecommendationAssets.load();
  bool warm = true, neutral = false;
  String config = 'neural50';
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final sample = a.data['samples'][0],
        uid = sample['user'] as int,
        item = sample['scores'][0]['item'] as int,
        raw = a.features(uid, item),
        changed = [...raw];
    if (neutral) changed[0] = a.featureMean[0];
    final standardized = a.standardize(changed),
        score = a.logit(changed),
        s = deepPipelineScore(
          a.data['rows'],
          config,
          warmOnly: warm,
          catalogSize: a.items.length,
        ),
        names = List<String>.from(a.data['report']['feature_names']);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'RECOMMENDER SYSTEMS · CHAPTER 03 · RANKING FEATURES & AUDIT',
            icon: Icons.analytics_outlined,
          ),
          _gap,
          const Text('Trace the features. Audit the funnel.', style: _title),
          _gap,
          Text(
            'Actual User $uid / Movie $item। Ranker labels retrieval labels থেকে disjoint; সব data outer cutoff-এর আগে। Frozen retrieval-role counts/profile ও ranker-role scaler ব্যবহার হয়। 5→16 ReLU→1 MLP observed rating≥4 predict করে; impression CTR নয়।',
            style: _bn,
          ),
          _gap,
          SwitchListTile(
            key: const Key('deep-neutral'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Neutralize tower feature'),
            subtitle: const Text(
              'Set standardized tower feature to zero, fixed weights.',
            ),
            value: neutral,
            onChanged: (v) => setState(() => neutral = v),
          ),
          for (var j = 0; j < raw.length; j++)
            Text(
              '${names[j]}\nraw ${_n(changed[j])} · mean ${_n(a.featureMean[j])} · std ${_n(a.featureStd[j])} · z ${_n(standardized[j])}',
              style: _bn,
            ),
          _gap,
          Text(
            'Inspection logit: ${_n(score)}\nSigmoid score: ${_n(score >= 0 ? 1 / (1 + math.exp(-score)) : math.exp(score) / (1 + math.exp(score)))}',
            style: _bn,
          ),
          const Text(
            'Sigmoid calibrated serving probability নয়। Neutralization একটি input intervention, causal feature importance বা refitted ablation নয়। Ranker training observed-rating pairs-এ; served retrieved candidates-এর distribution আলাদা হতে পারে।',
            style: _bn,
          ),
          _gap,
          DropdownButtonFormField<String>(
            key: ValueKey('deep-config-$config'),
            initialValue: config,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Frozen pipeline configuration',
            ),
            items: [
              for (final v in deepRecommendationConfigs)
                DropdownMenuItem(value: v, child: Text(v)),
            ],
            onChanged: (v) => setState(() => config = v!),
          ),
          _gap,
          SwitchListTile(
            key: const Key('deep-cohort'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Warm eligible cohort'),
            value: warm,
            onChanged: (v) => setState(() => warm = v),
          ),
          Text(
            warm
                ? 'Cohort: warm users / eligible positives'
                : 'Cohort: all future-positive users / all positives',
          ),
          _gap,
          Text(
            '${s['users']} users · mean candidate count ${_n(s['mean_candidates'])}',
            style: _bn,
          ),
          _bar('Candidate recall', (s['candidate_recall'] as num).toDouble()),
          _bar('Oracle Recall@10', (s['oracle_recall10'] as num).toDouble()),
          _bar('Final Recall@10', (s['recall'] as num).toDouble()),
          Text(
            'Precision@10 ${_n(s['precision'])} · NDCG@10 ${_n(s['ndcg'])}\nCatalog coverage ${_n(s['catalog_coverage'])}',
            style: _bn,
          ),
          _gap,
          for (final method in ['popularity', 'user_cf'])
            Builder(
              builder: (_) {
                final b = recommendationScorecard(
                  a.data['rows'],
                  method,
                  warmOnly: warm,
                  catalogSize: a.items.length,
                );
                return Text(
                  '$method baseline · Recall@10 ${_n(b['recall'])} · NDCG@10 ${_n(b['ndcg'])}',
                  style: _bn,
                );
              },
            ),
          _gap,
          const Text(
            'Candidate ceiling gold জেনে বানানো diagnostic upper bound; deployed reranker oracle নয়। Hybrid source union-এর budget বেশি হতে পারে। No measured latency/ANN, no tuning/CI/fresh blind test বা online lift। Frozen report neutralization control দিয়ে বদলায় না।',
            style: _bn,
          ),
          _gap,
          OutlinedButton(
            onPressed: () => setState(() {
              warm = true;
              neutral = false;
              config = 'neural50';
            }),
            child: const Text('Reset deep ranking audit'),
          ),
          _gap,
          _source,
        ],
      ),
    );
  });
}
