import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import 'evaluation_model.dart';

const _gap = SizedBox(height: 16),
    _bn = TextStyle(fontFamily: 'NotoSansBengali', height: 1.8),
    _title = TextStyle(fontSize: 24, fontWeight: FontWeight.w800);
String _n(num? x) => x == null ? 'undefined' : x.toStringAsFixed(4);
const _source = Text(
  'বাস্তব MovieLens / GroupLens · source license/attribution bundled; non-commercial conditions প্রযোজ্য। Frozen Chapter32 models, inspected diagnostics; no retraining, exposure correction বা online experiment। Genre metadata full2018 snapshot, historically versioned নয়।',
  style: _bn,
);
Widget _asset(
  Future<RecommendationEvaluationAssets> f,
  Widget Function(RecommendationEvaluationAssets) body,
) => FutureBuilder<RecommendationEvaluationAssets>(
  future: f,
  builder: (c, s) => s.hasError
      ? const Panel(
          child: Text('Bundled evaluation evidence could not be read.'),
        )
      : !s.hasData
      ? const Center(child: CircularProgressIndicator())
      : body(s.data!),
);

class PairedEvaluationLab extends StatefulWidget {
  const PairedEvaluationLab({super.key});
  @override
  State<PairedEvaluationLab> createState() => _PairedEvaluationLabState();
}

class _PairedEvaluationLabState extends State<PairedEvaluationLab> {
  final data = RecommendationEvaluationAssets.load();
  String pair = 'neural50:user_cf:recall', scope = 'warm', window = 'full';
  double confidence = .95;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final ci = a.interval(pair, confidence: confidence),
        rows = window == 'full'
            ? a.data['rows']
            : a.data['windows'][window]['rows'];
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'RECOMMENDER SYSTEMS · CHAPTER 04 · PAIRED EVALUATION',
            icon: Icons.analytics_outlined,
          ),
          _gap,
          const Text(
            'Compare the same users. Keep the uncertainty.',
            style: _title,
          ),
          _gap,
          const Text(
            'একই Warm User-দের Treatment−Control Metric-এর পার্থক্য থেকে 5000টি Paired User Bootstrap Replicate তৈরি হয়েছে। Seed 33। Model/split fixed; interval training randomness, temporal shift, exposure bias বা causal uplift মাপে না। এটি inspected diagnostic, fresh confirmation নয়।',
            style: _bn,
          ),
          _gap,
          DropdownButtonFormField<String>(
            key: ValueKey('eval-pair-$pair'),
            initialValue: pair,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Fixed full-window paired comparison',
            ),
            items: [
              for (final key in (a.data['paired'] as Map).keys)
                DropdownMenuItem(value: key as String, child: Text(key)),
            ],
            onChanged: (v) => setState(() => pair = v!),
          ),
          _gap,
          Text('Confidence: ${(confidence * 100).round()}%'),
          Wrap(
            spacing: 12,
            children: [
              for (final c in [.9, .95, .99])
                ChoiceChip(
                  key: Key('eval-confidence-$c'),
                  label: Text('${(c * 100).round()}%'),
                  selected: confidence == c,
                  onSelected: (_) => setState(() => confidence = c),
                ),
            ],
          ),
          _gap,
          Text(
            'Paired users: ${ci['users']}\nMean difference: ${_n(ci['mean'])}\nPercentile interval: [${_n(ci['low'])}, ${_n(ci['high'])}]\nZero inside: ${ci['low']! <= 0 && ci['high']! >= 0}',
            style: _bn,
          ),
          _gap,
          Semantics(
            label:
                'Treatment minus control; interval ${_n(ci['low'])} to ${_n(ci['high'])}, mean ${_n(ci['mean'])}; vertical line marks zero.',
            child: SizedBox(
              height: 90,
              width: double.infinity,
              child: CustomPaint(
                painter: _DifferencePainter(
                  low: ci['low']!.toDouble(),
                  high: ci['high']!.toDouble(),
                  mean: ci['mean']!.toDouble(),
                  colors: Theme.of(context).colorScheme,
                ),
              ),
            ),
          ),
          const Text(
            'Treatment − control · dot = paired mean · band = percentile interval · vertical line = zero',
          ),
          _gap,
          const Text(
            'Interval control uses stored real bootstrap replicates and linear quantiles; no new RNG in app। Multiple comparisons unadjusted। Confidence বদলে winner খোঁজা বা interval-কে probability of model superiority বলা ঠিক নয়।',
            style: _bn,
          ),
          _gap,
          DropdownButtonFormField<String>(
            key: ValueKey('eval-window-$window'),
            initialValue: window,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Frozen prediction window audit',
            ),
            items: [
              for (final v in ['full', 'early', 'late'])
                DropdownMenuItem(value: v, child: Text(v)),
            ],
            onChanged: (v) => setState(() => window = v!),
          ),
          _gap,
          DropdownButtonFormField<String>(
            key: ValueKey('eval-scope-$scope'),
            initialValue: scope,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Target cohort'),
            items: [
              for (final v in ['warm', 'broad', 'cold'])
                DropdownMenuItem(value: v, child: Text(v)),
            ],
            onChanged: (v) => setState(() => scope = v!),
          ),
          _gap,
          Text('Scorecard: $window window / $scope cohort', style: _bn),
          for (final method in ['neural50', 'user_cf', 'mmr1', 'mmr0.5'])
            Builder(
              builder: (_) {
                final s = evaluationScore(rows, method, scope: scope);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    '$method · ${s['users']} users\nP@10 ${_n(s['precision'])} · R@10 ${_n(s['recall'])}\nNDCG@10 ${_n(s['ndcg'])} · MRR@10 ${_n(s['mrr'])}',
                    style: _bn,
                  ),
                );
              },
            ),
          const Text(
            'Window/cohort controls change scorecard denominator, not paired CI above। Frozen predictions across early/late periods, no online updates; eligible users differ। Cold MMR diversity policy differs from Chapter32 neural bypass. Empty cohort remains undefined.',
            style: _bn,
          ),
          _gap,
          OutlinedButton(
            onPressed: () => setState(() {
              pair = 'neural50:user_cf:recall';
              scope = 'warm';
              window = 'full';
              confidence = .95;
            }),
            child: const Text('Reset paired evaluation'),
          ),
          _gap,
          _source,
        ],
      ),
    );
  });
}

class DiversityRerankingLab extends StatefulWidget {
  const DiversityRerankingLab({super.key});
  @override
  State<DiversityRerankingLab> createState() => _DiversityRerankingLabState();
}

class _DiversityRerankingLabState extends State<DiversityRerankingLab> {
  final data = RecommendationEvaluationAssets.load();
  int? user;
  double strength = 1;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final samples = a.data['samples'] as List;
    user ??= samples.first['user'];
    final sample = samples.firstWhere((s) => s['user'] == user),
        ids = List<int>.from(sample['candidates']),
        scores = (sample['scores'] as List)
            .map((v) => (v as num).toDouble())
            .toList(),
        run = a.mmr(ids, scores, strength: strength),
        quality = a.listQuality(run.ranked),
        row = (a.data['rows'] as List).firstWhere((r) => r['user'] == user),
        gold = List<int>.from(row['eligible']),
        metrics = evaluationMetrics(run.ranked, gold),
        method = 'mmr${strength == 1 ? '1' : strength}',
        global = a.diversity(method),
        score = evaluationScore(a.data['rows'], method);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'RECOMMENDER SYSTEMS · CHAPTER 04 · DIVERSITY RERANKING',
            icon: Icons.hub_outlined,
          ),
          _gap,
          const Text('Trade relevance against redundancy.', style: _title),
          _gap,
          const Text(
            'Same Chapter32 neural100 candidate pool, no gold in policy। Relevance = pool minmax ranker logit; redundancy = maximum genre cosine against already selected items। Greedy MMR, rounded12-decimal key then movieId tie। More diverse genre lists are not automatically more useful or fair.',
            style: _bn,
          ),
          _gap,
          DropdownButtonFormField<int>(
            key: ValueKey('diversity-user-$user'),
            initialValue: user,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Original source user',
            ),
            items: [
              for (final s in samples)
                DropdownMenuItem(
                  value: s['user'] as int,
                  child: Text(
                    'User ${s['user']} · ${s['fallback'] ? 'cold popularity scores' : 'warm ranker logits'}',
                  ),
                ),
            ],
            onChanged: (v) => setState(() => user = v),
          ),
          _gap,
          Text('MMR relevance weight: ${strength.toStringAsFixed(2)}'),
          Wrap(
            spacing: 12,
            children: [
              for (final v in [1.0, .75, .5])
                ChoiceChip(
                  key: Key('mmr-weight-$v'),
                  label: Text('λ $v'),
                  selected: strength == v,
                  onSelected: (_) => setState(() => strength = v),
                ),
            ],
          ),
          _gap,
          Text(
            'Source user: ILD ${_n(quality['ild'])} · novelty ${_n(quality['novelty_bits'])} bits\nEligible Recall@10 ${_n(metrics['recall'])} · NDCG@10 ${_n(metrics['ndcg'])}',
            style: _bn,
          ),
          for (var j = 0; j < run.ranked.length; j++) ...[
            Text(
              '${j + 1}. ${a.base.movies[run.ranked[j]]!.title}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              '${a.base.movies[run.ranked[j]]!.genres.join(' / ')}\nnormalized relevance ${_n(run.trace[j]['relevance'])} · redundancy ${_n(run.trace[j]['redundancy'])} · greedy utility ${_n(run.trace[j]['utility'])}',
              style: _bn,
            ),
            _gap,
          ],
          Text(
            'Fixed warm cohort: ${score['users']} users\nRecall@10 ${_n(score['recall'])} · NDCG@10 ${_n(score['ndcg'])}\nMean ILD ${_n(global['ild'])} · novelty ${_n(global['novelty_bits'])} bits\nCatalog coverage ${_n(global['catalog_coverage'])} · recommendation entropy ${_n(global['recommendation_entropy_bits'])} bits',
            style: _bn,
          ),
          _gap,
          const Text(
            'Novelty uses smoothed fit positive counts; historical rarity, not personalized surprise। Entropy counts planned recommendation slots, not measured impressions। Cold inspection applies MMR to popularity scores, a declared changed policy; warm aggregate excludes cold. λ1/.75/.5 fixed presets, not tuned winners.',
            style: _bn,
          ),
          _gap,
          OutlinedButton(
            onPressed: () => setState(() {
              user = samples.first['user'];
              strength = 1;
            }),
            child: const Text('Reset diversity reranking'),
          ),
          _gap,
          _source,
        ],
      ),
    );
  });
}

class _DifferencePainter extends CustomPainter {
  final double low, high, mean;
  final ColorScheme colors;
  const _DifferencePainter({
    required this.low,
    required this.high,
    required this.mean,
    required this.colors,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final minimum = low < -.01 ? low : -.01;
    final maximum = high > .01 ? high : .01;
    final span = maximum - minimum,
        left = minimum - span * .1,
        right = maximum + span * .1;
    double x(double value) =>
        16 + (value - left) / (right - left) * (size.width - 32);
    final y = size.height / 2;
    canvas.drawLine(
      Offset(16, y),
      Offset(size.width - 16, y),
      Paint()
        ..color = colors.outlineVariant
        ..strokeWidth = 2,
    );
    canvas.drawLine(
      Offset(x(0), 12),
      Offset(x(0), size.height - 12),
      Paint()
        ..color = colors.onSurfaceVariant
        ..strokeWidth = 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(x(low), y - 8, x(high), y + 8),
        const Radius.circular(8),
      ),
      Paint()..color = colors.primary.withValues(alpha: .3),
    );
    canvas.drawLine(
      Offset(x(low), y),
      Offset(x(high), y),
      Paint()
        ..color = colors.primary
        ..strokeWidth = 3,
    );
    canvas.drawCircle(Offset(x(mean), y), 6, Paint()..color = colors.primary);
  }

  @override
  bool shouldRepaint(covariant _DifferencePainter old) =>
      low != old.low ||
      high != old.high ||
      mean != old.mean ||
      colors != old.colors;
}

class ExposureExperimentLab extends StatefulWidget {
  const ExposureExperimentLab({super.key});
  @override
  State<ExposureExperimentLab> createState() => _ExposureExperimentLabState();
}

class _ExposureExperimentLabState extends State<ExposureExperimentLab> {
  bool clipped = false;
  double mde = .01;
  @override
  Widget build(BuildContext context) {
    final f = evaluationPropensity(clip: clipped ? 2 : null),
        n = evaluationSampleSize(mde: mde);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'RECOMMENDER SYSTEMS · CHAPTER 04 · EXPOSURE & EXPERIMENTS',
            icon: Icons.science_outlined,
          ),
          _gap,
          const Text(
            'Declare the logging policy. Plan the experiment.',
            style: _title,
          ),
          _gap,
          const Text(
            'MATHEMATICAL FIXTURE · four authored rows, not MovieLens logs or an executed A/B test। MovieLens has no impression propensities; empirical IPS/causal lift is not identifiable from these files। Logged action,reward,probability and target-policy match below are explicit teaching assumptions.',
            style: _bn,
          ),
          _gap,
          const Text(
            'Context0: logged A · p=.8 · reward1 · target A\nContext1: logged B · p=.2 · reward1 · target B\nContext2: logged A · p=.8 · reward0 · target B\nContext3: logged B · p=.2 · reward0 · target A',
            style: _bn,
          ),
          _gap,
          SwitchListTile(
            key: const Key('exposure-clip'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Clip importance weights at 2'),
            value: clipped,
            onChanged: (v) => setState(() => clipped = v),
          ),
          Text(
            'Weights: ${(f['weights'] as List).map((v) => _n(v)).join(', ')}\nNaive logged reward ${_n(f['naive'])}\nIPS ${_n(f['ips'])} · SNIPS ${_n(f['snips'])}\nEffective sample size ${_n(f['ess'])} / 4',
            style: _bn,
          ),
          _gap,
          const Text(
            'Finite-sample IPS may exceed1; that is not a calibrated probability। SNIPS normalizes weights and is finite-sample biased; clipping trades bias for variance. Positivity, correct logged propensities, consistency and appropriate causal assumptions still required. Slate propensity is not a product of marginals without a factorization assumption.',
            style: _bn,
          ),
          _gap,
          const Text(
            'A/B PLANNING ASSUMPTIONS · baseline binary rate.10, absolute MDE, two-sidedα≈.05 (z1.96), power≈.80 (z.84), equal independent arms। Normal approximation, fixed horizon; no experiment run, no observed significance.',
            style: _bn,
          ),
          _gap,
          Text(
            'Absolute MDE: ${(mde * 100).toStringAsFixed(1)} percentage points',
          ),
          Wrap(
            spacing: 12,
            children: [
              for (final v in [.005, .01, .02])
                ChoiceChip(
                  key: Key('experiment-mde-$v'),
                  label: Text('${(v * 100).toStringAsFixed(1)} pp'),
                  selected: mde == v,
                  onSelected: (_) => setState(() => mde = v),
                ),
            ],
          ),
          _gap,
          Text(
            'Approximate users per arm: $n\nTotal independent users: ${2 * n}',
            style: _bn,
          ),
          const Text(
            'Plan unit/user randomization,primary metric/guardrails,SRM,exposure logging,telemetry loss,interference and stopping rule before launch। Repeated looks need a valid sequential design. Sample-size arithmetic is not launch approval or a precision guarantee; clustered outcomes/design effects need a new calculation.',
            style: _bn,
          ),
          _gap,
          OutlinedButton(
            onPressed: () => setState(() {
              clipped = false;
              mde = .01;
            }),
            child: const Text('Reset exposure experiment'),
          ),
          _gap,
          _source,
        ],
      ),
    );
  }
}
