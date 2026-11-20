import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import '../recommendation/recommendation_model.dart';
import 'factor_model.dart';

const _gap = SizedBox(height: 16),
    _bn = TextStyle(fontFamily: 'NotoSansBengali', height: 1.8),
    _title = TextStyle(fontSize: 24, fontWeight: FontWeight.w800);
String _n(num? x) => x == null ? 'undefined' : x.toStringAsFixed(4);
const _source = Text(
  'বাস্তব MovieLens latest-small · GroupLens; original source license ও attribution bundled। Non-commercial conditions প্রযোজ্য। Chapter 30-এর একই 80668 fit/20168 future ratings; 28 warm eligible/116 broad users। Metadata historical version নয়; inspected diagnostics, blind benchmark নয়। No API বা Python execution in app.',
  style: _bn,
);
Widget _asset(Future<FactorAssets> f, Widget Function(FactorAssets) body) =>
    FutureBuilder<FactorAssets>(
      future: f,
      builder: (c, s) => s.hasError
          ? const Panel(child: Text('Bundled factor models could not be read.'))
          : !s.hasData
          ? const Center(child: CircularProgressIndicator())
          : body(s.data!),
    );

class FactorWorkbench extends StatefulWidget {
  const FactorWorkbench({super.key});
  @override
  State<FactorWorkbench> createState() => _FactorWorkbenchState();
}

class _FactorWorkbenchState extends State<FactorWorkbench> {
  final data = FactorAssets.load();
  int? user;
  String method = 'explicit_als';
  bool genres = true;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final cases = a.data['samples'] as List;
    user ??= cases.first['user'];
    final uid = user!,
        cold = a.fallback(uid, method),
        ranked = a.recommend(uid, method, k: 5, genres: genres),
        top = ranked.first.movie;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag('RECOMMENDER SYSTEMS · CHAPTER 02 · FACTOR WORKBENCH', icon: Icons.grid_on),
          _gap,
          const Text('Learn factors. Inspect the interactions.', style: _title),
          _gap,
          const Text(
            'চারটি trained model-এর complete weights দিয়ে full fit catalog Dart-এ score হয়। User/item factor coordinates latent basis; named genre বা human personality নয়। All observed seen items বাদ যায়। Model score probability নয়।',
            style: _bn,
          ),
          _gap,
          DropdownButtonFormField<int>(
            key: ValueKey('factor-user-$uid'),
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
                    'User ${c['user']} · ${a.userIndex.containsKey(c['user']) ? 'warm' : 'cold'}',
                  ),
                ),
            ],
            onChanged: (v) => setState(() => user = v),
          ),
          _gap,
          DropdownButtonFormField<String>(
            key: ValueKey('factor-method-$method'),
            initialValue: method,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Trained objective'),
            items: [
              for (final s in factorMethods)
                DropdownMenuItem(value: s, child: Text(s)),
            ],
            onChanged: (v) => setState(() => method = v!),
          ),
          _gap,
          Text(
            cold
                ? 'Fallback: popularity (no usable factors)'
                : 'Scoring: $method · rank 8',
            style: _bn,
          ),
          if (method == 'fm')
            SwitchListTile(
              key: const Key('factor-genres'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Include genre features'),
              subtitle: const Text(
                'Fixed weights, changed input; not a retrained ablation.',
              ),
              value: genres,
              onChanged: (v) => setState(() => genres = v),
            ),
          _gap,
          const Text(
            'Top 5 · full catalog minus seen',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          _gap,
          for (var j = 0; j < ranked.length; j++) ...[
            Text(
              '${j + 1}. ${a.base.movies[ranked[j].movie]!.title}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              'ID ${ranked[j].movie} · score ${_n(ranked[j].score)}',
              style: _bn,
            ),
            _gap,
          ],
          if (!cold && method != 'fm') ...[
            const Text(
              'Top-item factor contributions',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            for (var f = 0; f < 8; f++)
              Builder(
                builder: (_) {
                  final w = a.weights[method]!,
                      p = w.p[a.userIndex[uid]!][f],
                      q = w.q[a.itemIndex[top]!][f],
                      v = p * q;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Factor ${f + 1}: ${_n(p)} × ${_n(q)} = ${_n(v)}'),
                        LinearProgressIndicator(
                          value: v.abs() / (1 + v.abs()),
                          color: v < 0
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.primary,
                          minHeight: 5,
                          semanticsLabel:
                              'Factor ${f + 1} absolute contribution, scale abs(x)/(1+abs(x))',
                        ),
                      ],
                    ),
                  );
                },
              ),
            const Text(
              'Bar length |contribution|/(1+|contribution|); sign shown numerically. Explicit ALS adds global/user/item biases; other two are raw dot products.',
              style: _bn,
            ),
            _gap,
          ],
          if (!cold && method == 'fm')
            Builder(
              builder: (_) {
                final e = a.fmExplain(uid, top, genres: genres);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Top-item FM: bias ${_n(e['bias'])} + linear ${_n(e['linear'])} + interactions ${_n(e['interaction'])} = ${_n(e['score'])}',
                      style: _bn,
                    ),
                    _gap,
                    for (final p in (e['pairs'] as List).take(15))
                      Text(
                        '${p['a']} × ${p['b']}: ${_n(p['value'])}',
                        style: _bn,
                      ),
                    const Text(
                      'All pair terms are included in the total; only first15 shown. User×item, user×genre, item×genre and genre×genre share embeddings. Genre input off does not retrain the model.',
                      style: _bn,
                    ),
                    _gap,
                  ],
                );
              },
            ),
          OutlinedButton(
            onPressed: () => setState(() {
              user = cases.first['user'];
              method = 'explicit_als';
              genres = true;
            }),
            child: const Text('Reset factor workbench'),
          ),
          _gap,
          _source,
        ],
      ),
    );
  });
}

class ALSUpdateLab extends StatefulWidget {
  const ALSUpdateLab({super.key});
  @override
  State<ALSUpdateLab> createState() => _ALSUpdateLabState();
}

class _ALSUpdateLabState extends State<ALSUpdateLab> {
  final data = FactorAssets.load();
  double reg = 10;
  bool matrix = false;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final uid = a.data['als_audit']['user'] as int,
        update = a.updateUser(uid, reg: reg);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'RECOMMENDER SYSTEMS · CHAPTER 02 · ALS NORMAL EQUATION',
            icon: Icons.calculate_outlined,
          ),
          _gap,
          const Text('Freeze the items. Solve one user.', style: _title),
          _gap,
          Text(
            'Original fit User $uid-এর ${a.base.history[uid]!.length} observed ratings। Trained item factors/item biases স্থির রেখে bias+8 user factors-এর joint9D ridge system solve হয়। এটি global retraining বা future performance experiment নয়।',
            style: _bn,
          ),
          _gap,
          Text('Regularization: ${reg.toStringAsFixed(1)}'),
          Wrap(
            spacing: 12,
            children: [
              for (final v in [.1, 1.0, 10.0])
                ChoiceChip(
                  key: Key('als-reg-$v'),
                  label: Text('λ $v'),
                  selected: reg == v,
                  onSelected: (_) => setState(() => reg = v),
                ),
            ],
          ),
          _gap,
          Text(
            'Conditional objective before: ${_n(update.beforeLoss)}\nConditional objective after: ${_n(update.afterLoss)}\nUser bias before ${_n(update.before[0])} → after ${_n(update.after[0])}',
            style: _bn,
          ),
          _gap,
          const Text(
            'Objective = observed residual SSE + λ||[bias,p]||²। Frozen item/global terms constant; full global loss নয়। Exact conditional solve objective বাড়ায় না, কিন্তু changed λ-এর raw objective অন্য λ-এর সঙ্গে directly compare করবেন না।',
            style: _bn,
          ),
          _gap,
          Text(
            'A shape 9×9 · b shape 9 · first diagonals ${update.a.take(3).indexed.map((e) => _n(e.$2[e.$1])).join(', ')}\nResidual ||Aw−b||∞: ${_n(List.generate(9, (j) => (factorDot(update.a[j], update.after) - update.b[j]).abs()).reduce((x, y) => x > y ? x : y))}',
            style: _bn,
          ),
          TextButton(
            key: const Key('als-matrix'),
            onPressed: () => setState(() => matrix = !matrix),
            child: Text('Normal equation: ${matrix ? 'visible' : 'hidden'}'),
          ),
          if (matrix) ...[
            for (var j = 0; j < 9; j++)
              Text(
                'row$j diagonal ${_n(update.a[j][j])} · b ${_n(update.b[j])} · solution ${_n(update.after[j])}',
                style: _bn,
              ),
            _gap,
          ],
          const Text(
            'Global training trace · explicit ALS',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          _gap,
          _LossTrace(
            values: (a.data['weights']['explicit_als']['trace'] as List)
                .map((v) => (v as num).toDouble())
                .toList(),
          ),
          const Text(
            'Recorded17 global objective values: initialization +16 complete sweeps। Exact block solves decrease this penalized fit objective; no convex-global-optimum or diagnostic improvement guarantee।',
            style: _bn,
          ),
          _gap,
          OutlinedButton(
            onPressed: () => setState(() {
              reg = 10;
              matrix = false;
            }),
            child: const Text('Reset ALS update'),
          ),
          _gap,
          _source,
        ],
      ),
    );
  });
}

class _LossTrace extends StatelessWidget {
  final List<double> values;
  const _LossTrace({required this.values});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        height: 140,
        width: double.infinity,
        child: CustomPaint(
          painter: _LossPainter(values, Theme.of(context).colorScheme.primary),
        ),
      ),
      Text(
        'Start ${_n(values.first)} → final ${_n(values.last)} · linear objective scale',
        style: _bn,
      ),
    ],
  );
}

class _LossPainter extends CustomPainter {
  final List<double> values;
  final Color color;
  _LossPainter(this.values, this.color);
  @override
  void paint(Canvas c, Size s) {
    final lo = values.reduce((x, y) => x < y ? x : y),
        hi = values.reduce((x, y) => x > y ? x : y),
        p = Path();
    for (var j = 0; j < values.length; j++) {
      final x = j * s.width / (values.length - 1),
          y =
              s.height -
              10 -
              (values[j] - lo) / (hi - lo == 0 ? 1 : hi - lo) * (s.height - 20);
      if (j == 0) {
        p.moveTo(x, y);
      } else {
        p.lineTo(x, y);
      }
    }
    c.drawPath(
      p,
      Paint()
        ..color = color
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _LossPainter old) =>
      old.values != values || old.color != color;
}

class RankingLossLab extends StatefulWidget {
  const RankingLossLab({super.key});
  @override
  State<RankingLossLab> createState() => _RankingLossLabState();
}

class _RankingLossLabState extends State<RankingLossLab> {
  final data = FactorAssets.load();
  double offset = 0;
  bool warm = true;
  int k = 10;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final pair = a.data['pair_audit'],
        margin = (pair['margin'] as num).toDouble() + offset;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'RECOMMENDER SYSTEMS · CHAPTER 02 · PAIRWISE LOSS & AUDIT',
            icon: Icons.compare_arrows,
          ),
          _gap,
          const Text('Optimize the pair. Audit the ranking.', style: _title),
          _gap,
          Text(
            'Actual first training triplet: User ${pair['user']} · positive ${pair['positive']} · sampled-unobserved ${pair['unobserved']}। Fit-only uniform sampler সব observed ratings বাদ দেয়; unobserved item true dislike নয়। Future positives sampler দেখে না।',
            style: _bn,
          ),
          _gap,
          Text('Margin offset: ${offset.toStringAsFixed(1)}'),
          Slider(
            key: const Key('bpr-offset'),
            min: -3,
            max: 3,
            divisions: 12,
            value: offset,
            onChanged: (v) => setState(() => offset = v),
          ),
          Text(
            'Margin s(u,i)−s(u,j): ${_n(margin)}\nSoftplus(−margin): ${_n(factorSoftplus(-margin))}\nd loss / d margin: ${_n(factorBprDerivative(margin))}',
            style: _bn,
          ),
          const Text(
            'Offset is an explicitly controlled score intervention on one real triplet, not an optimizer step or retraining। Unregularized pair loss shown; full training also has sampled-vector L2 penalty। Lower pair loss does not guarantee NDCG gain।',
            style: _bn,
          ),
          _gap,
          SwitchListTile(
            key: const Key('factor-cohort'),
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
          Wrap(
            spacing: 12,
            children: [
              for (final v in [5, 10])
                ChoiceChip(
                  key: Key('factor-k-$v'),
                  label: Text('Top $v'),
                  selected: k == v,
                  onSelected: (_) => setState(() => k = v),
                ),
            ],
          ),
          _gap,
          for (final method in [...factorMethods, 'popularity', 'user_cf']) ...[
            Builder(
              builder: (_) {
                final s = recommendationScorecard(
                  a.data['rows'],
                  method,
                  k: k,
                  warmOnly: warm,
                  catalogSize: a.items.length,
                );
                return Text(
                  '$method · ${s['users']} users\nRecall@$k ${_n(s['recall'])} · NDCG@$k ${_n(s['ndcg'])}\nPrecision@$k ${_n(s['precision'])} · catalog coverage ${_n(s['catalog_coverage'])}',
                  style: _bn,
                );
              },
            ),
            _gap,
          ],
          Text(
            'Separate observed-rating task, raw unclipped RMSE:\nExplicit ALS ${_n(a.data['report']['rating_metrics']['explicit_als']['all_rmse'])}\nFM ${_n(a.data['report']['rating_metrics']['fm']['all_rmse'])}\nChapter30 Bayesian ${_n(a.data['report']['baseline_bayesian_rmse'])}',
            style: _bn,
          ),
          _gap,
          const Text(
            'Cold ranking → popularity। Explicit rating prediction retains learned available bias, zero latent term for unknown IDs; FM any unknown user/item → global mean। Ranking fallback and rating prediction are different policies. Same frozen split, no sampled evaluation negatives, no tuning/CI/online benefit claim। Input genre-off inspection is not a refitted ablation.',
            style: _bn,
          ),
          _gap,
          OutlinedButton(
            onPressed: () => setState(() {
              offset = 0;
              warm = true;
              k = 10;
            }),
            child: const Text('Reset ranking loss audit'),
          ),
          _gap,
          _source,
        ],
      ),
    );
  });
}
