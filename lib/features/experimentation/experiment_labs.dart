import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import 'experiment_model.dart';

const _space = SizedBox(height: 16),
    _bn = TextStyle(fontFamily: 'NotoSansBengali', height: 1.8),
    _heading = TextStyle(fontSize: 24, fontWeight: FontWeight.w800);
String _number(num? n) => n == null ? 'undefined' : n.toStringAsFixed(3);
const _source = Text(
  'Real historical NSW: 185 treated / 260 experimental controls; PSID: 2490 external controls। LaLonde (1986), Dehejia & Wahba (1999, 2002); CC BY-NC 2.0। Original files unchanged। Row keys স্থানীয় ordinals, participant IDs নয়। Retrospective teaching analysis; live experiment বা current policy advice নয়।',
  style: _bn,
);
Widget _asset(
  Future<ExperimentAssets> future,
  Widget Function(ExperimentAssets) body,
) => FutureBuilder<ExperimentAssets>(
  future: future,
  builder: (context, s) => s.hasError
      ? const Panel(
          child: Text('Bundled experiment evidence could not be loaded.'),
        )
      : s.hasData
      ? body(s.data!)
      : const Center(child: CircularProgressIndicator()),
);

class TrialInferenceLab extends StatefulWidget {
  const TrialInferenceLab({super.key});
  @override
  State<TrialInferenceLab> createState() => _TrialInferenceLabState();
}

class _TrialInferenceLabState extends State<TrialInferenceLab> {
  final data = ExperimentAssets.load();
  String outcome = 'earnings';
  double confidence = .95;
  int draws = 1000;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final trial = a.trial(outcome, confidence),
        nullAudit = a.randomization(outcome, draws),
        factor = outcome == 'positive' ? 100 : 1,
        unit = outcome == 'positive'
            ? 'percentage points'
            : 'source monetary units';
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'ML SYSTEMS & INTERVIEWS · CHAPTER 03 · RANDOMIZED CONTRAST',
            icon: Icons.science_outlined,
          ),
          _space,
          const Text(
            'Estimate the contrast. Keep uncertainty visible.',
            style: _heading,
          ),
          _space,
          const Text(
            'প্রকাশিত Experiment Subset-এর বাস্তব Outcome থেকে Mean Contrast, Unbiased Variance আর Welch SE/df আবার হিসাব করি। SciPy reference t-critical/p-value bundled। 1978 earnings-এর monetary units অপরিবর্তিত। Positive মানে re78>0; এটি আলাদাভাবে measured employment status নয়।',
            style: _bn,
          ),
          _space,
          Wrap(
            spacing: 12,
            children: [
              for (final k in experimentOutcomes)
                ChoiceChip(
                  key: Key('trial-outcome-$k'),
                  label: Text(
                    k == 'earnings' ? '1978 earnings' : 'Positive earnings',
                  ),
                  selected: outcome == k,
                  onSelected: (_) => setState(() => outcome = k),
                ),
            ],
          ),
          _space,
          Text('Confidence level: ${(confidence * 100).round()}%'),
          Wrap(
            spacing: 12,
            children: [
              for (final c in experimentConfidences)
                ChoiceChip(
                  key: Key('trial-confidence-$c'),
                  label: Text('${(c * 100).round()}%'),
                  selected: confidence == c,
                  onSelected: (_) => setState(() => confidence = c),
                ),
            ],
          ),
          _space,
          Text(
            'Observed contrast: ${_number(trial['delta'] * factor)} $unit\nWelch ${(confidence * 100).round()}% CI: [${_number(trial['lower'] * factor)}, ${_number(trial['upper'] * factor)}]\nSE ${_number(trial['se'] * factor)} · df ${_number(trial['df'])}\nTreated ${trial['treated']['n']} · control ${trial['control']['n']}\nMeans ${_number(trial['treated']['mean'])} / ${_number(trial['control']['mean'])}\nWelch two-sided p ${_number(trial['p_value'])}',
            style: _bn,
          ),
          _space,
          const Text(
            'Welch interval approximate sampling inference; randomization alone exact finite-sample t distribution দেয় না। CI parameter-এর probability নয়। Binary outcome-এর এই interval difference-of-means approximation; individual Bernoulli outcome model নয়।',
            style: _bn,
          ),
          _space,
          Text('Randomization draws: $draws'),
          Wrap(
            spacing: 12,
            children: [
              for (final n in [100, 500, 1000])
                ChoiceChip(
                  key: Key('trial-draws-$n'),
                  label: Text('$n'),
                  selected: draws == n,
                  onSelected: (_) => setState(() => draws = n),
                ),
            ],
          ),
          _space,
          _NullHistogram(audit: nullAudit, observed: trial['delta']),
          _space,
          Text(
            'Randomization tail: ${nullAudit['extreme']} / $draws\nPlus-one p ${_number(nullAudit['p_value'])} · approximate MC SE ${_number(nullAudit['mc_se'])}',
            style: _bn,
          ),
          _space,
          const Text(
            'Actual fixed outcomes, repeated label allocations under a sharp-zero-effect null। App saved allocation indices থেকে সব mean contrasts recompute করে। Absolute two-sided tail, plus-one correction; exact enumeration নয়। Original assignment protocol recovered হয়নি—এটি conditional complete-randomization illustration, নতুন source observations বা original trial re-run নয়। Prefix draws একই bank-এর nested views; p-value ভালো না হওয়া পর্যন্ত draw count বেছে নেওয়া valid protocol নয়।',
            style: _bn,
          ),
          _space,
          OutlinedButton(
            onPressed: () => setState(() {
              outcome = 'earnings';
              confidence = .95;
              draws = 1000;
            }),
            child: const Text('Reset trial inference'),
          ),
          _space,
          _source,
        ],
      ),
    );
  });
}

class _NullHistogram extends StatelessWidget {
  final Map<String, dynamic> audit;
  final double observed;
  const _NullHistogram({required this.audit, required this.observed});
  @override
  Widget build(BuildContext context) {
    final bins = List<int>.from(audit['bins']),
        peak = bins.reduce((a, b) => a > b ? a : b),
        lo = (audit['minimum'] as num).toDouble(),
        hi = (audit['maximum'] as num).toDouble(),
        position = hi == lo
            ? .5
            : ((observed - lo) / (hi - lo)).clamp(0.0, 1.0),
        colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 190,
      child: LayoutBuilder(
        builder: (context, c) => Stack(
          children: [
            const Align(
              alignment: Alignment.topLeft,
              child: Text('Sharp-null contrast distribution · line = observed'),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 30,
              bottom: 32,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final n in bins)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Container(
                          height: peak == 0 ? 0 : 120 * n / peak,
                          color: colors.primary.withValues(alpha: .7),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              left: position * (c.maxWidth - 2),
              top: 25,
              bottom: 27,
              child: Container(width: 2, color: colors.tertiary),
            ),
            Align(alignment: Alignment.bottomLeft, child: Text(_number(lo))),
            Align(alignment: Alignment.bottomRight, child: Text(_number(hi))),
          ],
        ),
      ),
    );
  }
}

class ExperimentDesignLab extends StatefulWidget {
  const ExperimentDesignLab({super.key});
  @override
  State<ExperimentDesignLab> createState() => _ExperimentDesignLabState();
}

class _ExperimentDesignLabState extends State<ExperimentDesignLab> {
  final data = ExperimentAssets.load();
  int delta = 2000, size = 1;
  double allocation = .5, alpha = .05, power = .8, icc = 0;
  bool loss = false;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final plan = a.plan(
          delta: delta,
          allocation: allocation,
          alpha: alpha,
          power: power,
          clusterSize: size,
          icc: icc,
        ),
        logging = experimentLogging(a.trialRows, loss: loss);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'ML SYSTEMS & INTERVIEWS · CHAPTER 03 · DESIGN & QUALITY GATES',
            icon: Icons.calculate_outlined,
          ),
          _space,
          const Text('Plan sensitivity before the test.', style: _heading),
          _space,
          const Text(
            'Prospective common-variance normal approximation; historical control earnings SD শুধু planning plug-in। MDE, allocation, alpha ও power assumptions বদলে independent-unit sample requirement দেখুন। Observed effect বসিয়ে post-hoc power দিয়ে result certify করা হয় না।',
            style: _bn,
          ),
          _space,
          Text('Minimum detectable effect: $delta source units'),
          Wrap(
            spacing: 12,
            children: [
              for (final d in [1000, 2000, 4000])
                ChoiceChip(
                  key: Key('design-mde-$d'),
                  label: Text('$d'),
                  selected: delta == d,
                  onSelected: (_) => setState(() => delta = d),
                ),
            ],
          ),
          _space,
          Text('Treatment allocation: ${(allocation * 100).round()}%'),
          Wrap(
            spacing: 12,
            children: [
              for (final r in [.4, .5, .7])
                ChoiceChip(
                  key: Key('design-allocation-$r'),
                  label: Text('${(r * 100).round()}%'),
                  selected: allocation == r,
                  onSelected: (_) => setState(() => allocation = r),
                ),
            ],
          ),
          _space,
          Text('Two-sided alpha: $alpha'),
          Wrap(
            spacing: 12,
            children: [
              for (final v in [.05, .01])
                ChoiceChip(
                  key: Key('design-alpha-$v'),
                  label: Text('$v'),
                  selected: alpha == v,
                  onSelected: (_) => setState(() => alpha = v),
                ),
            ],
          ),
          _space,
          Text('Target power: ${(power * 100).round()}%'),
          Wrap(
            spacing: 12,
            children: [
              for (final v in [.8, .9])
                ChoiceChip(
                  key: Key('design-power-$v'),
                  label: Text('${(v * 100).round()}%'),
                  selected: power == v,
                  onSelected: (_) => setState(() => power = v),
                ),
            ],
          ),
          _space,
          Text('Cluster size assumption: $size'),
          Wrap(
            spacing: 12,
            children: [
              for (final n in [1, 5, 10])
                ChoiceChip(
                  key: Key('design-cluster-$n'),
                  label: Text('$n'),
                  selected: size == n,
                  onSelected: (_) => setState(() => size = n),
                ),
            ],
          ),
          _space,
          Text('ICC assumption: $icc'),
          Wrap(
            spacing: 12,
            children: [
              for (final r in [0.0, .05, .2])
                ChoiceChip(
                  key: Key('design-icc-$r'),
                  label: Text('$r'),
                  selected: icc == r,
                  onSelected: (_) => setState(() => icc = r),
                ),
            ],
          ),
          _space,
          Text(
            'Required independent units: ${plan['total']}\nTreated ${plan['treated']} · control ${plan['control']}\nAchieved normal power ${_number(plan['achieved_normal_power'])}\nPlanning SD ${_number(plan['sigma'])}\nDesign effect ${_number(plan['design_effect'])}\nAdjusted planning units ${plan['adjusted_units']} · approximate clusters ${plan['clusters']}',
            style: _bn,
          ),
          _space,
          const Text(
            'DE=1+(m−1)ICC equal-cluster planning formula; actual NSW cluster IDs/ICC নেই। এটি cluster-robust analysis নয়। Many units in few clusters independent evidence নয়; unequal cluster sizes, attrition, spillover ও small-cluster inference আলাদা design চায়।',
            style: _bn,
          ),
          _space,
          SwitchListTile(
            key: const Key('design-logging-loss'),
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Inject treatment-dependent logging loss · software fixture',
            ),
            value: loss,
            onChanged: (v) => setState(() => loss = v),
          ),
          _space,
          Text(
            'Logging rehearsal: ${loss ? 'LOSS INJECTED' : 'COMPLETE'}\nObserved ${logging['observed_units']} / ${logging['source_units']} ordinal source keys\nControl ${logging['control']} · treatment ${logging['treated']} · dropped ${logging['dropped']}\nExpected fixture allocation 50/50 · chi-square ${_number(logging['chi_square'])}\np ${logging['p_value'].toStringAsFixed(6)} · SRM flag ${logging['flag']}',
            style: _bn,
          ),
          _space,
          const Text(
            'Rehearsal source keys নতুন hash policy-তে assign করে, original NSW treatment ব্যবহার করে না। Loss একটি authored logging bug। Original trial-এর configured ratio/logs নেই, তাই 185/260 দেখে 50/50 SRM test করা invalid। Non-rejection quality proof নয়; source assignment, exposure ও outcome joins আলাদা audit লাগে।',
            style: _bn,
          ),
          _space,
          OutlinedButton(
            onPressed: () => setState(() {
              delta = 2000;
              size = 1;
              allocation = .5;
              alpha = .05;
              power = .8;
              icc = 0;
              loss = false;
            }),
            child: const Text('Reset experiment design'),
          ),
          _space,
          _source,
        ],
      ),
    );
  });
}

class ObservationalAuditLab extends StatefulWidget {
  const ObservationalAuditLab({super.key});
  @override
  State<ObservationalAuditLab> createState() => _ObservationalAuditLabState();
}

class _ObservationalAuditLabState extends State<ObservationalAuditLab> {
  final data = ExperimentAssets.load();
  String comparison = 'psid', outcome = 'earnings';
  bool adjust = false;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final audit = a.observational(
          comparison: comparison,
          outcome: outcome,
          adjust: adjust,
        ),
        factor = outcome == 'positive' ? 100 : 1;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'ML SYSTEMS & INTERVIEWS · CHAPTER 03 · OBSERVATIONAL LIMITS',
            icon: Icons.rule_outlined,
          ),
          _space,
          const Text(
            'Change the comparison. Audit the assumptions.',
            style: _heading,
          ),
          _space,
          const Text(
            'Same 185 treated units; experimental control ও external PSID controls-এর observed outcomes তুলুন। PSID sample treatment assignment randomize করে না। Raw বা adjusted gap নিজে থেকে identified causal effect নয়। Experimental estimate-ও finite-sample uncertainty-সহ benchmark, known individual ground truth নয়।',
            style: _bn,
          ),
          _space,
          Wrap(
            spacing: 12,
            children: [
              for (final s in ['experimental', 'psid'])
                ChoiceChip(
                  key: Key('observational-comparison-$s'),
                  label: Text(
                    s == 'experimental'
                        ? 'Experimental controls'
                        : 'External PSID controls',
                  ),
                  selected: comparison == s,
                  onSelected: (_) => setState(() => comparison = s),
                ),
            ],
          ),
          _space,
          Wrap(
            spacing: 12,
            children: [
              for (final k in experimentOutcomes)
                ChoiceChip(
                  key: Key('observational-outcome-$k'),
                  label: Text(
                    k == 'earnings' ? '1978 earnings' : 'Positive earnings',
                  ),
                  selected: outcome == k,
                  onSelected: (_) => setState(() => outcome = k),
                ),
            ],
          ),
          _space,
          SwitchListTile(
            key: const Key('observational-adjust'),
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Standardize two pre74-positive strata to treated composition',
            ),
            value: adjust,
            onChanged: (v) => setState(() => adjust = v),
          ),
          _space,
          Text(
            'Comparison: $comparison\nTreated ${audit['treated']} · controls ${audit['control']}\nRaw observed gap ${_number(audit['raw_gap'] * factor)}\nShown ${adjust ? 'stratified descriptive' : 'raw descriptive'} gap ${_number(audit['shown_gap'] == null ? null : audit['shown_gap'] * factor)}\nUnits: ${outcome == 'positive' ? 'percentage points' : 'source monetary units'}\nBoth coarse strata occupied: ${audit['empirical_overlap']}',
            style: _bn,
          ),
          _space,
          for (final row in audit['strata'])
            Text(
              'Pre74 positive: ${row['prior_positive']}\nTreated ${row['treated']} / controls ${row['control']} · target weight ${_number(row['weight'])}\nWithin-stratum observed gap ${_number(row['gap'] == null ? null : row['gap'] * factor)}\n',
              style: _bn,
            ),
          const Text(
            'Pre-treatment balance · standardized mean differences',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          _space,
          for (final k in ['age', 'education', 're74', 're75']) ...[
            Text('$k: ${_number(audit['smd'][k])}'),
            const SizedBox(height: 5),
            LinearProgressIndicator(
              value:
                  ((audit['smd'][k] as num?)?.abs() ?? 0).clamp(0.0, 2.0) / 2,
              minHeight: 7,
            ),
            _space,
          ],
          const Text(
            'Bars |SMD| capped at2 for display; text keeps actual signed value। Formula uses average within-group variances। Occupied two coarse bins no-hidden-confounding বা full overlap prove করে না। Stratum weights treated population-এর, তাই adjusted contrast ATT-like; raw experimental contrast-এর weighting আলাদা। Outcome/mediator/collider দিয়ে adjust নয়।',
            style: _bn,
          ),
          _space,
          const Text(
            'Identification checklist: well-defined intervention ও consistency, relevant-population exchangeability, positivity, no interference/appropriate design, measurement ও selection assumptions। Current coarse adjustment একটি transparent descriptive audit; matching/IPW/DML বা observational causal claim এখানে implement করা হয়নি।',
            style: _bn,
          ),
          _space,
          OutlinedButton(
            onPressed: () => setState(() {
              comparison = 'psid';
              outcome = 'earnings';
              adjust = false;
            }),
            child: const Text('Reset observational audit'),
          ),
          _space,
          _source,
        ],
      ),
    );
  });
}
