import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import 'feature_model.dart';

const _gap = SizedBox(height: 16),
    _bn = TextStyle(fontFamily: 'NotoSansBengali', height: 1.8),
    _title = TextStyle(fontSize: 24, fontWeight: FontWeight.w800);
String _n(num? x) => x == null ? 'undefined' : x.toStringAsFixed(3);
const _source = Text(
  'বাস্তব UCI Bike Sharing · Fanaee-T(2013), CC BY4.0; source notice bundled। প্রথম547 daily observations,শেষ184 outcomes ব্যবহার হয়নি। Arrival schedule ও bad delivery স্পষ্ট software fixtures; real ingestion clocks/streaming throughput/model accuracy দাবি নয়।',
  style: _bn,
);
Widget _asset(
  Future<FeatureSystemAssets> f,
  Widget Function(FeatureSystemAssets) body,
) => FutureBuilder<FeatureSystemAssets>(
  future: f,
  builder: (c, s) => s.hasError
      ? const Panel(
          child: Text('Bundled feature evidence could not be loaded.'),
        )
      : s.hasData
      ? body(s.data!)
      : const Center(child: CircularProgressIndicator()),
);
Widget _vector(Map<String, dynamic> values) => Text(
  [for (final key in featureFields) '$key: ${_n(values[key])}'].join('\n'),
  style: _bn,
);

class PointInTimeFeatureLab extends StatefulWidget {
  const PointInTimeFeatureLab({super.key});
  @override
  State<PointInTimeFeatureLab> createState() => _PointInTimeFeatureLabState();
}

class _PointInTimeFeatureLabState extends State<PointInTimeFeatureLab> {
  final data = FeatureSystemAssets.load();
  String scenario = 'late_fixture';
  int target = 375;
  bool latest = false;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final events = a.events(scenario),
        pit = pointInTimeFeatures(events, target),
        shown = pointInTimeFeatures(events, target, latest: latest),
        diff = featureDifference(pit, shown),
        window = events
            .where(
              (r) => r['event_day'] >= target - 7 && r['event_day'] < target,
            )
            .toList(),
        outcome = events.firstWhere((r) => r['event_day'] == target)['cnt'];
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'ML SYSTEMS & INTERVIEWS · CHAPTER 01 · POINT-IN-TIME FEATURES',
            icon: Icons.history_outlined,
          ),
          _gap,
          const Text('Ask what was available then.', style: _title),
          _gap,
          const Text(
            'Daily prediction at target-day start। Feature window [target−7,target), available_day≤target। Counts/dates real; on_time availability=day+1, late_fixture adds3 days every17th event। Nominal calendar indices, no actual source timezone/ingestion claim।',
            style: _bn,
          ),
          _gap,
          DropdownButtonFormField<int>(
            key: ValueKey('feature-target-$target'),
            initialValue: target,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Actual historical prediction date',
            ),
            items: [
              for (final t in [365, 375, 409, 545])
                DropdownMenuItem(
                  value: t,
                  child: Text('${featureDate(t)} · day$t'),
                ),
            ],
            onChanged: (v) => setState(() => target = v!),
          ),
          _gap,
          Wrap(
            spacing: 12,
            children: [
              for (final s in featureScenarios)
                ChoiceChip(
                  key: Key('feature-scenario-$s'),
                  label: Text(s),
                  selected: scenario == s,
                  onSelected: (_) => setState(() => scenario = s),
                ),
            ],
          ),
          _gap,
          SwitchListTile(
            key: const Key('feature-latest'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Retrospective latest state · declared bug'),
            value: latest,
            onChanged: (v) => setState(() => latest = v),
          ),
          _gap,
          Text(
            'Lookup: ${latest ? 'LATEST (availability ignored)' : 'POINT IN TIME'}\nPrediction cutoff: ${featureDate(target)}\nDifferent fields: ${diff.isEmpty ? 'none' : diff.join(', ')}',
            style: _bn,
          ),
          _gap,
          _vector(shown),
          _gap,
          Text('Window coverage: ${shown['observed7']} / 7', style: _bn),
          LinearProgressIndicator(
            value: (shown['observed7'] as num) / 7,
            minHeight: 8,
          ),
          _gap,
          for (final row in window)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '${row['date']} · actual count ${row['cnt']}\nFixture available ${featureDate(row['available_day'])} · ${row['available_day'] <= target ? 'KNOWN at cutoff' : 'NOT YET AVAILABLE'}',
                style: _bn,
              ),
            ),
          Text(
            'Retrospective target outcome: $outcome · NEVER a feature',
            style: _bn,
          ),
          _gap,
          const Text(
            'lag1/lag7 missing হলে null, rolling mean শুধু known rows-এর denominator। Later backfill দিয়ে historical prediction সাজালে availability leakage হয়। Changing display mode does not change source observations or saved reference protocol.',
            style: _bn,
          ),
          _gap,
          OutlinedButton(
            onPressed: () => setState(() {
              scenario = 'late_fixture';
              target = 375;
              latest = false;
            }),
            child: const Text('Reset point-in-time features'),
          ),
          _gap,
          _source,
        ],
      ),
    );
  });
}

class PipelineReplayLab extends StatefulWidget {
  const PipelineReplayLab({super.key});
  @override
  State<PipelineReplayLab> createState() => _PipelineReplayLabState();
}

class _PipelineReplayLabState extends State<PipelineReplayLab> {
  final data = FeatureSystemAssets.load();
  bool duplicates = false, invalid = false;
  int chunk = 32;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final r = featureReplay(
          a.events('late_fixture'),
          duplicates: duplicates,
          invalid: invalid,
          chunk: chunk,
        ),
        stats = a.data['statistics']['late_fixture'];
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'ML SYSTEMS & INTERVIEWS · CHAPTER 01 · IDEMPOTENT PIPELINE',
            icon: Icons.sync_alt_outlined,
          ),
          _gap,
          const Text('Replay safely. Materialize once.', style: _title),
          _gap,
          const Text(
            'SOFTWARE DELIVERY FIXTURE · actual547 source events sorted by declared availability। Duplicate toggle replays the same events; invalid toggle adds one negative-count copy that is rejected before storage। Source counts remain unchanged। UI uses Dart map replay; companion workflow executes actual SQLite transactions.',
            style: _bn,
          ),
          _gap,
          SwitchListTile(
            key: const Key('pipeline-duplicates'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Deliver every real event twice'),
            value: duplicates,
            onChanged: (v) => setState(() => duplicates = v),
          ),
          SwitchListTile(
            key: const Key('pipeline-invalid'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Inject one invalid software fixture'),
            value: invalid,
            onChanged: (v) => setState(() => invalid = v),
          ),
          _gap,
          Text('Logical batch size: $chunk'),
          Wrap(
            spacing: 12,
            children: [
              for (final n in [1, 32, 128])
                ChoiceChip(
                  key: Key('pipeline-chunk-$n'),
                  label: Text('$n'),
                  selected: chunk == n,
                  onSelected: (_) => setState(() => chunk = n),
                ),
            ],
          ),
          _gap,
          Text(
            'Deliveries ${r['deliveries']}\nInserted ${r['inserted']} · duplicate no-ops ${r['duplicates']}\nRejected ${r['rejected']} · stored ${r['stored']}\nLogical batches ${r['batches']}',
            style: _bn,
          ),
          _gap,
          const Text(
            'Natural key: scenario + bike-global:date। Identical payload duplicate is a no-op; conflicting payload is rejected, not silently overwritten। Negative count/type/calendar/availability checks precede insert। Chunk changes logical grouping, not throughput or exactly-once network semantics.',
            style: _bn,
          ),
          _gap,
          Text(
            'Saved independent parity audit:\n${stats['snapshots']} snapshots × batch/incremental/SQLite\nParity failures ${stats['parity_failures']}\nRetrospective availability-ignoring mismatches ${stats['retrospective_mismatch_snapshots']}\nMissing lag1 snapshots ${stats['missing_lag1']}',
            style: _bn,
          ),
          _gap,
          const Text(
            'SQLite rollback/crash-and-retry is tested in the companion pipeline। At-least-once delivery + idempotent sink is not universal exactly-once processing; checkpoints, external side effects and concurrency need separate design.',
            style: _bn,
          ),
          _gap,
          OutlinedButton(
            onPressed: () => setState(() {
              duplicates = false;
              invalid = false;
              chunk = 32;
            }),
            child: const Text('Reset pipeline replay'),
          ),
          _gap,
          _source,
        ],
      ),
    );
  });
}

class FeatureConsistencyLab extends StatefulWidget {
  const FeatureConsistencyLab({super.key});
  @override
  State<FeatureConsistencyLab> createState() => _FeatureConsistencyLabState();
}

class _FeatureConsistencyLabState extends State<FeatureConsistencyLab> {
  final data = FeatureSystemAssets.load();
  String fault = 'none';
  bool latest = false;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final expected = a.manifest('late_fixture'), loaded = {...expected};
    if (fault != 'none') loaded[fault] = 'incompatible-software-fixture';
    final errors = featureContractErrors(expected, loaded),
        offline = pointInTimeFeatures(a.events('late_fixture'), 375),
        serving = guardedPointInTimeFeatures(
          a.events('late_fixture'),
          375,
          expected,
          loaded,
          latest: latest,
        ),
        diff = serving == null
            ? <String>[]
            : featureDifference(offline, serving);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'ML SYSTEMS & INTERVIEWS · CHAPTER 01 · FEATURE CONSISTENCY',
            icon: Icons.rule_outlined,
          ),
          _gap,
          const Text('Match the contract before serving.', style: _title),
          _gap,
          const Text(
            'Actual source window at2012-01-11, declared late schedule। Historical training/serving reference uses the same cutoff,definition,null policy and entity key। Metadata mismatch is an injected software fault; latest-state toggle intentionally demonstrates skew, not an executed online service.',
            style: _bn,
          ),
          _gap,
          DropdownButtonFormField<String>(
            key: ValueKey('feature-fault-$fault'),
            initialValue: fault,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Declared feature contract fault',
            ),
            items: [
              for (final f in [
                'none',
                'feature_version',
                'definition_sha256',
                'source_sha256',
                'availability_rule',
                'entity_key',
              ])
                DropdownMenuItem(value: f, child: Text(f)),
            ],
            onChanged: (v) => setState(() => fault = v!),
          ),
          _gap,
          SwitchListTile(
            key: const Key('feature-serving-latest'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Serve retrospective latest · declared skew bug'),
            value: latest,
            onChanged: (v) => setState(() => latest = v),
          ),
          _gap,
          Text(
            errors.isNotEmpty
                ? 'Feature contract: BLOCKED · ${errors.join(', ')}'
                : 'Feature contract: READY',
            style: _bn,
          ),
          _gap,
          if (serving == null)
            const Text(
              'Lookup blocked before feature computation. Load a compatible definition/source/availability contract; changing a hash label does not validate actual bytes.',
              style: _bn,
            )
          else ...[
            Text(
              'Consistency: ${diff.isEmpty ? 'PARITY' : 'SKEW'}\nDifferent fields: ${diff.isEmpty ? 'none' : diff.join(', ')}',
              style: _bn,
            ),
            _gap,
            const Text('Historical point-in-time reference', style: _bn),
            _vector(offline),
            _gap,
            const Text('Local serving inspection', style: _bn),
            _vector(serving),
            _gap,
          ],
          Text(
            'Feature version ${expected['feature_version']}\nEntity ${expected['entity_key']}\nAvailability ${expected['availability_rule']}',
            style: _bn,
          ),
          _gap,
          const Text(
            'Matching implementations can share the same bug। Independent SQL/direct/incremental tests and explicit boundary/null cases are needed। Companion export includes a real SQLite feature store,definition,source attribution and checksums; CLI verifies actual bytes and database integrity.',
            style: _bn,
          ),
          _gap,
          OutlinedButton(
            onPressed: () => setState(() {
              fault = 'none';
              latest = false;
            }),
            child: const Text('Reset feature consistency'),
          ),
          _gap,
          _source,
        ],
      ),
    );
  });
}
