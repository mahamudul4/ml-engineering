import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import '../feature_systems/feature_model.dart';
import 'mlops_model.dart';

const _gap = SizedBox(height: 16),
    _bn = TextStyle(fontFamily: 'NotoSansBengali', height: 1.8),
    _title = TextStyle(fontSize: 24, fontWeight: FontWeight.w800);
String _n(num? x) => x == null ? 'undefined' : x.toStringAsFixed(3);
const _source = Text(
  'বাস্তব UCI Bike Sharing · Fanaee-T (2013), CC BY4.0। প্রথম 547 counts/dates; reserved 184 outcomes unused। Real fit/inference/historical diagnostics; arrival, label-delay, routing ও SLO telemetry fixtures স্পষ্টভাবে চিহ্নিত। Production deployment, traffic বা causal lift-এর দাবি নেই।',
  style: _bn,
);
Widget _asset(Future<MLOpsAssets> f, Widget Function(MLOpsAssets) body) =>
    FutureBuilder<MLOpsAssets>(
      future: f,
      builder: (c, s) => s.hasError
          ? const Panel(
              child: Text('Bundled MLOps evidence could not be loaded.'),
            )
          : s.hasData
          ? body(s.data!)
          : const Center(child: CircularProgressIndicator()),
    );

class ReleaseRoutingLab extends StatefulWidget {
  const ReleaseRoutingLab({super.key});
  @override
  State<ReleaseRoutingLab> createState() => _ReleaseRoutingLabState();
}

class _ReleaseRoutingLabState extends State<ReleaseRoutingLab> {
  final data = MLOpsAssets.load();
  int target = 375, bp = 10000;
  String scenario = 'on_time';
  bool fault = false, rollback = false;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final r = a.serve(
          target,
          scenario: scenario,
          canaryBp: bp,
          rollback: rollback,
          candidateFault: fault,
        ),
        replay = a.replay(
          scenario: scenario,
          canaryBp: bp,
          rollback: rollback,
          candidateFault: fault,
        ),
        label = (a.data['rows'] as List).firstWhere(
          (v) => v['target'] == target,
        )['outcome'];
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'ML SYSTEMS & INTERVIEWS · CHAPTER 02 · RELEASE & ROLLBACK',
            icon: Icons.swap_horiz_outlined,
          ),
          _gap,
          const Text('Route the release. Keep a safe fallback.', style: _title),
          _gap,
          const Text(
            'Actual float64 Ridge fit: 2011-এর 358 examples, fixed alpha10। Seasonal7 serving baseline ও naive1 benchmark। App local inference/fallback recompute করে। এখানে Canary দিয়ে তারিখ অনুযায়ী Request Routing-এর মহড়া হয়। Online Randomized Experiment বা Distributed Deployment করা হয়নি।',
            style: _bn,
          ),
          _gap,
          DropdownButtonFormField<int>(
            key: ValueKey('mlops-target-$target'),
            initialValue: target,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Actual historical request',
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
          Text('Candidate traffic: ${(bp / 100).round()}%'),
          Wrap(
            spacing: 12,
            children: [
              for (final n in [0, 1000, 5000, 10000])
                ChoiceChip(
                  key: Key('mlops-canary-$n'),
                  label: Text('${(n / 100).round()}%'),
                  selected: bp == n,
                  onSelected: (_) => setState(() => bp = n),
                ),
            ],
          ),
          _gap,
          Wrap(
            spacing: 12,
            children: [
              for (final s in featureScenarios)
                ChoiceChip(
                  key: Key('mlops-scenario-$s'),
                  label: Text(s),
                  selected: scenario == s,
                  onSelected: (_) => setState(() => scenario = s),
                ),
            ],
          ),
          SwitchListTile(
            key: const Key('mlops-candidate-fault'),
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Inject candidate metadata mismatch · software fixture',
            ),
            value: fault,
            onChanged: (v) => setState(() => fault = v),
          ),
          SwitchListTile(
            key: const Key('mlops-rollback'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Local rollback to validated baseline'),
            value: rollback,
            onChanged: (v) => setState(() => rollback = v),
          ),
          _gap,
          Text(
            'Serving: ${r['served']}\nStatus ${r['status']} · reason ${r['reason']}\nPrediction ${_n(r['prediction'])}\nModel ${r['model_version']} · features ${r['feature_version']}\nRequest bucket ${r['bucket']} / 10000\nRetrospective outcome $label · NEVER an inference input',
            style: _bn,
          ),
          _gap,
          if (r['features'] != null)
            Text(
              [for (final k in mlopsInputFields) '$k: ${_n(r['features'][k])}']
                  .join('\n'),
              style: _bn,
            ),
          _gap,
          Text(
            'Full historical replay: ${replay['requests']} requests\nCandidate ${replay['candidate']} · baseline ${replay['baseline']}\nFallback ${replay['fallback']} · blocked ${replay['blocked']}',
            style: _bn,
          ),
          _gap,
          const Text(
            'FNV1a32(request key)%10000 retries জুড়ে deterministic। Key entity+date; user randomization unit নয়। বাস্তবে Routed Request-এর অনুপাত Threshold-এর সমান নাও হতে পারে। Missing Ridge input বা candidate contract failure-এ independently validated seasonal7 চলে। Bad baseline contract feature computation-এর আগেই block করে। CLI actual bytes verify করে; এই metadata control একটি software fixture।',
            style: _bn,
          ),
          _gap,
          OutlinedButton(
            onPressed: () => setState(() {
              target = 375;
              bp = 10000;
              scenario = 'on_time';
              fault = false;
              rollback = false;
            }),
            child: const Text('Reset release routing'),
          ),
          _gap,
          _source,
        ],
      ),
    );
  });
}

class MonitoringDriftLab extends StatefulWidget {
  const MonitoringDriftLab({super.key});
  @override
  State<MonitoringDriftLab> createState() => _MonitoringDriftLabState();
}

class _MonitoringDriftLabState extends State<MonitoringDriftLab> {
  final data = MLOpsAssets.load();
  String period = 'full', feature = 'lag1';
  int delay = 0;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final drift = a.monitoring(period, feature),
        quality = a.quality(period, delay: delay),
        colors = Theme.of(context).colorScheme;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'ML SYSTEMS & INTERVIEWS · CHAPTER 02 · DRIFT & MATURE LABELS',
            icon: Icons.monitor_heart_outlined,
          ),
          _gap,
          const Text(
            'Separate service health, drift and model quality.',
            style: _title,
          ),
          _gap,
          const Text(
            'Actual rolling one-step historical predictions;model/scaler fit 2011 only, no refit। Drift uses all request inputs;quality uses only labels mature under declared day-close+delay fixture। Outcome clocks are not measured UCI ingestion times. Seasonal patterns/selection limit causal conclusions.',
            style: _bn,
          ),
          _gap,
          DropdownButtonFormField<String>(
            key: ValueKey('mlops-period-$period'),
            initialValue: period,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Historical monitoring period',
            ),
            items: [
              for (final p in mlopsPeriods.keys)
                DropdownMenuItem(value: p, child: Text(p)),
            ],
            onChanged: (v) => setState(() => period = v!),
          ),
          _gap,
          DropdownButtonFormField<String>(
            key: ValueKey('mlops-feature-$feature'),
            initialValue: feature,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Raw feature distribution',
            ),
            items: [
              for (final f in mlopsInputFields)
                DropdownMenuItem(value: f, child: Text(f)),
            ],
            onChanged: (v) => setState(() => feature = v!),
          ),
          _gap,
          Text('Label maturity delay: $delay days'),
          Wrap(
            spacing: 12,
            children: [
              for (final d in [0, 2, 7])
                ChoiceChip(
                  key: Key('mlops-delay-$d'),
                  label: Text('$d days'),
                  selected: delay == d,
                  onSelected: (_) => setState(() => delay = d),
                ),
            ],
          ),
          _gap,
          Text(
            'PSI ${_n(drift['psi'])}\nReference ${drift['reference_count']} fit inputs · monitor ${drift['observed_count']} inputs\nRequest rows ${quality['request_rows']} · mature labels ${quality['mature_labels']}',
            style: _bn,
          ),
          _gap,
          const Text(
            'Bins: fixed fit-only quintile edges; ties ডানের bin-এ যায়। প্রতি bin-এ .5 যোগ করে renormalize করি। Bars reference / monitor probability mass দেখায়; model confidence নয়।',
            style: _bn,
          ),
          _gap,
          for (
            var j = 0;
            j < (drift['reference_bins'] as List).length;
            j++
          ) ...[
            Text(
              'Bin ${j + 1}: ${j == 0 ? '-∞' : _n(drift['edges'][j - 1])} to ${j == (drift['edges'] as List).length ? '∞' : _n(drift['edges'][j])}\nCounts ${drift['reference_bins'][j]} / ${drift['observed_bins'][j]}',
              style: _bn,
            ),
            LinearProgressIndicator(
              value: drift['reference_mass'][j],
              minHeight: 7,
              color: colors.primary,
            ),
            const SizedBox(height: 5),
            LinearProgressIndicator(
              value: drift['observed_mass'][j],
              minHeight: 7,
              color: colors.tertiary,
            ),
            _gap,
          ],
          for (final name in ['naive1', 'baseline', 'candidate'])
            Text(
              '$name · ${quality['models'][name]['labels']} same mature labels\nMAE ${_n(quality['models'][name]['mae'])} · RMSE ${_n(quality['models'][name]['rmse'])}\nMean signed error ${_n(quality['models'][name]['bias'])}\n',
              style: _bn,
            ),
          const Text(
            'PSI is binned univariate distribution change; hypothesis test, concept-drift proof বা automatic retraining instruction নয়। Seasonality-ও drift ঘটাতে পারে। Historical MAE দিয়ে online product lift প্রমাণ হয় না। Mature labels ও feature coverage-এর denominators আলাদা।',
            style: _bn,
          ),
          _gap,
          OutlinedButton(
            onPressed: () => setState(() {
              period = 'full';
              feature = 'lag1';
              delay = 0;
            }),
            child: const Text('Reset monitoring audit'),
          ),
          _gap,
          _source,
        ],
      ),
    );
  });
}

class SLOIncidentLab extends StatefulWidget {
  const SLOIncidentLab({super.key});
  @override
  State<SLOIncidentLab> createState() => _SLOIncidentLabState();
}

class _SLOIncidentLabState extends State<SLOIncidentLab> {
  final data = MLOpsAssets.load();
  int threshold = 100;
  double target = .99;
  bool rehearsed = false;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final s = mlopsSlo(
          a.data['slo']['rows'],
          threshold: threshold,
          target: target,
        ),
        replay = rehearsed ? a.replay(rollback: true) : null;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'ML SYSTEMS & INTERVIEWS · CHAPTER 02 · SLO & INCIDENT REHEARSAL',
            icon: Icons.health_and_safety_outlined,
          ),
          _gap,
          const Text('Count good requests. Rehearse recovery.', style: _title),
          _gap,
          const Text(
            'AUTHORED TELEMETRY FIXTURE · twenty duration/status rows; actual HTTP timings বা production logs নয়। Good=successful AND duration≤threshold। Failure-সহ সব eligible request denominator-এ থাকে। Target/window এখানে teaching assumptions; product requirement থেকে production SLO ঠিক করতে হয়।',
            style: _bn,
          ),
          _gap,
          Text('Latency threshold: $threshold ms'),
          Wrap(
            spacing: 12,
            children: [
              for (final t in [50, 100, 200])
                ChoiceChip(
                  key: Key('mlops-latency-$t'),
                  label: Text('$t ms'),
                  selected: threshold == t,
                  onSelected: (_) => setState(() => threshold = t),
                ),
            ],
          ),
          _gap,
          Text('SLO target: ${(target * 100).toStringAsFixed(1)}%'),
          Wrap(
            spacing: 12,
            children: [
              for (final t in [.95, .99, .999])
                ChoiceChip(
                  key: Key('mlops-slo-$t'),
                  label: Text('${(t * 100).toStringAsFixed(1)}%'),
                  selected: target == t,
                  onSelected: (_) => setState(() => target = t),
                ),
            ],
          ),
          _gap,
          Text(
            'Composite good ${s['good']} / ${s['requests']}\nAvailability ${_n(s['availability'])} · composite SLI ${_n(s['composite_sli'])}\nAllowed bad ${_n(s['allowed_bad'])} · observed bad ${s['bad']}\nRemaining budget ${_n(s['remaining_bad'])} · burn rate ${_n(s['burn_rate'])}x\np95 all ${_n(s['p95_all'])} ms · p95 success-only ${_n(s['p95_success'])} ms',
            style: _bn,
          ),
          _gap,
          for (final bin in s['histogram'])
            Text(
              'Cumulative ≤${bin['le']} ms: ${bin['count']} / ${s['requests']}',
              style: _bn,
            ),
          Text(
            'Cumulative +∞: ${s['requests']} / ${s['requests']}',
            style: _bn,
          ),
          _gap,
          const Text(
            'এখানে exact linear sample quantile দেখানো হয়েছে; histogram quantile interpolation আলাদা। Per-instance p95 average করবেন না। Burn=bad fraction/(1−target); traffic/window assumptions ছাড়া outage duration forecast করা যায় না।',
            style: _bn,
          ),
          _gap,
          FilledButton(
            key: const Key('mlops-rehearse-rollback'),
            onPressed: () => setState(() => rehearsed = true),
            child: const Text('Rehearse local rollback'),
          ),
          _gap,
          if (replay != null)
            Text(
              'Rehearsal: ROLLBACK VERIFIED\n${replay['baseline']} historical requests served by validated baseline\nThis local controller replay is not a production rollback orproof ofincident recovery.',
              style: _bn,
            ),
          _gap,
          const Text(
            'Incident loop:validate telemetry and blast radius→pause rollout/mitigate→verify version, features, fallback and mature outcomes→retain evidence→root cause/action items। Drift alarm alone does not identify cause। Rollback upstream data নিজে repair করে না.',
            style: _bn,
          ),
          _gap,
          OutlinedButton(
            onPressed: () => setState(() {
              threshold = 100;
              target = .99;
              rehearsed = false;
            }),
            child: const Text('Reset SLO rehearsal'),
          ),
          _gap,
          _source,
        ],
      ),
    );
  });
}
