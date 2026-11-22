import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import 'attention_model.dart';

const _gap = SizedBox(height: 16),
    _bn = TextStyle(fontFamily: 'NotoSansBengali', height: 1.85),
    _title = TextStyle(fontSize: 24, fontWeight: FontWeight.w800);
String _vec(List<double> values) =>
    '[${values.map((v) => v.toStringAsFixed(5)).join(', ')}]';
Widget _asset(
  Future<AttentionAssets> future,
  Widget Function(AttentionAssets) build,
) => FutureBuilder<AttentionAssets>(
  future: future,
  builder: (context, s) {
    if (s.hasError) {
      return const Panel(
        child: Text(
          'Bundled attention evidence could not be read. Reopen the lab.',
        ),
      );
    }
    if (!s.hasData) {
      return const Center(child: CircularProgressIndicator());
    }
    return build(s.data!);
  },
);
Widget _source() => const Text(
  'UCI Bike Sharing · Fanaee-T (2013) · CC BY4.0। Actual daily counts, 2011 fit / Jan–Jun2012 diagnostic development। Final184 outcomes excluded। Same development data আগেই explored; নতুন independent test নয়। App Dart forward চালায়, Python training নয়।',
  style: _bn,
);
Widget _picker(
  AttentionAssets a,
  int query,
  void Function(int) change,
  String key,
) => DropdownButtonFormField<int>(
  key: ValueKey('$key-$query'),
  initialValue: query,
  isExpanded: true,
  decoration: const InputDecoration(labelText: 'Historical forecast origin'),
  items: [
    for (var i = 0; i < 3; i++)
      DropdownMenuItem(
        value: i,
        child: Text('${a.queries[i].targetDate} · 14 observed days'),
      ),
  ],
  onChanged: (v) {
    if (v != null) {
      change(v);
    }
  },
);

class AttentionLab extends StatefulWidget {
  const AttentionLab({super.key});
  @override
  State<AttentionLab> createState() => _AttentionLabState();
}

class _AttentionLabState extends State<AttentionLab> {
  final data = AttentionAssets.load();
  int sample = 0, head = 0, query = 7, keyIndex = 3;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final q = a.queries[sample],
        t = a.model.run(q.standardized),
        w = t.weights[head][query],
        allowed = keyIndex <= query;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'DEEP LEARNING & RL · CHAPTER 06 · ATTENTION WEIGHTS',
            icon: Icons.grid_on_outlined,
          ),
          _gap,
          const Text('Project. Compare. Mix the values.', style: _title),
          _gap,
          const Text(
            'Actual count→4 features, pre-norm থেকে learned Q/K/V। দুই head-এর প্রতিটির dimension2। একটি Query Row ও Key Cell বেছে Scaled Dot Product, Causal Mask আর Weighted Value দেখুন। Attention weight নিজে causal explanation বা feature importance নয়।',
            style: _bn,
          ),
          _gap,
          _picker(
            a,
            sample,
            (v) => setState(() => sample = v),
            'attention-origin',
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Tag('Head: ${head + 1} / 2'),
              Tag('Query: ${query + 1} / 14'),
              Tag('Key: ${keyIndex + 1} / 14'),
              const Tag('Mask: causal'),
            ],
          ),
          _gap,
          Slider(
            key: const Key('attention-query'),
            value: query.toDouble(),
            min: 0,
            max: 13,
            divisions: 13,
            label: q.dates[query],
            onChanged: (v) => setState(() => query = v.round()),
          ),
          Text(
            'Rows=query · columns=key · tap a cell · darker means larger weight',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          _AttentionGrid(
            weights: t.weights[head],
            selected: query,
            onTap: (row, col) => setState(() {
              query = row;
              keyIndex = col;
            }),
          ),
          _gap,
          Text(
            'Query ${q.dates[query]}: Q ${_vec(t.q[head][query])}\nKey ${q.dates[keyIndex]}: K ${_vec(t.k[head][keyIndex])}\nRaw score / √2: ${t.scores[head][query][keyIndex].toStringAsFixed(6)}\n${allowed ? 'Allowed' : 'Blocked future key'} · weight ${w[keyIndex].toStringAsFixed(6)}\nV: ${_vec(t.v[head][keyIndex])}\nWeighted contribution: ${_vec(t.v[head][keyIndex].map((v) => v * w[keyIndex]).toList())}\nMixed head output: ${_vec(t.mixed[head][query])}',
            style: const TextStyle(height: 1.9),
          ),
          _gap,
          const Text(
            'ব্যবহার করা যায় এমন Score-গুলো থেকে সর্বোচ্চ Score বিয়োগ করি। তারপর প্রতিটির exp বের করি। যে Row-এর Score, সেই Row-এর সব exp-এর যোগফল দিয়ে ভাগ করি। Masked Key-গুলোর Weight ঠিক 0। Valid Row-এর Weight যোগ করলে 1 হয়, কারণ এখানে Dropout 0। Head outputs concatenate করার পরে learned output projection ও residual আছে—heatmap পুরো model explanation নয়।',
            style: _bn,
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                key: const Key('attention-head'),
                onPressed: () => setState(() => head = 1 - head),
                child: const Text('Switch attention head'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  sample = 0;
                  head = 0;
                  query = 7;
                  keyIndex = 3;
                }),
                child: const Text('Reset attention'),
              ),
            ],
          ),
          _gap,
          _source(),
        ],
      ),
    );
  });
}

class _AttentionGrid extends StatelessWidget {
  final Matrix weights;
  final int selected;
  final void Function(int, int) onTap;
  const _AttentionGrid({
    required this.weights,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          const SizedBox(width: 22),
          for (var j = 0; j < 14; j++)
            Expanded(
              child: Text(
                '${j + 1}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 9),
              ),
            ),
        ],
      ),
      for (var i = 0; i < 14; i++)
        Row(
          children: [
            SizedBox(
              width: 22,
              child: Text(
                '${i + 1}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: i == selected ? FontWeight.w900 : FontWeight.w400,
                ),
              ),
            ),
            for (var j = 0; j < 14; j++)
              Expanded(
                child: Semantics(
                  button: true,
                  label:
                      'Query ${i + 1}, key ${j + 1}, weight ${weights[i][j].toStringAsFixed(4)}',
                  child: GestureDetector(
                    onTap: () => onTap(i, j),
                    child: Container(
                      height: 20,
                      margin: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: weights[i][j] == 0
                            ? Colors.grey.withValues(alpha: .10)
                            : (Theme.of(context).brightness == Brightness.dark
                                      ? lime
                                      : forest)
                                  .withValues(
                                    alpha: .12 + .88 * math.sqrt(weights[i][j]),
                                  ),
                        border: i == selected
                            ? Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: 1,
                              )
                            : null,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
    ],
  );
}

class AttentionMaskLab extends StatefulWidget {
  const AttentionMaskLab({super.key});
  @override
  State<AttentionMaskLab> createState() => _AttentionMaskLabState();
}

class _AttentionMaskLabState extends State<AttentionMaskLab> {
  final data = AttentionAssets.load();
  int sample = 0, valid = 10;
  bool causal = true;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final q = a.queries[sample],
        base = a.model.run(q.standardized, causal: causal, valid: valid),
        prefix = q.standardized.take(6).toList(),
        suffix = q.standardized
            .skip(6)
            .take(valid - 6)
            .toList()
            .reversed
            .toList(),
        altered = [...prefix, ...suffix, ...q.standardized.skip(valid)];
    final changed = a.model.run(altered, causal: causal, valid: valid),
        row = base.weights[0][5],
        delta = List.generate(
          4,
          (i) =>
              (base.matrices['state']![5][i] - changed.matrices['state']![5][i])
                  .abs(),
        ).reduce(math.max);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'DEEP LEARNING & RL · CHAPTER 06 · MASK & AVAILABILITY',
            icon: Icons.filter_alt_outlined,
          ),
          _gap,
          const Text('Block the key. Preserve the prefix.', style: _title),
          _gap,
          const Text(
            'Query position6 ধরে দুই mask combine করি: causal blocks later keys; key-padding blocks positions≥valid length। Valid Length 10 ধরে History Prefix ছোট করা হয়েছে। উৎসের Data-তে কোনো মান Missing থাকার কারণে এটা করা হয়নি। Padding mask শুধু keys বাদ দেয়; padded query outputs বা loss নিজে বাদ যায় না।',
            style: _bn,
          ),
          _gap,
          _picker(a, sample, (v) => setState(() => sample = v), 'mask-origin'),
          _gap,
          SwitchListTile(
            key: const Key('mask-causal'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Causal query-prefix visibility'),
            value: causal,
            onChanged: (v) => setState(() => causal = v),
          ),
          SwitchListTile(
            key: const Key('mask-padding'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Truncate valid prefix to 10 steps'),
            value: valid == 10,
            onChanged: (v) => setState(() => valid = v ? 10 : 14),
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Tag(causal ? 'Mask: causal' : 'Mask: full history'),
              Tag('Valid keys: $valid / 14'),
              const Tag('Inspected query: 6'),
            ],
          ),
          _gap,
          Wrap(
            spacing: 6,
            runSpacing: 8,
            children: [
              for (var j = 0; j < 14; j++)
                Container(
                  width: 72,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        (j >= valid
                                ? Colors.orange
                                : (causal && j > 5 ? Colors.grey : forest))
                            .withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${j + 1}\n${j >= valid
                        ? 'PAD key'
                        : causal && j > 5
                        ? 'future'
                        : 'allowed'}\n${row[j].toStringAsFixed(4)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, height: 1.7),
                  ),
                ),
            ],
          ),
          _gap,
          Text(
            'Later-key attention mass: ${row.skip(6).reduce((a, b) => a + b).toStringAsFixed(6)}\nCurrent query state: ${_vec(base.matrices['state']![5])}\nAfter suffix reordering: ${_vec(changed.matrices['state']![5])}\nMax state difference: ${delta.toStringAsExponential(4)}',
            style: const TextStyle(height: 1.9),
          ),
          _gap,
          const Text(
            'Counterfactual audit: Query 6-এর পরের Valid Suffix-এ একই বাস্তব মানগুলোর ক্রম উল্টে দিই। Prefix-এর মান আর Position একই থাকে। এটি নতুন real observation নয়। Causal block current state বদলাতে দেয় না; full attention later context নিতে পারে। Forecast origin-এ পুরো14-day history জানা থাকলে full past-window attention নিজে target leakage নয়; per-position online prediction-এর availability আলাদা।',
            style: _bn,
          ),
          _gap,
          const Text(
            'PyTorch MultiheadAttention boolean True=blocked; functional SDPA True=allowed। এই app allowed-key rule সরাসরি গণনা করে। Completely masked row-এর softmax undefined—silent NaN বা invented uniform weights না দিয়ে nonempty visibility contract রাখুন।',
            style: _bn,
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                key: const Key('mask-open'),
                onPressed: () => setState(() => causal = false),
                child: const Text('Inspect full history'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  sample = 0;
                  valid = 10;
                  causal = true;
                }),
                child: const Text('Reset masks'),
              ),
            ],
          ),
          _gap,
          _source(),
        ],
      ),
    );
  });
}

class TransformerBlockLab extends StatefulWidget {
  const TransformerBlockLab({super.key});
  @override
  State<TransformerBlockLab> createState() => _TransformerBlockLabState();
}

class _TransformerBlockLabState extends State<TransformerBlockLab> {
  final data = AttentionAssets.load();
  int sample = 0;
  bool position = true;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final q = a.queries[sample],
        t = a.model.run(q.standardized, usePosition: position),
        prediction = t.prediction * a.scale + a.mean;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'DEEP LEARNING & RL · CHAPTER 06 · TRANSFORMER BLOCK',
            icon: Icons.account_tree_outlined,
          ),
          _gap,
          const Text(
            'Add position. Follow both residual paths.',
            style: _title,
          ),
          _gap,
          const Text(
            'একটি explicit pre-norm block: count projection→position→LayerNorm→2-head attention→residual→LayerNorm→FFN/ReLU→residual। Last valid state থেকে scalar next-day forecast। D4, heads2, FF8;185 trainable parameters, no final norm/dropout। এটি tiny count model; pretrained LLM নয়।',
            style: _bn,
          ),
          _gap,
          _picker(a, sample, (v) => setState(() => sample = v), 'block-origin'),
          _gap,
          SwitchListTile(
            key: const Key('block-position'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Window-relative sinusoidal positions'),
            value: position,
            onChanged: (v) => setState(() => position = v),
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Tag(position ? 'Position: on' : 'Position: off'),
              const Tag('Pre-norm · 185 parameters'),
              const Tag('Forecast: next day'),
            ],
          ),
          _gap,
          const Text(
            'Position vectors · first 4 window offsets',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < 4; i++)
            Text(
              '$i: ${_vec(sinusoidalPositions()[i])}',
              style: const TextStyle(height: 1.8),
            ),
          _gap,
          for (final key in [
            'embedding',
            'norm1',
            'concat',
            'attention',
            'residual1',
            'norm2',
            'ff_hidden',
            'ff_output',
            'state',
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Text(
                '$key at step14\n${_vec(t.matrices[key]![13])}',
                style: const TextStyle(height: 1.8),
              ),
            ),
          _gap,
          Text(
            '${q.targetDate}\nForecast: ${prediction.toStringAsFixed(2)} counts\nLast-day naive: ${q.counts.last.toStringAsFixed(2)}\nObserved outcome: ${q.outcome.toInt()}\nModel error: ${(prediction - q.outcome).toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w700, height: 1.9),
          ),
          _gap,
          const Text(
            'Position off হলো একই trained weights-এর inference intervention; separately trained no-position baseline নয়। Causal mask নিজেও order structure দেয়, তাই positional encoding সরালেই model পুরো permutation-invariant হয় না। প্রতিটি 14 দিনের Window-এ Sinusoidal Offset নতুন করে শুরু হয়। এতে Calendar Seasonality ধরা পড়বে বা দীর্ঘ Context-এ Extrapolation কাজ করবে, এমন নিশ্চয়তা নেই। Outcome শুধু retrospective inspection, model input নয়।',
            style: _bn,
          ),
          _gap,
          const Text(
            'Source data ও development role আগের chapter-এ ব্যবহৃত। Fixed80-update recipe-এর raw-count MAE/RMSE README ও lesson-এ আছে; architecture comparison isolate করতে same selection budget, repeated seeds ও fresh chronological evidence দরকার। Attention heatmap causal importance প্রমাণ করে না।',
            style: _bn,
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                key: const Key('block-no-position'),
                onPressed: () => setState(() => position = false),
                child: const Text('Inspect without position'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  sample = 0;
                  position = true;
                }),
                child: const Text('Reset block'),
              ),
            ],
          ),
          _gap,
          _source(),
        ],
      ),
    );
  });
}
