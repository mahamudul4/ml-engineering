import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

class ReliabilityRow {
  final String id, text;
  final int gold, inputTokens, outputTokens;
  final double probability;
  ReliabilityRow(
    this.id,
    this.text,
    this.gold,
    this.probability,
    this.inputTokens,
    this.outputTokens,
  );
  factory ReliabilityRow.fromJson(Map<String, dynamic> j) => ReliabilityRow(
    j['id'],
    j['text'],
    j['gold'],
    (j['p_support'] as num).toDouble(),
    j['input_tokens'],
    j['output_tokens'],
  );
}

void _validate(List<ReliabilityRow> rows) {
  if (rows.isEmpty ||
      rows.map((r) => r.id).toSet().length != rows.length ||
      rows.any(
        (r) =>
            ![0, 1].contains(r.gold) ||
            !r.probability.isFinite ||
            r.probability < 0 ||
            r.probability > 1,
      )) {
    throw ArgumentError(
      'Nonempty unique IDs,binary gold,finite probability0..1',
    );
  }
}

Map<String, dynamic> selectiveAudit(
  List<ReliabilityRow> rows,
  double threshold,
) {
  _validate(rows);
  if (!threshold.isFinite || threshold < .5 || threshold > 1) {
    throw ArgumentError('Threshold.5..1');
  }
  final accepted = rows
          .where((r) => math.max(r.probability, 1 - r.probability) >= threshold)
          .toList(),
      correct = accepted
          .where((r) => (r.probability >= .5 ? 1 : 0) == r.gold)
          .length;
  return Map.unmodifiable({
    'threshold': threshold,
    'accepted': accepted.length,
    'correct': correct,
    'coverage': accepted.length / rows.length,
    'accuracy': accepted.isEmpty ? null : correct / accepted.length,
    'risk': accepted.isEmpty ? null : 1 - correct / accepted.length,
  });
}

Map<String, dynamic> reliabilityAudit(
  List<ReliabilityRow> rows, {
  int bins = 5,
}) {
  _validate(rows);
  if (bins < 1 || bins > 20) {
    throw ArgumentError('Bins1..20');
  }
  var tp = 0, tn = 0, fp = 0, fn = 0;
  var brier = 0.0, nll = 0.0, ece = 0.0;
  final table = [
    for (var i = 0; i < bins; i++)
      <String, dynamic>{
        'index': i,
        'count': 0,
        'correct': 0,
        'confidence_sum': 0.0,
      },
  ];
  for (final r in rows) {
    final pred = r.probability >= .5 ? 1 : 0,
        confidence = math.max(r.probability, 1 - r.probability);
    if (pred == 1 && r.gold == 1) {
      tp++;
    } else if (pred == 0 && r.gold == 0) {
      tn++;
    } else if (pred == 1) {
      fp++;
    } else {
      fn++;
    }
    final bucket = table[math.min((confidence * bins).floor(), bins - 1)];
    bucket['count']++;
    bucket['correct'] += pred == r.gold ? 1 : 0;
    bucket['confidence_sum'] += confidence;
    brier += math.pow(r.probability - r.gold, 2);
    nll -= math.log(
      (r.gold == 1 ? r.probability : 1 - r.probability).clamp(1e-15, 1 - 1e-15),
    );
  }
  for (final b in table) {
    final n = b['count'] as int;
    b['accuracy'] = n == 0 ? null : b['correct'] / n;
    b['mean_confidence'] = n == 0 ? null : b['confidence_sum'] / n;
    b['gap'] = n == 0 ? null : (b['accuracy'] - b['mean_confidence']).abs();
    if (n > 0) {
      ece += n / rows.length * (b['gap'] as num);
    }
  }
  return Map.unmodifiable({
    'queries': rows.length,
    'tp': tp,
    'tn': tn,
    'fp': fp,
    'fn': fn,
    'accuracy': (tp + tn) / rows.length,
    'support_recall': tp + fn == 0 ? null : tp / (tp + fn),
    'contradict_recall': tn + fp == 0 ? null : tn / (tn + fp),
    'precision': tp + fp == 0 ? null : tp / (tp + fp),
    'brier': brier / rows.length,
    'binary_nll_clipped': nll / rows.length,
    'ece': ece,
    'bins': List.unmodifiable(table.map(Map<String, dynamic>.unmodifiable)),
    'sweep': List.unmodifiable([
      for (final t in [.5, .6, .7, .8, .9, .95]) selectiveAudit(rows, t),
    ]),
  });
}

class ServingRequest {
  final String id;
  final int inputTokens, outputTokens;
  const ServingRequest(this.id, this.inputTokens, this.outputTokens);
}

Map<String, dynamic> servingReplay(
  List<ServingRequest> requests, {
  int batchSize = 1,
  double interval = 5,
  double prefill = .4,
  double decode = 1.2,
  double overhead = 2,
}) {
  if (requests.isEmpty ||
      batchSize < 1 ||
      batchSize > 16 ||
      [interval, prefill, decode, overhead].any((v) => !v.isFinite || v < 0) ||
      requests.any(
        (r) =>
            r.inputTokens < 1 ||
            r.inputTokens > 32 ||
            r.outputTokens < 1 ||
            r.outputTokens > 8,
      )) {
    throw ArgumentError(
      'Nonempty valid token counts,batch1..16,finite nonnegative costs',
    );
  }
  var clock = 0.0;
  final rows = <Map<String, dynamic>>[];
  for (var begin = 0; begin < requests.length; begin += batchSize) {
    final group = requests.sublist(
          begin,
          math.min(begin + batchSize, requests.length),
        ),
        start = math.max(clock, (begin + group.length - 1) * interval),
        prefillTime =
            overhead +
            group.map((r) => r.inputTokens).reduce(math.max) * prefill,
        first = start + prefillTime + decode,
        finish =
            start +
            prefillTime +
            group.map((r) => r.outputTokens).reduce(math.max) * decode;
    for (var i = 0; i < group.length; i++) {
      final arrival = (begin + i) * interval;
      rows.add(
        Map.unmodifiable({
          'id': group[i].id,
          'arrival_ms': arrival,
          'start_ms': start,
          'queue_ms': start - arrival,
          'ttft_ms': first - arrival,
          'latency_ms': finish - arrival,
          'finish_ms': finish,
        }),
      );
    }
    clock = finish;
  }
  final latencies = rows.map((r) => r['latency_ms'] as double).toList()..sort();
  double percentile(double p) =>
      latencies[math.max(0, (p * latencies.length).ceil() - 1)];
  return Map.unmodifiable({
    'assumptions': Map.unmodifiable({
      'batch_size': batchSize,
      'interval_ms': interval,
      'prefill_ms_per_input_token': prefill,
      'decode_ms_per_output_token': decode,
      'batch_overhead_ms': overhead,
      'scheduler': 'consecutive fixed groups wait for last member;one serial worker;ideal padded batch compute',
    }),
    'requests': rows.length,
    'makespan_ms': clock,
    'throughput_per_second': clock == 0 ? null : rows.length * 1000 / clock,
    'p50_ms': percentile(.5),
    'p95_ms': percentile(.95),
    'mean_ttft_ms':
        rows.fold<double>(0, (s, r) => s + (r['ttft_ms'] as double)) /
        rows.length,
    'rows': List.unmodifiable(rows),
  });
}

String reliabilityCacheKey(
  String query,
  String model,
  String corpus,
  String prompt,
  String permission,
  String decoding,
) {
  final fields = [query, model, corpus, prompt, permission, decoding];
  if (fields.any((s) => s.isEmpty)) {
    throw ArgumentError('Six nonempty scope/version fields');
  }
  return jsonEncode(fields);
}

class ReliabilityAssets {
  final Map<String, List<ReliabilityRow>> variants;
  final List<ServingRequest> requests;
  final Map<String, dynamic> report;
  ReliabilityAssets._(this.variants, this.requests, this.report);
  static ReliabilityAssets? _cached;
  static Future<ReliabilityAssets>? _pending;
  static Future<ReliabilityAssets> load() async =>
      _cached ??= await (_pending ??= _load());
  static Future<ReliabilityAssets> _load() async {
    final j = jsonDecode(
      await rootBundle.loadString(
        'assets/datasets/scifact_rag/reliability_lab.json',
      ),
    );
    final variants = Map<String, List<ReliabilityRow>>.unmodifiable(
      (j['variants'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(
          k,
          List<ReliabilityRow>.unmodifiable(
            (v['rows'] as List).map((r) => ReliabilityRow.fromJson(r)),
          ),
        ),
      ),
    );
    if (variants.length != 3 ||
        !variants.keys.toSet().containsAll(['base', 'full', 'lora']) ||
        variants.values.any((r) => r.length != 188) ||
        j['report']['ece_bins'] != 5) {
      throw const FormatException('Frozen188-query,three-model audit');
    }
    for (final rows in variants.values) {
      _validate(rows);
    }
    final ids = variants['base']!.map((r) => r.id).join(',');
    if (variants.values.any((r) => r.map((q) => q.id).join(',') != ids)) {
      throw const FormatException('Paired query ordering');
    }
    final requests = List<ServingRequest>.unmodifiable(
      (j['requests'] as List).map(
        (r) => ServingRequest(r['id'], r['input_tokens'], r['output_tokens']),
      ),
    );
    if (requests.length != 40) {
      throw const FormatException('Forty actual source requests');
    }
    servingReplay(requests);
    return ReliabilityAssets._(
      variants,
      requests,
      Map.unmodifiable(j['report']),
    );
  }
}
