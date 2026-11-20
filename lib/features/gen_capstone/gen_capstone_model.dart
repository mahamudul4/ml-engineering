import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

import '../rag/rag_model.dart';

List<double> _v(dynamic x) =>
    (x as List).map((n) => (n as num).toDouble()).toList();
void _finite(List<double> x, int n) {
  if (x.length != n || x.any((v) => !v.isFinite)) {
    throw ArgumentError('Expected $n finite values');
  }
}

dynamic _freeze(dynamic x) => x is Map
    ? Map<String, dynamic>.unmodifiable(
        x.map((k, v) => MapEntry(k as String, _freeze(v))),
      )
    : x is List
    ? List<dynamic>.unmodifiable(x.map(_freeze))
    : x;
int capstoneBucket(String word) {
  var h = 2166136261;
  for (final b in ascii.encode(word)) {
    h = ((h ^ b) * 16777619) & 0xffffffff;
  }
  return h % 128;
}

List<double> _block(String text) {
  final x = List.filled(128, 0.0);
  for (final match in RegExp(r'[A-Za-z0-9]+').allMatches(text)) {
    x[capstoneBucket(match[0]!.toLowerCase())]++;
  }
  for (var i = 0; i < 128; i++) {
    x[i] = math.log(1 + x[i]);
  }
  final norm = math.sqrt(x.fold<double>(0, (n, v) => n + v * v));
  return norm == 0 ? x : x.map((v) => v / norm).toList();
}

List<double> capstoneFeatures(String query, String context) =>
    List.unmodifiable([..._block(query), ..._block(context)]);
double _sigmoid(double v) =>
    v >= 0 ? 1 / (1 + math.exp(-v)) : math.exp(v) / (1 + math.exp(v));
double _tanh(double v) => 2 * _sigmoid(2 * v) - 1;

class ResponseTrace {
  final int previous, chosen;
  final List<double> probabilities, hidden;
  ResponseTrace(this.previous, this.chosen, List<double> p, List<double> h)
    : probabilities = List.unmodifiable(p),
      hidden = List.unmodifiable(h);
}

class GeneratedResponse {
  final String text;
  final bool ended;
  final List<int> ids;
  final List<double> initialHidden;
  final List<ResponseTrace> trace;
  GeneratedResponse(
    this.text,
    this.ended,
    List<int> ids,
    List<double> h,
    List<ResponseTrace> trace,
  ) : ids = List.unmodifiable(ids),
      initialHidden = List.unmodifiable(h),
      trace = List.unmodifiable(trace);
  bool get formatValid => ended && ['support', 'contradict'].contains(text);
  double get confidence => trace.first.probabilities.reduce(math.max);
}

String capstoneDecision({
  required bool hasContext,
  required bool quotesExact,
  required bool formatValid,
  required double confidence,
  double threshold = 0,
}) {
  if (!threshold.isFinite ||
      threshold < 0 ||
      threshold > 1 ||
      !confidence.isFinite ||
      confidence < 0 ||
      confidence > 1) {
    throw ArgumentError('Probabilities/threshold0..1');
  }
  return !hasContext
      ? 'no_context'
      : !quotesExact
      ? 'citation_mismatch'
      : !formatValid
      ? 'invalid_format'
      : confidence < threshold
      ? 'low_confidence'
      : 'unverified_hypothesis';
}

Map<String, dynamic> capstoneScore(List<dynamic> rows, {double threshold = 0}) {
  if (rows.isEmpty) {
    throw ArgumentError('Nonempty diagnostic rows');
  }
  var valid = 0,
      correct = 0,
      hit = 0,
      joint = 0,
      accepted = 0,
      acceptedCorrect = 0;
  for (final r in rows) {
    final g = r['generation'];
    final good = g['format_valid'] as bool;
    final right = good && g['text'] == r['gold'];
    if (good) valid++;
    if (right) correct++;
    if (r['rationale_hit'] == 1) {
      hit++;
      if (right) joint++;
    }
    final d = capstoneDecision(
      hasContext: r['has_context'],
      quotesExact: true,
      formatValid: good,
      confidence: (g['first_token_confidence'] as num).toDouble(),
      threshold: threshold,
    );
    if (d == 'unverified_hypothesis') {
      accepted++;
      if (right) acceptedCorrect++;
    }
  }
  return Map.unmodifiable({
    'n': rows.length,
    'valid': valid,
    'correct': correct,
    'accuracy': correct / rows.length,
    'complete_rationale_hits': hit,
    'joint_hits': joint,
    'accepted': accepted,
    'coverage': accepted / rows.length,
    'accepted_accuracy': accepted == 0 ? null : acceptedCorrect / accepted,
    'accepted_risk': accepted == 0 ? null : 1 - acceptedCorrect / accepted,
  });
}

class GenCapstoneAssets {
  static GenCapstoneAssets? _cached;
  static Future<GenCapstoneAssets>? _pending;
  final Map<String, dynamic> data;
  final RAGAssets rag;
  GenCapstoneAssets.fromJson(Map<String, dynamic> j, this.rag)
    : data = _freeze(j) {
    if (vocabulary.join('|') != '<PAD>|<BOS>|<EOS>|a|c|d|i|n|o|p|r|s|t|u') {
      throw const FormatException('Decoder vocabulary');
    }
    for (final s in [
      ('condition.weight', 16, 256),
      ('embedding.weight', 14, 8),
      ('cell.weight_ih', 48, 8),
      ('cell.weight_hh', 48, 16),
      ('head.weight', 14, 16),
    ]) {
      final rows = data['weights'][s.$1] as List;
      if (rows.length != s.$2) {
        throw const FormatException('Weight rows');
      }
      for (final row in rows) {
        _finite(_v(row), s.$3);
      }
    }
    for (final s in [
      ('condition.bias', 16),
      ('cell.bias_ih', 48),
      ('cell.bias_hh', 48),
      ('head.bias', 14),
    ]) {
      _finite(_v(data['weights'][s.$1]), s.$2);
    }
    if (samples.length != 6) {
      throw const FormatException('Six source cases');
    }
  }
  static Future<GenCapstoneAssets> load() async =>
      _cached ??= await (_pending ??= _load());
  static Future<GenCapstoneAssets> _load() async {
    final rag = await RAGAssets.load();
    return GenCapstoneAssets.fromJson(
      jsonDecode(
        await rootBundle.loadString(
          'assets/datasets/scifact_rag/capstone_lab.json',
        ),
      ),
      rag,
    );
  }

  List<String> get vocabulary =>
      List.unmodifiable((data['vocabulary'] as List).cast<String>());
  List<dynamic> get samples => data['samples'];
  Map<String, dynamic> get report => data['report'];
  List<double> _affine(String key, List<double> x, String bias) {
    final rows = data['weights'][key] as List, b = _v(data['weights'][bias]);
    _finite(x, (rows.first as List).length);
    final r = List.generate(rows.length, (i) {
      final row = _v(rows[i]);
      var n = b[i];
      for (var j = 0; j < x.length; j++) {
        n += row[j] * x[j];
      }
      return n;
    });
    _finite(r, r.length);
    return r;
  }

  List<double> initial(List<double> x) => List.unmodifiable(
    _affine('condition.weight', x, 'condition.bias').map(_tanh),
  );
  ResponseTrace step(int token, List<double> h) {
    if (token < 0 || token >= 14) {
      throw ArgumentError('Token0..13');
    }
    _finite(h, 16);
    final embed = _v(data['weights']['embedding.weight'][token]);
    final input = _affine('cell.weight_ih', embed, 'cell.bias_ih'),
        hidden = _affine('cell.weight_hh', h, 'cell.bias_hh');
    final next = List.generate(16, (j) {
      final r = _sigmoid(input[j] + hidden[j]),
          z = _sigmoid(input[16 + j] + hidden[16 + j]),
          n = _tanh(input[32 + j] + r * hidden[32 + j]);
      return (1 - z) * n + z * h[j];
    });
    final logits = _affine('head.weight', next, 'head.bias'),
        max = logits.sublist(2).reduce(math.max);
    final exp = List.generate(
      14,
      (i) => i < 2 ? 0.0 : math.exp(logits[i] - max),
    );
    final sum = exp.reduce((a, b) => a + b);
    final p = exp.map((v) => v / sum).toList();
    var chosen = 2;
    for (var i = 3; i < 14; i++) {
      if (p[i] > p[chosen]) chosen = i;
    }
    return ResponseTrace(token, chosen, p, next);
  }

  GeneratedResponse generate(List<double> features) {
    final start = initial(features);
    var h = start, token = 1;
    final ids = <int>[], trace = <ResponseTrace>[];
    for (var t = 0; t < 12; t++) {
      final s = step(token, h);
      trace.add(s);
      ids.add(s.chosen);
      h = s.hidden;
      token = s.chosen;
      if (token == 2) break;
    }
    return GeneratedResponse(
      ids.where((i) => i >= 3).map((i) => vocabulary[i]).join(),
      ids.last == 2,
      ids,
      start,
      trace,
    );
  }

  static List<double> vector(dynamic x) => _v(x);
}
