import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

typedef Matrix = List<List<double>>;
typedef Heads = List<Matrix>;
List<double> _v(dynamic x) =>
    List<double>.unmodifiable((x as List).map((v) => (v as num).toDouble()));
Matrix _m(dynamic x) => List<List<double>>.unmodifiable((x as List).map(_v));
Heads _heads(Heads x) => List<Matrix>.unmodifiable(x.map(_m));
void _finite(Iterable<double> x) {
  if (x.any((v) => !v.isFinite)) {
    throw ArgumentError('Finite attention arithmetic');
  }
}

Matrix sinusoidalPositions() => _m([
  for (var t = 0; t < 14; t++) [sin(t), cos(t), sin(t / 100), cos(t / 100)],
]);

class AttentionTrace {
  final Map<String, Matrix> matrices;
  final Heads q, k, v, scores, weights, mixed;
  final double prediction;
  AttentionTrace(
    Map<String, Matrix> m,
    Heads query,
    Heads key,
    Heads value,
    Heads s,
    Heads a,
    Heads z,
    this.prediction,
  ) : matrices = Map.unmodifiable(m.map((k, v) => MapEntry(k, _m(v)))),
      q = _heads(query),
      k = _heads(key),
      v = _heads(value),
      scores = _heads(s),
      weights = _heads(a),
      mixed = _heads(z);
}

class AttentionModel {
  final Map<String, Matrix> matrices;
  final Map<String, List<double>> vectors;
  AttentionModel.fromJson(Map<String, dynamic> raw)
    : matrices = Map.unmodifiable({
        for (final e in raw.entries)
          if ((e.value as List).isNotEmpty && e.value[0] is List)
            e.key: _m(e.value),
      }),
      vectors = Map.unmodifiable({
        for (final e in raw.entries)
          if ((e.value as List).isNotEmpty && e.value[0] is! List)
            e.key: _v(e.value),
      }) {
    const shapes = {
      'input.weight': [4, 1],
      'attn.in_proj_weight': [12, 4],
      'attn.out_proj.weight': [4, 4],
      'ff1.weight': [8, 4],
      'ff2.weight': [4, 8],
      'head.weight': [1, 4],
      'position': [14, 4],
    };
    const sizes = {
      'input.bias': 4,
      'norm1.weight': 4,
      'norm1.bias': 4,
      'attn.in_proj_bias': 12,
      'attn.out_proj.bias': 4,
      'norm2.weight': 4,
      'norm2.bias': 4,
      'ff1.bias': 8,
      'ff2.bias': 4,
      'head.bias': 1,
    };
    if (raw.length != 17 ||
        matrices.length != shapes.length ||
        vectors.length != sizes.length) {
      throw const FormatException('Transformer state layout');
    }
    for (final e in shapes.entries) {
      final m = matrices[e.key];
      if (m == null ||
          m.length != e.value[0] ||
          m.any((r) => r.length != e.value[1])) {
        throw const FormatException('Transformer matrix shape');
      }
      for (final r in m) {
        _finite(r);
      }
    }
    for (final e in sizes.entries) {
      final v = vectors[e.key];
      if (v == null || v.length != e.value) {
        throw const FormatException('Transformer vector shape');
      }
      _finite(v);
    }
    final pe = sinusoidalPositions();
    for (var t = 0; t < 14; t++) {
      for (var j = 0; j < 4; j++) {
        if ((matrices['position']![t][j] - pe[t][j]).abs() > 1e-12) {
          throw const FormatException('Window-relative sinusoidal positions');
        }
      }
    }
  }
  Matrix _linear(Matrix x, String key) {
    final w = matrices['$key.weight']!, b = vectors['$key.bias']!;
    return [
      for (final r in x)
        [
          for (var j = 0; j < w.length; j++)
            b[j] +
                List.generate(
                  r.length,
                  (k) => r[k] * w[j][k],
                ).fold(0.0, (s, v) => s + v),
        ],
    ];
  }

  Matrix _norm(Matrix x, String key) => [
    for (final r in x)
      _normRow(r, vectors['$key.weight']!, vectors['$key.bias']!),
  ];
  List<double> _normRow(
    List<double> x,
    List<double> weight,
    List<double> bias,
  ) {
    _finite(x);
    final mean = x.reduce((a, b) => a + b) / 4,
        variance =
            x.map((v) => pow(v - mean, 2).toDouble()).reduce((a, b) => a + b) /
            4;
    _finite([mean, variance]);
    return [
      for (var j = 0; j < 4; j++)
        (x[j] - mean) / sqrt(variance + 1e-5) * weight[j] + bias[j],
    ];
  }

  AttentionTrace run(
    List<double> sequence, {
    bool causal = true,
    int valid = 14,
    bool usePosition = true,
  }) {
    if (sequence.length != 14 || valid < 1 || valid > 14) {
      throw ArgumentError('14 stored steps, valid1..14');
    }
    _finite(sequence);
    final projected = _linear([
          for (final value in sequence) [value],
        ], 'input'),
        pe = matrices['position']!;
    final x = [
          for (var i = 0; i < 14; i++)
            [
              for (var j = 0; j < 4; j++)
                projected[i][j] + (usePosition ? pe[i][j] : 0),
            ],
        ],
        n = _norm(x, 'norm1');
    final iw = matrices['attn.in_proj_weight']!,
        ib = vectors['attn.in_proj_bias']!;
    final packed = [
      for (final r in n)
        [
          for (var j = 0; j < 12; j++)
            ib[j] +
                List.generate(
                  4,
                  (k) => r[k] * iw[j][k],
                ).fold(0.0, (s, v) => s + v),
        ],
    ];
    Heads split(int offset) => [
      for (var head = 0; head < 2; head++)
        [
          for (final r in packed)
            [r[offset + head * 2], r[offset + head * 2 + 1]],
        ],
    ];
    final q = split(0), k = split(4), v = split(8);
    final scores = [
      for (var h = 0; h < 2; h++)
        [
          for (var i = 0; i < 14; i++)
            [
              for (var j = 0; j < 14; j++)
                (q[h][i][0] * k[h][j][0] + q[h][i][1] * k[h][j][1]) / sqrt(2),
            ],
        ],
    ];
    final weights = <Matrix>[];
    for (var h = 0; h < 2; h++) {
      final rows = <List<double>>[];
      for (var i = 0; i < 14; i++) {
        final allowed = [
          for (var j = 0; j < 14; j++) j < valid && (!causal || j <= i),
        ];
        final logits = [
          for (var j = 0; j < 14; j++)
            if (allowed[j]) scores[h][i][j],
        ];
        _finite(logits);
        final largest = logits.reduce(max),
            ex = [
              for (var j = 0; j < 14; j++)
                allowed[j] ? exp(scores[h][i][j] - largest) : 0.0,
            ],
            sum = ex.reduce((a, b) => a + b);
        rows.add(ex.map((e) => e / sum).toList());
      }
      weights.add(rows);
    }
    final mixed = [
      for (var h = 0; h < 2; h++)
        [
          for (var i = 0; i < 14; i++)
            [
              for (var d = 0; d < 2; d++)
                List.generate(
                  14,
                  (j) => weights[h][i][j] * v[h][j][d],
                ).fold(0.0, (s, v) => s + v),
            ],
        ],
    ];
    final concat = [
          for (var i = 0; i < 14; i++) [...mixed[0][i], ...mixed[1][i]],
        ],
        out = _linear(concat, 'attn.out_proj');
    final r1 = [
          for (var i = 0; i < 14; i++)
            [for (var j = 0; j < 4; j++) x[i][j] + out[i][j]],
        ],
        n2 = _norm(r1, 'norm2'),
        hidden = _linear(
          n2,
          'ff1',
        ).map((r) => r.map((v) => max(0.0, v)).toList()).toList(),
        ff = _linear(hidden, 'ff2');
    final state = [
          for (var i = 0; i < 14; i++)
            [for (var j = 0; j < 4; j++) r1[i][j] + ff[i][j]],
        ],
        prediction = _linear([state[valid - 1]], 'head').single.single;
    final all = {
      'embedding': x,
      'norm1': n,
      'concat': concat,
      'attention': out,
      'residual1': r1,
      'norm2': n2,
      'ff_hidden': hidden,
      'ff_output': ff,
      'state': state,
    };
    for (final m in all.values) {
      for (final r in m) {
        _finite(r);
      }
    }
    _finite([prediction]);
    return AttentionTrace(all, q, k, v, scores, weights, mixed, prediction);
  }
}

DateTime _day(String date) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) {
    throw const FormatException('ISO calendar day');
  }
  final d = DateTime.parse('${date}T00:00:00Z');
  if (d.toIso8601String().substring(0, 10) != date) {
    throw const FormatException('Valid calendar day');
  }
  return d;
}

class AttentionQuery {
  final int targetIndex;
  final String targetDate;
  final List<String> dates;
  final List<double> counts, standardized;
  final double outcome;
  AttentionQuery.fromJson(Map<String, dynamic> j)
    : targetIndex = j['target_index'],
      targetDate = j['target_date'],
      dates = List.unmodifiable(List<String>.from(j['history_dates'])),
      counts = _v(j['counts']),
      standardized = _v(j['standardized']),
      outcome = (j['outcome'] as num).toDouble() {
    _finite([...counts, ...standardized, outcome]);
    if (![365, 400, 540].contains(targetIndex) ||
        dates.length != 14 ||
        counts.length != 14 ||
        standardized.length != 14 ||
        counts.any((v) => v < 0) ||
        outcome < 0) {
      throw const FormatException('Actual historical window');
    }
    final origin = _day(targetDate);
    if (origin.difference(DateTime.utc(2011, 1, 1)).inDays != targetIndex ||
        origin.isAfter(DateTime.utc(2012, 6, 30))) {
      throw const FormatException('Source target date');
    }
    for (var i = 0; i < 14; i++) {
      if (_day(dates[i]) != origin.subtract(Duration(days: 14 - i))) {
        throw const FormatException('Causal calendar dates');
      }
    }
  }
}

class AttentionAssets {
  final AttentionModel model;
  final double mean, scale;
  final List<AttentionQuery> queries;
  AttentionAssets.fromJson(Map<String, dynamic> j)
    : model = AttentionModel.fromJson(j['weights']),
      mean = (j['mean'] as num).toDouble(),
      scale = (j['scale'] as num).toDouble(),
      queries = List.unmodifiable(
        (j['queries'] as List).map((q) => AttentionQuery.fromJson(q)),
      ) {
    _finite([mean, scale]);
    if (scale <= 0 ||
        queries.length != 3 ||
        queries.map((q) => q.targetIndex).toSet().length != 3 ||
        j['lookback'] != 14 ||
        j['width'] != 4 ||
        j['heads'] != 2 ||
        j['ff_width'] != 8 ||
        j['parameter_count'] != 185 ||
        j['dtype'] != 'float64' ||
        j['train_end'] != '2011-12-31' ||
        j['development_end'] != '2012-06-30') {
      throw const FormatException('Attention evidence schema');
    }
    for (final q in queries) {
      for (var i = 0; i < 14; i++) {
        if (((q.counts[i] - mean) / scale - q.standardized[i]).abs() > 1e-10) {
          throw const FormatException('Training-only count transform');
        }
      }
    }
  }
  static AttentionAssets? _cache;
  static Future<AttentionAssets> load() async =>
      _cache ??= AttentionAssets.fromJson(
        jsonDecode(
          await rootBundle.loadString(
            'assets/datasets/bike_sharing/attention_lab.json',
          ),
        ),
      );
}
