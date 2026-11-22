import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import 'sequence_model.dart';

const _gap = SizedBox(height: 16),
    _bn = TextStyle(fontFamily: 'NotoSansBengali', height: 1.85),
    _title = TextStyle(fontSize: 24, fontWeight: FontWeight.w800);
Widget _asset(
  Future<SequenceAssets> f,
  Widget Function(SequenceAssets) build,
) => FutureBuilder<SequenceAssets>(
  future: f,
  builder: (c, s) {
    if (s.hasError) {
      return const Panel(
        child: Text(
          'Bundled sequence evidence could not be read. Reopen the lab.',
        ),
      );
    }
    if (!s.hasData) return const Center(child: CircularProgressIndicator());
    return build(s.data!);
  },
);
Widget _source() => const Text(
  'UCI Bike Sharing · Fanaee-T (2013) · CC BY4.0. Actual daily counts, train2011 / diagnostic development Jan–Jun2012। Training-only scaling; final184 outcomes excluded from experiments/labs। Dart recurrence actual CPU float64 PyTorch references-এর সঙ্গে যাচাই করা। App Python train করে না।',
  style: _bn,
);
String _vector(List<double> x) =>
    '[${x.map((v) => v.toStringAsFixed(6)).join(', ')}]';
Widget _queryPicker(
  SequenceAssets a,
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
        child: Text('${a.queries[i].targetDate} ·14 observed previous days'),
      ),
  ],
  onChanged: (v) {
    if (v != null) change(v);
  },
);

class RecurrentLab extends StatefulWidget {
  const RecurrentLab({super.key});
  @override
  State<RecurrentLab> createState() => _RecurrentLabState();
}

class _RecurrentLabState extends State<RecurrentLab> {
  final data = SequenceAssets.load();
  int query = 0, step = 1;
  String cell = 'gru_trained';
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final q = a.queries[query],
        r = a.cells[cell]!.trace(q.standardized),
        state = r[step - 1];
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag('DEEP LEARNING & RL · CHAPTER 05 · RECURRENT STATE', icon: Icons.route_outlined),
          _gap,
          const Text('Read one step. Carry the right state.', style: _title),
          _gap,
          const Text(
            'বাস্তব 14 দিনের Count Sequence, Hidden Size 3। তুলনার জন্য RNN, LSTM আর Initial GRU নির্দিষ্ট Seed দিয়ে তৈরি করা হয়েছে। এগুলো Train করা হয়নি। আগে Train করা GRU-টিই মূল Forecasting Model। একটি Step বেছে Hidden State, Cell State আর Gate-গুলোর মান দেখুন। প্রতিটি Window শূন্য State থেকে শুরু হয়। Cell-এর মান দেখে Model-এর মানের Ranking করা যায় না।',
            style: _bn,
          ),
          _gap,
          _queryPicker(
            a,
            query,
            (v) => setState(() => query = v),
            'cell-query',
          ),
          _gap,
          DropdownButtonFormField<String>(
            key: ValueKey('cell-kind-$cell'),
            initialValue: cell,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Cell and parameter identity',
            ),
            items: const [
              DropdownMenuItem(
                value: 'rnn_initial',
                child: Text('RNN · initial reference'),
              ),
              DropdownMenuItem(
                value: 'gru_initial',
                child: Text('GRU · initial reference'),
              ),
              DropdownMenuItem(
                value: 'gru_trained',
                child: Text('GRU · trained80 steps'),
              ),
              DropdownMenuItem(
                value: 'lstm_initial',
                child: Text('LSTM · initial reference'),
              ),
            ],
            onChanged: (v) {
              if (v != null) setState(() => cell = v);
            },
          ),
          _gap,
          Slider(
            key: const Key('cell-step'),
            value: step.toDouble(),
            min: 1,
            max: 14,
            divisions: 13,
            label: '$step',
            onChanged: (v) => setState(() => step = v.round()),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Tag('Cell: $cell'),
              Tag('Step: $step / 14'),
              Tag('Date: ${q.dates[step - 1]}'),
            ],
          ),
          _gap,
          Text(
            'Observed count: ${q.counts[step - 1].toInt()}\nStandardized input: ${q.standardized[step - 1].toStringAsFixed(6)}\nPrevious hidden: ${step == 1 ? '[0, 0, 0]' : _vector(r[step - 2].hidden)}\nCurrent hidden: ${_vector(state.hidden)}',
            style: const TextStyle(height: 2),
          ),
          _gap,
          if (state.cell.isNotEmpty)
            Text(
              'Cell memory c: ${_vector(state.cell)}',
              style: const TextStyle(height: 2),
            ),
          for (final entry in state.gates.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Text(
                '${entry.key}: ${_vector(entry.value)}',
                style: const TextStyle(height: 1.8),
              ),
            ),
          _gap,
          const Text(
            'PyTorch GRU-তে Gate-এর ক্রম r,z,n। Candidate n=tanh(input_affine + r⊙hidden_affine); hidden bias reset-এর ভেতরে। Textbook variant-এর matrix/reset order ভিন্ন হতে পারে। LSTM-এ ক্রম i,f,g,o। Cell State আর Hidden State আলাদা।',
            style: _bn,
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                key: const Key('cell-lstm'),
                onPressed: () => setState(() {
                  cell = 'lstm_initial';
                  step = 14;
                }),
                child: const Text('Inspect LSTM final state'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  query = 0;
                  step = 1;
                  cell = 'gru_trained';
                }),
                child: const Text('Reset recurrence'),
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

class PaddingLab extends StatefulWidget {
  const PaddingLab({super.key});
  @override
  State<PaddingLab> createState() => _PaddingLabState();
}

class _PaddingLabState extends State<PaddingLab> {
  final data = SequenceAssets.load();
  int query = 0;
  bool ignore = false;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final p = a.padding[query],
        cell = a.cells['gru_trained']!,
        valid = cell.trace(p.padded, length: p.length).last.hidden,
        naive = cell.trace(p.padded).last.hidden;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'DEEP LEARNING & RL · CHAPTER 05 · PADDING & LENGTHS',
            icon: Icons.view_array_outlined,
          ),
          _gap,
          const Text('Padding is storage, not an observation.', style: _title),
          _gap,
          const Text(
            'তিনটি বাস্তব History Window-এর Prefix Length যথাক্রমে 5/14/9 ধরে নেওয়া হয়েছে। উৎসের Data-তে কোনো মান Missing থাকার কারণে এই দৈর্ঘ্য নেওয়া হয়নি। Right pad standardized0 দিয়ে common length14। Zero input-ও recurrent biases/hidden transitions চালায়। PyTorch packed final state valid prefix-এর সঙ্গে মেলে; dense padded last state আলাদা হতে পারে।',
            style: _bn,
          ),
          _gap,
          DropdownButtonFormField<int>(
            key: ValueKey('padding-query-$query'),
            initialValue: query,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Actual prefix with declared valid length',
            ),
            items: [
              for (var i = 0; i < 3; i++)
                DropdownMenuItem(
                  value: i,
                  child: Text(
                    'Window ${i + 1} · valid ${a.padding[i].length} /14',
                  ),
                ),
            ],
            onChanged: (v) {
              if (v != null) setState(() => query = v);
            },
          ),
          _gap,
          SwitchListTile(
            key: const Key('padding-ignore'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Treat padded zeros as real timesteps (bug)'),
            value: ignore,
            onChanged: (v) => setState(() => ignore = v),
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Tag('Valid length: ${p.length}'),
              Tag(
                ignore
                    ? 'State policy: ignore lengths'
                    : 'State policy: valid prefix',
              ),
            ],
          ),
          _gap,
          Wrap(
            spacing: 5,
            runSpacing: 7,
            children: [
              for (var i = 0; i < 14; i++)
                Container(
                  width: 66,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (i < p.length ? forest : Colors.orange).withValues(
                      alpha: .12,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${i + 1}\n${p.padded[i].toStringAsFixed(3)}\n${i < p.length ? 'valid' : 'PAD'}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, height: 1.6),
                  ),
                ),
            ],
          ),
          _gap,
          Text(
            'Displayed final hidden: ${_vector(ignore ? naive : valid)}\nPacked/individual valid state: ${_vector(valid)}\nDense last-padded state: ${_vector(naive)}',
            style: const TextStyle(height: 2),
          ),
          _gap,
          const Text(
            'Loss mask padded target contributions বাদ দেয়; recurrent hidden-state transitions নিজে থামায় না। Unidirectional valid output index(length−1) বা packed execution ব্যবহার করা যায়। Bidirectional model-এ padded suffix reverse direction-ও contaminate করতে পারে। Lengths CPU tensor, enforce_sorted=False internal sorting handle করে।',
            style: _bn,
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                key: const Key('padding-bug'),
                onPressed: () => setState(() => ignore = true),
                child: const Text('Inspect ignored lengths'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  query = 0;
                  ignore = false;
                }),
                child: const Text('Reset padding'),
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

class SequenceForecastLab extends StatefulWidget {
  const SequenceForecastLab({super.key});
  @override
  State<SequenceForecastLab> createState() => _SequenceForecastLabState();
}

class _SequenceForecastLabState extends State<SequenceForecastLab> {
  final data = SequenceAssets.load();
  int query = 0;
  bool seven = false;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final q = a.queries[query],
        h = seven ? 7 : 1,
        forecast = a.cells['gru_trained']!.recursive(
          q.counts,
          a.mean,
          a.scale,
          h,
        ),
        seasonal = q.counts.skip(7).take(h).toList();
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'DEEP LEARNING & RL · CHAPTER 05 · CAUSAL FORECAST',
            icon: Icons.show_chart_outlined,
          ),
          _gap,
          const Text('Fix the origin. Separate the protocols.', style: _title),
          _gap,
          const Text(
            'Forecast origin-এর আগের14 actual daily counts input। One-step prediction বা fixed-origin recursive7 days দেখুন। Recursive Forecast-এ Model-এর নিজের Prediction পরের Input হয়। Forecast Origin-এর পরের Observed Count Model-কে দেওয়া হয় না। বাস্তব Outcome শুধু আগের Prediction-এর Error দেখতে ব্যবহার করা হয়।',
            style: _bn,
          ),
          _gap,
          _queryPicker(
            a,
            query,
            (v) => setState(() => query = v),
            'forecast-query',
          ),
          _gap,
          SwitchListTile(
            key: const Key('forecast-seven'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Fixed-origin recursive 7 days'),
            value: seven,
            onChanged: (v) => setState(() => seven = v),
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Tag('Forecast steps: $h'),
              Tag('Last observed: ${q.dates.last}'),
              const Tag('Hidden reset: each window'),
            ],
          ),
          _gap,
          _ForecastChart(query: q, forecast: forecast, seasonal: seasonal),
          _gap,
          const Text(
            'Observed history · counts available after each day closes',
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < 14; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                '${q.dates[i]} · ${q.counts[i].toInt()}',
                style: const TextStyle(fontSize: 12, height: 1.6),
              ),
            ),
          _gap,
          for (var i = 0; i < h; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '${q.futureDates[i]} · lead ${i + 1}\nGRU ${forecast[i].toStringAsFixed(2)} · seasonal7 ${seasonal[i].toStringAsFixed(2)} · observed ${q.futureCounts[i].toInt()}\nGRU error: ${(forecast[i] - q.futureCounts[i]).toStringAsFixed(2)}',
                style: const TextStyle(height: 1.8),
              ),
            ),
          _gap,
          const Text(
            'Rolling one-step development evaluation আগের observed development counts ব্যবহার করতে পারে। এই recursive7 fixed-origin path সেগুলো feed করে না; দুই protocol-এর metrics সরাসরি এক ranking নয়। Main fixed GRU development MAE≈1245.91, last-day baseline≈900.60; complex model উন্নতি নিশ্চিত করে না। Forecast linear head unbounded, silent clipping নেই।',
            style: _bn,
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                key: const Key('forecast-recursive'),
                onPressed: () => setState(() => seven = true),
                child: const Text('Inspect recursive 7 days'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  query = 0;
                  seven = false;
                }),
                child: const Text('Reset forecast'),
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

class _ForecastChart extends StatelessWidget {
  final SequenceQuery query;
  final List<double> forecast, seasonal;
  const _ForecastChart({
    required this.query,
    required this.forecast,
    required this.seasonal,
  });
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final observed = dark ? lime : forest,
        predicted = dark ? const Color(0xffc4adff) : const Color(0xff7650be);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Count timeline · forecast origin after the 14 observed days',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Semantics(
          label: 'Historical count timeline. Green: available history. Purple: model forecast. Orange: future outcomes shown only for retrospective inspection. Gray: seasonal baseline. Numeric values follow below.',
          child: SizedBox(
            height: 180,
            width: double.infinity,
            child: CustomPaint(
              painter: _ForecastPainter(
                query,
                forecast,
                seasonal,
                observed,
                predicted,
                dark ? Colors.white54 : Colors.black38,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            Text('● Observed history', style: TextStyle(color: observed)),
            Text('● GRU prediction', style: TextStyle(color: predicted)),
            const Text(
              '● Future outcome',
              style: TextStyle(color: Colors.deepOrange),
            ),
            Text(
              '— Seasonal7',
              style: TextStyle(color: dark ? Colors.white70 : Colors.black54),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${query.dates.first} → ${query.dates.last} | origin → ${query.futureDates[forecast.length - 1]}',
          style: const TextStyle(fontSize: 11, height: 1.7),
        ),
      ],
    );
  }
}

class _ForecastPainter extends CustomPainter {
  final SequenceQuery query;
  final List<double> forecast, seasonal;
  final Color observed, predicted, grid;
  _ForecastPainter(
    this.query,
    this.forecast,
    this.seasonal,
    this.observed,
    this.predicted,
    this.grid,
  );
  @override
  void paint(Canvas canvas, Size size) {
    final actual = query.futureCounts.take(forecast.length).toList();
    final values = [0.0, ...query.counts, ...actual, ...forecast, ...seasonal],
        lo = values.reduce(math.min),
        hi = values.reduce(math.max);
    final range = math.max(1.0, hi - lo),
        step = size.width / (14 + forecast.length);
    double y(double value) =>
        size.height - 10 - (value - lo) / range * (size.height - 20);
    Offset point(int i, double value) => Offset((i + .5) * step, y(value));
    for (var i = 0; i < 4; i++) {
      final yy = 10 + i * (size.height - 20) / 3;
      canvas.drawLine(
        Offset(0, yy),
        Offset(size.width, yy),
        Paint()..color = grid.withValues(alpha: .14),
      );
    }
    final origin = 14 * step;
    for (double yy = 0; yy < size.height; yy += 10) {
      canvas.drawLine(
        Offset(origin, yy),
        Offset(origin, math.min(yy + 5, size.height)),
        Paint()..color = grid,
      );
    }
    void line(List<double> data, int start, Color color, {bool dots = true}) {
      final path = Path();
      for (var i = 0; i < data.length; i++) {
        final p = point(start + i, data[i]);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );
      if (dots) {
        for (var i = 0; i < data.length; i++) {
          canvas.drawCircle(
            point(start + i, data[i]),
            3,
            Paint()..color = color,
          );
        }
      }
    }

    line(query.counts, 0, observed);
    line([query.counts.last, ...forecast], 13, predicted);
    line(actual, 14, Colors.deepOrange);
    line(seasonal, 14, grid);
  }

  @override
  bool shouldRepaint(covariant _ForecastPainter old) =>
      old.query != query ||
      old.forecast != forecast ||
      old.observed != observed;
}
