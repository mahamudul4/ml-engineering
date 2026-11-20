import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import '../recommendation/recommendation_model.dart';
import 'capstone_model.dart';

const _gap = SizedBox(height: 16),
    _bn = TextStyle(fontFamily: 'NotoSansBengali', height: 1.8),
    _title = TextStyle(fontSize: 24, fontWeight: FontWeight.w800);
String _n(num? x) => x == null ? 'undefined' : x.toStringAsFixed(4);
const _source = Text(
  'বাস্তব MovieLens / GroupLens · source notice ও non-commercial conditions bundled। Historical inspected development data; full2018 metadata historically versioned নয়। No online lift, production latency বা fresh blind benchmark দাবি।',
  style: _bn,
);
Widget _asset(
  Future<RecommenderCapstoneAssets> future,
  Widget Function(RecommenderCapstoneAssets) body,
) => FutureBuilder<RecommenderCapstoneAssets>(
  future: future,
  builder: (c, s) => s.hasError
      ? const Panel(child: Text('Bundled capstone could not be loaded.'))
      : s.hasData
      ? body(s.data!)
      : const Center(child: CircularProgressIndicator()),
);

class CapstoneRetrievalLab extends StatefulWidget {
  const CapstoneRetrievalLab({super.key});
  @override
  State<CapstoneRetrievalLab> createState() => _CapstoneRetrievalLabState();
}

class _CapstoneRetrievalLabState extends State<CapstoneRetrievalLab> {
  final data = RecommenderCapstoneAssets.load();
  int? user;
  int budget = 50;
  String policy = 'rrf_cf';
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final samples = List<int>.from(a.data['samples']);
    user ??= samples.first;
    final row = a.row(user!),
        run = capstoneFuse(
          Map<String, dynamic>.from(row['sources']),
          policy: policy,
          budget: budget,
        ),
        gold = Set<int>.from(row['eligible']),
        metrics = recommendationMetrics(run.ranked, gold),
        hits = run.candidates.where(gold.contains).length;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'RECOMMENDER SYSTEMS · CHAPTER 05 · RETRIEVAL → FUSION',
            icon: Icons.hub_outlined,
          ),
          _gap,
          const Text('Build the pool. Explain every rank.', style: _title),
          _gap,
          const Text(
            'Frozen fit-only popularity/content/user-CF top100 snapshots। App recomputes union ও weighted RRF from rank positions; source retrievers Python-এ fresh fit থেকে তৈরি। Budgets/presets inspection controls, saved validation selection বদলায় না। Missing source contribution 0; score probability নয়।',
            style: _bn,
          ),
          _gap,
          DropdownButtonFormField<int>(
            key: ValueKey('capstone-user-$user'),
            initialValue: user,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Original audit user'),
            items: [
              for (final id in samples)
                DropdownMenuItem(
                  value: id,
                  child: Text(
                    'User $id · ${a.row(id)['cold_fallback'] ? 'popularity fallback' : 'warm history'}',
                  ),
                ),
            ],
            onChanged: (v) => setState(() => user = v),
          ),
          _gap,
          Text('Per-source budget: $budget'),
          Wrap(
            spacing: 12,
            children: [
              for (final n in [25, 50, 100])
                ChoiceChip(
                  key: Key('capstone-budget-$n'),
                  label: Text('$n'),
                  selected: budget == n,
                  onSelected: (_) => setState(() => budget = n),
                ),
            ],
          ),
          _gap,
          DropdownButtonFormField<String>(
            key: ValueKey('capstone-policy-$policy'),
            initialValue: policy,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Fusion inspection preset',
            ),
            items: [
              for (final p in capstonePolicies.keys)
                DropdownMenuItem(value: p, child: Text(p)),
            ],
            onChanged: (v) => setState(() => policy = v!),
          ),
          _gap,
          Text(
            'Union: ${run.candidates.length} unique / maximum ${3 * budget}\nEligible candidate Recall: ${gold.isEmpty ? 'undefined' : _n(hits / gold.length)}\nFinal Recall@10 ${_n(metrics['recall'])} · NDCG@10 ${_n(metrics['ndcg'])}',
            style: _bn,
          ),
          _gap,
          const Text(
            'Contribution share: popularity / content / CF · normalized bar, not probability',
          ),
          _gap,
          for (var j = 0; j < run.ranked.length; j++)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${j + 1}. ${a.model.movies[run.ranked[j]]!.title}\nSource ranks (pop/content/CF): ${(run.trace[j]['ranks'] as List).map((v) => v ?? 'absent').join(' / ')}\nRRF ${_n(run.trace[j]['score'])} = ${(run.trace[j]['contributions'] as List).map((v) => _n(v)).join(' + ')}',
                    style: _bn,
                  ),
                  const SizedBox(height: 8),
                  _ContributionBar(
                    values: List<double>.from(run.trace[j]['contributions']),
                  ),
                ],
              ),
            ),
          const Text(
            'RRF = sum w/(60+rank), one-based ranks; candidates sources-first deduplicated। All fit-seen ratings filtered before source TopL। Cold/no-positive history uses popularity; source lists overlap, not three independent signals। Unknown future items remain unreachable; no future gold in fusion.',
            style: _bn,
          ),
          _gap,
          OutlinedButton(
            onPressed: () => setState(() {
              user = samples.first;
              budget = 50;
              policy = 'rrf_cf';
            }),
            child: const Text('Reset capstone retrieval'),
          ),
          _gap,
          _source,
        ],
      ),
    );
  });
}

class _ContributionBar extends StatelessWidget {
  final List<double> values;
  const _ContributionBar({required this.values});
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme,
        colors = [c.primary, c.tertiary, c.secondary];
    return Semantics(
      label:
          'Popularity ${_n(values[0])}, content ${_n(values[1])}, CF ${_n(values[2])}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          height: 8,
          child: Row(
            children: [
              for (var j = 0; j < 3; j++)
                if (values[j] > 0)
                  Expanded(
                    flex: (values[j] * 1e9).round(),
                    child: ColoredBox(
                      color: colors[j],
                      child: const SizedBox.expand(),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class CapstoneEvaluationLab extends StatefulWidget {
  const CapstoneEvaluationLab({super.key});
  @override
  State<CapstoneEvaluationLab> createState() => _CapstoneEvaluationLabState();
}

class _CapstoneEvaluationLabState extends State<CapstoneEvaluationLab> {
  final data = RecommenderCapstoneAssets.load();
  String role = 'validation', scope = 'warm';
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final selected = capstoneSelect(
          Map<String, dynamic>.from(a.data['scorecards']['validation']),
        ),
        report = a.data['report'],
        ci = a.data['paired'];
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'RECOMMENDER SYSTEMS · CHAPTER 05 · LOCKED EVALUATION',
            icon: Icons.fact_check_outlined,
          ),
          _gap,
          const Text(
            'Select on validation. Audit the decision.',
            style: _title,
          ),
          _gap,
          Text(
            'Fit ${report['fit_rows']} · validation ${report['validation_rows']} · audit ${report['audit_rows']}\nFit cutoff ${report['fit_cutoff']} · validation cutoff ${report['validation_cutoff']}\nLocked fusion selection: $selected',
            style: _bn,
          ),
          _gap,
          const Text(
            'Warm validation NDCG descending, then Recall, rounded12, then declared preset order। Only three fusion policies in selector; popularity/user-CF separate baselines। No validation/audit refit or history update। Initial60/20/20 feasibility audit had only5 warm users; fit history expanded to80%, historical reuse declared.',
            style: _bn,
          ),
          _gap,
          DropdownButtonFormField<String>(
            key: ValueKey('capstone-role-$role'),
            initialValue: role,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Frozen role scorecards',
            ),
            items: [
              for (final r in ['validation', 'audit'])
                DropdownMenuItem(value: r, child: Text(r)),
            ],
            onChanged: (v) => setState(() => role = v!),
          ),
          _gap,
          DropdownButtonFormField<String>(
            key: ValueKey('capstone-scope-$scope'),
            initialValue: scope,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Target cohort'),
            items: [
              for (final s in ['warm', 'broad', 'cold'])
                DropdownMenuItem(value: s, child: Text(s)),
            ],
            onChanged: (v) => setState(() => scope = v!),
          ),
          _gap,
          Text('Scorecard: $role / $scope', style: _bn),
          for (final method in [
            'popularity',
            'user_cf',
            ...capstonePolicies.keys,
          ])
            Builder(
              builder: (_) {
                final s = a.data['scorecards'][role][method][scope];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    '$method · ${s['users']} users\nRecall@10 ${_n(s['recall'])} · NDCG@10 ${_n(s['ndcg'])}\nPool coverage ${_n(s['candidate_recall'])} · oracle Recall@10 ${_n(s['oracle_recall10'])}\nMean candidates ${_n(s['mean_candidates'])} · catalog coverage ${_n(s['catalog_coverage'])}',
                    style: _bn,
                  ),
                );
              },
            ),
          _gap,
          Text(
            'Fixed audit warm paired Recall vs popularity: ${ci['users']} users\nMean ${_n(ci['mean'])} · conditional95% interval [${_n(ci['low'])}, ${_n(ci['high'])}]',
            style: _bn,
          ),
          const Text(
            'Bootstrap5000 seed34, user differences, fixed selected policy; selector not resampled, interval is not selection-adjusted or causal। Baseline candidate pool here means returned Top10, fusion pool means union up to150: pool-cost/coverage values are different stages, not equal-budget retrieval comparison.',
            style: _bn,
          ),
          _gap,
          const Text(
            'Decision: EDUCATIONAL PROTOTYPE ONLY\nFusion winner is not overall winner: user-CF NDCG exceeds selected fusion on validation and audit। Small selected cohorts, observed ratings, historical reuse and no online evidence prevent a launch claim.',
            style: _bn,
          ),
          _gap,
          OutlinedButton(
            onPressed: () => setState(() {
              role = 'validation';
              scope = 'warm';
            }),
            child: const Text('Reset capstone evaluation'),
          ),
          _gap,
          _source,
        ],
      ),
    );
  });
}

class CapstoneServingLab extends StatefulWidget {
  const CapstoneServingLab({super.key});
  @override
  State<CapstoneServingLab> createState() => _CapstoneServingLabState();
}

class _CapstoneServingLabState extends State<CapstoneServingLab> {
  final data = RecommenderCapstoneAssets.load();
  String fault = 'none', mode = 'complete';
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final expected = Map<String, dynamic>.from(a.data['manifest']),
        loaded = {...expected};
    if (fault != 'none') loaded[fault] = 'incompatible-fixture';
    final errors = capstoneContractErrors(expected, loaded),
        replay =
            capstoneGuardedReplay(
              a.data['roles']['audit'],
              expected,
              loaded,
              mode: mode,
            ) ??
            <String, dynamic>{};
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'RECOMMENDER SYSTEMS · CHAPTER 05 · ARTIFACT & SERVING CONTRACT',
            icon: Icons.inventory_2_outlined,
          ),
          _gap,
          const Text('Version the model. Guard the response.', style: _title),
          _gap,
          const Text(
            'SOFTWARE FIXTURE · injected metadata mismatch ও scripted request sequence, not production incidents/traffic or latency measurements। Real audit user IDs এবং actual source candidates থেকে recommendations recompute হয়। App checks declared fields; companion CLI independently verifies actual artifact bytes/SHA256.',
            style: _bn,
          ),
          _gap,
          DropdownButtonFormField<String>(
            key: ValueKey('capstone-fault-$fault'),
            initialValue: fault,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Declared contract fault',
            ),
            items: [
              for (final f in [
                'none',
                'model_version',
                'model_sha256',
                'catalog_sha256',
                'feature_schema',
                'policy_sha256',
              ])
                DropdownMenuItem(value: f, child: Text(f)),
            ],
            onChanged: (v) => setState(() => fault = v!),
          ),
          _gap,
          Text(
            errors.isEmpty
                ? 'Contract: READY'
                : 'Contract: BLOCKED · ${errors.join(', ')}',
            style: _bn,
          ),
          Text(
            'Model ${expected['model_version']}\nSchema ${expected['feature_schema']}\nCatalog hash ${expected['catalog_sha256'].toString().substring(0, 16)}…',
            style: _bn,
          ),
          _gap,
          DropdownButtonFormField<String>(
            key: ValueKey('capstone-cache-$mode'),
            initialValue: mode,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Cache key inspection',
            ),
            items: [
              for (final m in ['complete', 'shared_user', 'omit_policy'])
                DropdownMenuItem(value: m, child: Text(m)),
            ],
            onChanged: (v) => setState(() => mode = v!),
          ),
          _gap,
          if (errors.isNotEmpty)
            const Text(
              'Serving blocked before cache lookup. Resolve artifact mismatch or explicitly load a separately validated fallback bundle; arbitrary partial files are unsafe.',
              style: _bn,
            )
          else ...[
            Text(
              'Replay: ${replay['requests']} requests · ${replay['hits']} hits · ${replay['rejected']} rejected collisions · ${replay['computations']} computations',
              style: _bn,
            ),
            for (final r in replay['trace'])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'User ${r['user']} · ${r['policy']}\n${r['rejected']
                      ? 'REJECT mismatched payload → recompute'
                      : r['hit']
                      ? 'HIT exact signature'
                      : 'MISS → compute'}\nTop3: ${(r['ranked'] as List).take(3).join(', ')}',
                  style: _bn,
                ),
              ),
          ],
          _gap,
          const Text(
            'Complete signature: model byte hash/catalog/schema and model/policy artifact version, user, fit-history hash, fusion preset, budget and seen-filter policy। Guard validates cached payload signature even when a deliberately incomplete key collides। Rejection prevents cross-user/stale-policy output; more hits alone is not correctness or a speedup benchmark.',
            style: _bn,
          ),
          _gap,
          OutlinedButton(
            onPressed: () => setState(() {
              fault = 'none';
              mode = 'complete';
            }),
            child: const Text('Reset capstone serving'),
          ),
          _gap,
          _source,
        ],
      ),
    );
  });
}
