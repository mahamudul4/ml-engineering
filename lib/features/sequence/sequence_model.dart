import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

List<double> _v(dynamic x) =>
    List<double>.unmodifiable((x as List).map((v) => (v as num).toDouble()));
List<List<double>> _m(dynamic x) =>
    List<List<double>>.unmodifiable((x as List).map(_v));
void _finite(List<double> x) {
  if (x.isEmpty || x.any((v) => !v.isFinite)) {
    throw ArgumentError('Finite nonempty values');
  }
}

double _sigmoid(double x) {
  if (x >= 0) return 1 / (1 + exp(-x));
  final z = exp(x);
  return z / (1 + z);
}

double _tanh(double x) => 2 * _sigmoid(2 * x) - 1;

// Source observations are calendar days, independent of the device's DST rules.
DateTime _day(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw const FormatException('ISO source calendar day');
  }
  final date = DateTime.parse('${value}T00:00:00Z');
  if (date.toIso8601String().substring(0, 10) != value) {
    throw const FormatException('Valid source calendar day');
  }
  return date;
}

class CellState {
  final List<double> hidden, cell;
  final Map<String, List<double>> gates;
  CellState(List<double> h, List<double> c, Map<String, List<double>> g)
    : hidden = List.unmodifiable(h),
      cell = List.unmodifiable(c),
      gates = Map.unmodifiable(
        g.map((k, v) => MapEntry(k, List<double>.unmodifiable(v))),
      );
}

class RecurrentWeights {
  final String name, kind;
  final List<List<double>> inputWeight, hiddenWeight;
  final List<double> inputBias, hiddenBias, head;
  final double headBias;
  RecurrentWeights.fromJson(Map<String, dynamic> j)
    : name = j['name'],
      kind = j['kind'],
      inputWeight = _m(j['parameters']['w_ih']),
      hiddenWeight = _m(j['parameters']['w_hh']),
      inputBias = _v(j['parameters']['b_ih']),
      hiddenBias = _v(j['parameters']['b_hh']),
      head = j['parameters']['head_weight'] == null
          ? const []
          : _v(j['parameters']['head_weight']),
      headBias = (j['parameters']['head_bias'] as num?)?.toDouble() ?? 0 {
    final rows = {'rnn': 3, 'gru': 9, 'lstm': 12}[kind];
    if (rows == null ||
        inputWeight.length != rows ||
        hiddenWeight.length != rows ||
        inputBias.length != rows ||
        hiddenBias.length != rows ||
        inputWeight.any((r) => r.length != 1) ||
        hiddenWeight.any((r) => r.length != 3) ||
        (head.isNotEmpty && head.length != 3) ||
        !headBias.isFinite) {
      throw const FormatException('Hidden3 recurrent layout');
    }
    for (final r in [...inputWeight, ...hiddenWeight, inputBias, hiddenBias]) {
      _finite(r);
    }
    if (head.isNotEmpty) _finite(head);
  }
  List<CellState> trace(List<double> sequence, {int? length}) {
    _finite(sequence);
    final count = length ?? sequence.length;
    if (count < 1 || count > sequence.length || sequence.length > 64) {
      throw ArgumentError('Valid recurrent length1..64');
    }
    var h = List.filled(3, 0.0), c = List.filled(3, 0.0);
    final result = <CellState>[];
    for (final value in sequence.take(count)) {
      final a = [
            for (var k = 0; k < inputBias.length; k++)
              inputWeight[k][0] * value + inputBias[k],
          ],
          b = [
            for (var k = 0; k < hiddenBias.length; k++)
              hiddenBias[k] +
                  List.generate(
                    3,
                    (j) => hiddenWeight[k][j] * h[j],
                  ).fold(0.0, (s, v) => s + v),
          ];
      final gates = <String, List<double>>{};
      if (kind == 'rnn') {
        h = [for (var j = 0; j < 3; j++) _tanh(a[j] + b[j])];
      } else if (kind == 'gru') {
        final r = [for (var j = 0; j < 3; j++) _sigmoid(a[j] + b[j])],
            z = [for (var j = 0; j < 3; j++) _sigmoid(a[3 + j] + b[3 + j])];
        final n = [
          for (var j = 0; j < 3; j++) _tanh(a[6 + j] + r[j] * b[6 + j]),
        ];
        h = [for (var j = 0; j < 3; j++) (1 - z[j]) * n[j] + z[j] * h[j]];
        gates.addAll({'reset': r, 'update': z, 'candidate': n});
      } else {
        final i = [for (var j = 0; j < 3; j++) _sigmoid(a[j] + b[j])],
            f = [for (var j = 0; j < 3; j++) _sigmoid(a[3 + j] + b[3 + j])],
            g = [for (var j = 0; j < 3; j++) _tanh(a[6 + j] + b[6 + j])],
            o = [for (var j = 0; j < 3; j++) _sigmoid(a[9 + j] + b[9 + j])];
        c = [for (var j = 0; j < 3; j++) f[j] * c[j] + i[j] * g[j]];
        h = [for (var j = 0; j < 3; j++) o[j] * _tanh(c[j])];
        gates.addAll({'input': i, 'forget': f, 'candidate': g, 'output': o});
      }
      _finite(h);
      _finite(c);
      result.add(CellState(h, kind == 'lstm' ? c : [], gates));
    }
    return List.unmodifiable(result);
  }

  double predict(List<double> normalized) {
    if (kind != 'gru' || head.length != 3 || normalized.length != 14) {
      throw ArgumentError('GRU head on14 steps');
    }
    final h = trace(normalized).last.hidden;
    final z =
        headBias +
        List.generate(3, (k) => h[k] * head[k]).fold(0.0, (s, v) => s + v);
    if (!z.isFinite) throw ArgumentError('Finite head output');
    return z;
  }

  List<double> recursive(
    List<double> counts,
    double mean,
    double scale,
    int horizon,
  ) {
    _finite(counts);
    if (counts.length != 14 ||
        !mean.isFinite ||
        !scale.isFinite ||
        scale <= 0 ||
        horizon < 1 ||
        horizon > 7) {
      throw ArgumentError('Causal14-step prefix, horizon1..7');
    }
    final prefix = [...counts], result = <double>[];
    for (var step = 0; step < horizon; step++) {
      final x = prefix
              .skip(prefix.length - 14)
              .map((v) => (v - mean) / scale)
              .toList(),
          value = predict(x) * scale + mean;
      if (!value.isFinite) throw ArgumentError('Forecast overflow');
      result.add(value);
      prefix.add(value);
    }
    return List.unmodifiable(result);
  }
}

class SequenceQuery {
  final int targetIndex;
  final String targetDate;
  final List<String> dates, futureDates;
  final List<double> counts, standardized, futureCounts;
  SequenceQuery.fromJson(Map<String, dynamic> j)
    : targetIndex = j['target_index'],
      targetDate = j['target_date'],
      dates = List.unmodifiable(List<String>.from(j['history_dates'])),
      futureDates = List.unmodifiable(List<String>.from(j['future_dates'])),
      counts = _v(j['counts']),
      standardized = _v(j['standardized']),
      futureCounts = _v(j['future_counts']) {
    _finite(counts);
    _finite(standardized);
    _finite(futureCounts);
    if (![365, 400, 540].contains(targetIndex) ||
        dates.length != 14 ||
        counts.length != 14 ||
        standardized.length != 14 ||
        futureDates.length != 7 ||
        futureCounts.length != 7 ||
        counts.any((v) => v < 0) ||
        futureCounts.any((v) => v < 0)) {
      throw const FormatException('Actual causal query');
    }
    final origin = _day(targetDate), base = DateTime.utc(2011, 1, 1);
    if (origin.difference(base).inDays != targetIndex) {
      throw const FormatException('Source calendar position');
    }
    for (var i = 0; i < 14; i++) {
      if (_day(dates[i]) != origin.subtract(Duration(days: 14 - i))) {
        throw const FormatException('Contiguous historical dates');
      }
    }
    for (var i = 0; i < 7; i++) {
      if (_day(futureDates[i]) != origin.add(Duration(days: i)) ||
          _day(futureDates[i]).isAfter(DateTime.utc(2012, 6, 30))) {
        throw const FormatException('Reserved date excluded');
      }
    }
  }
}

class PaddingQuery {
  final int query, length;
  final List<double> padded;
  PaddingQuery.fromJson(Map<String, dynamic> j)
    : query = j['query'],
      length = j['length'],
      padded = _v(j['padded']) {
    _finite(padded);
    if (query < 0 ||
        query > 2 ||
        ![5, 14, 9].contains(length) ||
        padded.length != 14 ||
        padded.skip(length).any((v) => v != 0)) {
      throw const FormatException('Declared right-padding contract');
    }
  }
}

class SequenceAssets {
  final double mean, scale;
  final Map<String, RecurrentWeights> cells;
  final List<SequenceQuery> queries;
  final List<PaddingQuery> padding;
  SequenceAssets.fromJson(Map<String, dynamic> j)
    : mean = (j['mean'] as num).toDouble(),
      scale = (j['scale'] as num).toDouble(),
      cells = Map.unmodifiable({
        for (final r in j['cells'] as List)
          r['name'] as String: RecurrentWeights.fromJson(r),
      }),
      queries = List.unmodifiable(
        (j['queries'] as List).map((q) => SequenceQuery.fromJson(q)),
      ),
      padding = List.unmodifiable(
        (j['padding_references'] as List).map((q) => PaddingQuery.fromJson(q)),
      ) {
    if (!mean.isFinite ||
        !scale.isFinite ||
        scale <= 0 ||
        cells.length != 4 ||
        ![
          'rnn_initial',
          'gru_initial',
          'gru_trained',
          'lstm_initial',
        ].every(cells.containsKey) ||
        queries.length != 3 ||
        queries.map((q) => q.targetIndex).toSet().length != 3 ||
        padding.length != 3 ||
        j['dtype'] != 'float64' ||
        j['lookback'] != 14 ||
        j['hidden'] != 3 ||
        j['parameter_count'] != 58 ||
        j['train_end'] != '2011-12-31' ||
        j['development_end'] != '2012-06-30' ||
        cells['gru_trained']!.head.length != 3) {
      throw const FormatException('Sequence training evidence schema');
    }
    const kinds = {
      'rnn_initial': 'rnn',
      'gru_initial': 'gru',
      'gru_trained': 'gru',
      'lstm_initial': 'lstm',
    };
    for (final name in kinds.keys) {
      if (cells[name]!.kind != kinds[name]) {
        throw const FormatException('Named cell kind');
      }
    }
    for (final q in queries) {
      for (var i = 0; i < 14; i++) {
        if (((q.counts[i] - mean) / scale - q.standardized[i]).abs() > 1e-10) {
          throw const FormatException('Training transform mismatch');
        }
      }
    }
    for (var i = 0; i < 3; i++) {
      final p = padding[i];
      if (p.query != i || p.length != [5, 14, 9][i]) {
        throw const FormatException('Aligned padding rows');
      }
      for (var k = 0; k < p.length; k++) {
        if (p.padded[k] != queries[i].standardized[k]) {
          throw const FormatException('Source prefix mismatch');
        }
      }
    }
  }
  static SequenceAssets? _cached;
  static Future<SequenceAssets> load() async {
    if (_cached != null) return _cached!;
    final a = SequenceAssets.fromJson(
      jsonDecode(
        await rootBundle.loadString(
          'assets/datasets/bike_sharing/sequence_lab.json',
        ),
      ),
    );
    _cached = a;
    return a;
  }
}
