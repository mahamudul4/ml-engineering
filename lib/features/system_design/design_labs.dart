import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import 'design_model.dart';

const _space = SizedBox(height: 16),
    _bn = TextStyle(fontFamily: 'NotoSansBengali', height: 1.8),
    _heading = TextStyle(fontSize: 24, fontWeight: FontWeight.w800);
String _n(num? x) => x == null ? 'undefined' : x.toStringAsFixed(3);
const _source = Text(
  'Real source artifacts: MovieLens/GroupLens, SciFact/Wadden et al., UCI Bike Sharing/Fanaee-T ও UCI Spambase/Hopkins et al.। Original notices/licenses bundled। Reused historical results ও নতুন development split; production traffic, latency, fraud efficacy বা scientific truth দাবি নয়।',
  style: _bn,
);
Widget _asset(Future<DesignAssets> f, Widget Function(DesignAssets) body) =>
    FutureBuilder<DesignAssets>(
      future: f,
      builder: (context, s) => s.hasError
          ? const Panel(
              child: Text(
                'Bundled system-design evidence could not be loaded.',
              ),
            )
          : s.hasData
          ? body(s.data!)
          : const Center(child: CircularProgressIndicator()),
    );

class ArchitectureCapacityLab extends StatefulWidget {
  const ArchitectureCapacityLab({super.key});
  @override
  State<ArchitectureCapacityLab> createState() =>
      _ArchitectureCapacityLabState();
}

class _ArchitectureCapacityLabState extends State<ArchitectureCapacityLab> {
  final data = DesignAssets.load();
  String system = 'recommendation';
  int qps = 1000, replicas = 4, deadline = 100;
  double hit = .5, scale = 1;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final c = a.data['cases'][system],
        plan = a.capacity(
          system,
          qps: qps,
          hit: hit,
          replicas: replicas,
          scale: scale,
          deadline: deadline,
        ),
        colors = Theme.of(context).colorScheme;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'ML SYSTEMS & INTERVIEWS · CHAPTER 04 · ARCHITECTURE & CAPACITY',
            icon: Icons.account_tree_outlined,
          ),
          _space,
          const Text('Map the path. Budget the bottleneck.', style: _heading),
          _space,
          const Text(
            'Five source-backed cases; নিচের stage times, load, cache hit ও concurrency স্পষ্ট planning assumptions। Stage group-এর branches parallel হলে max, groups serial হলে sum। এই arithmetic measured latency/p95 বা production sizing recommendation নয়।',
            style: _bn,
          ),
          _space,
          DropdownButtonFormField<String>(
            key: ValueKey('architecture-case-$system'),
            initialValue: system,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Design case'),
            items: [
              for (final id in designCases)
                DropdownMenuItem(
                  value: id,
                  child: Text(a.data['cases'][id]['title']),
                ),
            ],
            onChanged: (v) => setState(() => system = v!),
          ),
          _space,
          Text('${c['request']}\n${c['quality']}', style: _bn),
          _space,
          for (var j = 0; j < (c['stages'] as List).length; j++) ...[
            Text(
              'Stage ${j + 1}${(c['stages'][j] as List).length > 1 ? ' · parallel branches' : ' · serial'}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final stage in c['stages'][j])
                  Chip(
                    label: Text(
                      '${stage['label']} · ${_n(stage['ms'] * scale)} assumed ms',
                    ),
                  ),
              ],
            ),
            if (j < (c['stages'] as List).length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Icon(Icons.south, size: 18),
              ),
          ],
          _space,
          Text('External requests: $qps / s'),
          Wrap(
            spacing: 12,
            children: [
              for (final n in [100, 1000, 10000])
                ChoiceChip(
                  key: Key('architecture-qps-$n'),
                  label: Text('$n'),
                  selected: qps == n,
                  onSelected: (_) => setState(() => qps = n),
                ),
            ],
          ),
          _space,
          Text('Assumed cache hit: ${(hit * 100).round()}%'),
          Wrap(
            spacing: 12,
            children: [
              for (final h in [0.0, .5, .9])
                ChoiceChip(
                  key: Key('architecture-hit-$h'),
                  label: Text('${(h * 100).round()}%'),
                  selected: hit == h,
                  onSelected: (_) => setState(() => hit = h),
                ),
            ],
          ),
          _space,
          Text('Replica assumption: $replicas'),
          Wrap(
            spacing: 12,
            children: [
              for (final n in [1, 4, 16])
                ChoiceChip(
                  key: Key('architecture-replicas-$n'),
                  label: Text('$n'),
                  selected: replicas == n,
                  onSelected: (_) => setState(() => replicas = n),
                ),
            ],
          ),
          _space,
          Text('Stage-time scale: ${scale}x'),
          Wrap(
            spacing: 12,
            children: [
              for (final v in [.5, 1.0, 2.0])
                ChoiceChip(
                  key: Key('architecture-scale-$v'),
                  label: Text('${v}x'),
                  selected: scale == v,
                  onSelected: (_) => setState(() => scale = v),
                ),
            ],
          ),
          _space,
          Text('Miss-path deadline assumption: $deadline ms'),
          Wrap(
            spacing: 12,
            children: [
              for (final n in [50, 100, 250])
                ChoiceChip(
                  key: Key('architecture-deadline-$n'),
                  label: Text('$n ms'),
                  selected: deadline == n,
                  onSelected: (_) => setState(() => deadline = n),
                ),
            ],
          ),
          _space,
          Text(
            'Planning state: ${plan['state']}\nCritical path ${_n(plan['critical_ms'])} ms · serial-work sum ${_n(plan['serial_work_ms'])} ms\nParallel-path difference ${_n(plan['parallel_saved_ms'])} ms\nBackend miss load ${_n(plan['backend_qps'])} / s\nIdeal slot capacity ${_n(plan['ideal_capacity'])} / s\nUtilization ${_n(plan['utilization'])} · slots ${plan['concurrent_slots']}\nAverage in service under stable assumptions ${_n(plan['in_service'])}\nDeadline arithmetic slack ${_n(plan['deadline_slack'])} ms',
            style: _bn,
          ),
          _space,
          LinearProgressIndicator(
            value: (plan['utilization'] as num).toDouble().clamp(0.0, 1.0),
            minHeight: 10,
            color: plan['stable'] ? colors.primary : colors.error,
          ),
          _space,
          const Text(
            'Four concurrent request slots per replica assumed; miss slot occupied for critical-path duration। Cache lookup/ingress, branch resource contention, queue waits, retries ও tail dependence separately unknown। Cache hits upstream capacity free করে না। Utilization≥1 sustained fluid model-এ unstable; p95 estimate নয়। .7 headroom boundary শুধু declared planning flag।',
            style: _bn,
          ),
          _space,
          OutlinedButton(
            onPressed: () => setState(() {
              system = 'recommendation';
              qps = 1000;
              replicas = 4;
              deadline = 100;
              hit = .5;
              scale = 1;
            }),
            child: const Text('Reset architecture plan'),
          ),
          _space,
          _source,
        ],
      ),
    );
  });
}

class SelectiveReviewLab extends StatefulWidget {
  const SelectiveReviewLab({super.key});
  @override
  State<SelectiveReviewLab> createState() => _SelectiveReviewLabState();
}

class _SelectiveReviewLabState extends State<SelectiveReviewLab> {
  final data = DesignAssets.load();
  double low = .2, high = .8;
  int budget = 50, cost = 100;
  String overflow = 'defer';
  bool fault = false;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final r = a.review(
      low: low,
      high: high,
      budget: budget,
      overflow: overflow,
      fpCost: cost,
      fault: fault,
    );
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'ML SYSTEMS & INTERVIEWS · CHAPTER 04 · DECISION & REVIEW POLICY',
            icon: Icons.mark_email_read_outlined,
          ),
          _space,
          const Text(
            'Budget the review. Keep unresolved labels honest.',
            style: _heading,
          ),
          _space,
          const Text(
            'Real UCI Spambase: 4601 rows/57 numeric features; exact-profile group split। Fixed train-only scaled Logistic Regression,3183 fit/738 validation/680 reserved rows। Reserved outcomes unscored; validation is development। App recomputes all738 probabilities। Spam benchmark-কে fraud model বা current mailbox performance বলব না।',
            style: _bn,
          ),
          _space,
          Text('Auto-allow below: $low'),
          Wrap(
            spacing: 12,
            children: [
              for (final v in [.2, .4])
                ChoiceChip(
                  key: Key('review-low-$v'),
                  label: Text('$v'),
                  selected: low == v,
                  onSelected: (_) => setState(() => low = v),
                ),
            ],
          ),
          _space,
          Text('Auto-block at or above: $high'),
          Wrap(
            spacing: 12,
            children: [
              for (final v in [.6, .8])
                ChoiceChip(
                  key: Key('review-high-$v'),
                  label: Text('$v'),
                  selected: high == v,
                  onSelected: (_) => setState(() => high = v),
                ),
            ],
          ),
          _space,
          Text('Review admissions per retrospective batch: $budget'),
          Wrap(
            spacing: 12,
            children: [
              for (final n in [20, 50, 100])
                ChoiceChip(
                  key: Key('review-budget-$n'),
                  label: Text('$n'),
                  selected: budget == n,
                  onSelected: (_) => setState(() => budget = n),
                ),
            ],
          ),
          _space,
          Text('Overflow policy: $overflow'),
          Wrap(
            spacing: 12,
            children: [
              for (final v in ['defer', 'allow', 'block'])
                ChoiceChip(
                  key: Key('review-overflow-$v'),
                  label: Text(v),
                  selected: overflow == v,
                  onSelected: (_) => setState(() => overflow = v),
                ),
            ],
          ),
          _space,
          Text('False-block symbolic cost: $cost'),
          Wrap(
            spacing: 12,
            children: [
              for (final n in [10, 100])
                ChoiceChip(
                  key: Key('review-cost-$n'),
                  label: Text('$n'),
                  selected: cost == n,
                  onSelected: (_) => setState(() => cost = n),
                ),
            ],
          ),
          _space,
          SwitchListTile(
            key: const Key('review-contract-fault'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Block model contract · software fixture'),
            value: fault,
            onChanged: (v) => setState(() => fault = v),
          ),
          _space,
          Text(
            'Policy cohort: ${r['n']} development rows\nAuto-allow ${r['allow']} · auto-block ${r['block']}\nReview admitted ${r['review']} · deferred ${r['defer']}\nUncertain ${r['uncertain']} · overflow ${r['overflow_count']}\nUnresolved decisions ${r['pending']} · contract blocked ${r['contract_blocked']}\nAutomatic decision coverage ${_n(r['coverage'])}\nRetrospective false blocks ${r['false_blocks']} · missed spam ${r['missed_spam']}\nConditional automatic accuracy ${_n(r['conditional_accuracy'])}\nAutomatic-decision symbolic cost ${r['automatic_cost']}',
            style: _bn,
          ),
          _space,
          LinearProgressIndicator(
            value: (r['coverage'] as num?)?.toDouble() ?? 0,
            minHeight: 10,
          ),
          _space,
          Text(
            'Admitted source ordinals: ${(r['review_ids'] as List).take(10).join(', ')}${(r['review_ids'] as List).length > 10 ? ' …' : ''}',
            style: _bn,
          ),
          _space,
          const Text(
            'Uncertain requests prioritized by |p−.5| rounded to12 decimal places, ties original row ordinal; labels never drive routing। Score margin is an uncalibrated heuristic। Admitted review remains unresolved; human results invented নয়। Conditional accuracy excludes pending rows; all-cohort accuracy নয়। Symbolic cost excludes review, delay ও abstention costs—zero automatic cost policyকে free/best করে না। Budgets authored, not real arrivals or reviewer throughput।',
            style: _bn,
          ),
          _space,
          OutlinedButton(
            onPressed: () => setState(() {
              low = .2;
              high = .8;
              budget = 50;
              cost = 100;
              overflow = 'defer';
              fault = false;
            }),
            child: const Text('Reset review policy'),
          ),
          _space,
          _source,
        ],
      ),
    );
  });
}

class CaseFailureLab extends StatefulWidget {
  const CaseFailureLab({super.key});
  @override
  State<CaseFailureLab> createState() => _CaseFailureLabState();
}

class _CaseFailureLabState extends State<CaseFailureLab> {
  final data = DesignAssets.load();
  String system = 'recommendation', fault = 'none';
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final r = a.response(system, fault: fault);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'ML SYSTEMS & INTERVIEWS · CHAPTER 04 · CONTRACT & FAILURE REPLAY',
            icon: Icons.rule_outlined,
          ),
          _space,
          const Text(
            'Replay the dependency. Defend the response.',
            style: _heading,
          ),
          _space,
          const Text(
            'Frozen real MovieLens ranking, SciFact retrieval/response decoder, Spambase linear model ও Bike Ridge স্থানীয়ভাবে execute হয়। Faults explicitly authored policy fixtures; actual distributed outage, authorization service বা production recovery benchmark নয়।',
            style: _bn,
          ),
          _space,
          DropdownButtonFormField<String>(
            key: ValueKey('failure-case-$system'),
            initialValue: system,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Source-backed request',
            ),
            items: [
              for (final id in designCases)
                DropdownMenuItem(
                  value: id,
                  child: Text(a.data['cases'][id]['title']),
                ),
            ],
            onChanged: (v) => setState(() => system = v!),
          ),
          _space,
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              for (final f in designFaults)
                ChoiceChip(
                  key: Key('failure-fault-$f'),
                  label: Text(f),
                  selected: fault == f,
                  onSelected: (_) => setState(() => fault = f),
                ),
            ],
          ),
          _space,
          Text(
            'Response: ${r['status']}\nServed by ${r['served']}\nReason ${r['reason']}\nRequest ${r['request']}',
            style: _bn,
          ),
          _space,
          if (r['output'] != null)
            for (final e in (r['output'] as Map).entries)
              Text(
                '${e.key}: ${e.value is List
                    ? (e.value as List).join(', ')
                    : e.value is num
                    ? _n(e.value)
                    : e.value}',
                style: _bn,
              ),
          if ((r['citations'] as List).isNotEmpty)
            Text(
              'Exact-span citations: ${(r['citations'] as List).join(', ')}',
              style: _bn,
            ),
          _space,
          const Text(
            'Contract fields: case version, model identity, source identity, input schema, policy identity। Mismatch blocks request computation। App metadata fixture ও CLI actual-byte checks আলাদা। Upstream fixture drops personalization/dense candidates, withholds spam features, applies Bike late schedule or empties RAG context। Available validated fallback না থাকলে abstain।',
            style: _bn,
          ),
          _space,
          const Text(
            'RAG decoder শুধু support/contradict word generates; exact quotes provenance, entailment proof নয়। Output always unverified hypothesis, clinical/scientific verdict নয়। Search TF-IDF/LSA fixed corpus method, pretrained embedding model নয়। Sample replay output কোনো system-এর aggregate utility বা throughput guarantee দেয় না।',
            style: _bn,
          ),
          _space,
          OutlinedButton(
            onPressed: () => setState(() {
              system = 'recommendation';
              fault = 'none';
            }),
            child: const Text('Reset case failure replay'),
          ),
          _space,
          _source,
        ],
      ),
    );
  });
}
