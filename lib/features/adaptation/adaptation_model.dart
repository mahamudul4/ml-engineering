import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

import '../llm/llm_model.dart';

List<int> adaptationPrefix(String text) =>
    List.unmodifiable([257, ...utf8.encode(text).take(24), 10]);
double responseNLL(List<double> logits, int target) {
  if (logits.length != 259 ||
      logits.any((v) => !v.isFinite) ||
      ![83, 67].contains(target)) {
    throw ArgumentError('Finite259 logits and S/C target');
  }
  final allowed = [
        for (var i = 0; i < 259; i++)
          if (i != 256 && i != 257) logits[i],
      ],
      maximum = allowed.reduce(math.max);
  return maximum +
      math.log(allowed.fold<double>(0, (s, v) => s + math.exp(v - maximum))) -
      logits[target];
}

double supportProbability(List<double> logits) {
  if (logits.length != 259 || logits.any((v) => !v.isFinite)) {
    throw ArgumentError('Finite259 logits');
  }
  final highest = math.max(logits[83], logits[67]),
      s = math.exp(logits[83] - highest),
      c = math.exp(logits[67] - highest);
  return s / (s + c);
}

List<List<double>> adapterDelta(
  List<List<double>> a,
  List<List<double>> b, {
  double scale = 1,
}) {
  if (a.length != 2 ||
      a.any((r) => r.length != 8 || r.any((v) => !v.isFinite)) ||
      b.length != 259 ||
      b.any((r) => r.length != 2 || r.any((v) => !v.isFinite)) ||
      !scale.isFinite) {
    throw ArgumentError('Finite A2x8,B259x2,scale');
  }
  return List.unmodifiable([
    for (final row in b)
      List<double>.unmodifiable([
        for (var j = 0; j < 8; j++)
          scale * (row[0] * a[0][j] + row[1] * a[1][j]),
      ]),
  ]);
}

class AdaptationSample {
  final String id, role, text, label;
  final List<int> ids;
  AdaptationSample.fromJson(Map<String, dynamic> j)
    : id = j['id'],
      role = j['role'],
      text = j['text'],
      label = j['label'],
      ids = List.unmodifiable(List<int>.from(j['ids']));
}

class AdaptationAssets {
  final Map<String, ByteDecoderModel> models;
  final List<List<double>> a, b;
  final List<AdaptationSample> samples;
  final Map<String, dynamic> report, history;
  AdaptationAssets._(
    this.models,
    this.a,
    this.b,
    this.samples,
    this.report,
    this.history,
  );
  static AdaptationAssets? _cached;
  static Future<AdaptationAssets>? _pending;
  static Future<AdaptationAssets> load() async =>
      _cached ??= await (_pending ??= _load());
  static Future<AdaptationAssets> _load() async {
    final j = jsonDecode(
      await rootBundle.loadString(
        'assets/datasets/scifact_rag/adaptation_lab.json',
      ),
    );
    List<List<double>> matrix(dynamic value) => List.unmodifiable(
      (value as List).map(
        (r) => List<double>.unmodifiable(
          (r as List).map((v) => (v as num).toDouble()),
        ),
      ),
    );
    final models = Map<String, ByteDecoderModel>.unmodifiable(
          (j['weights'] as Map<String, dynamic>).map(
            (k, v) => MapEntry(k, ByteDecoderModel.fromJson(v)),
          ),
        ),
        a = matrix(j['adapter']['A']),
        b = matrix(j['adapter']['B']);
    if (models.length != 4 ||
        !models.keys.toSet().containsAll([
          'base',
          'full',
          'lora',
          'int8_head_demo',
        ]) ||
        j['adapter']['rank'] != 2 ||
        j['adapter']['alpha'] != 2 ||
        j['report']['recipe']['no_evidence_input'] != true) {
      throw const FormatException('Fixed adaptation recipe and four models');
    }
    final delta = adapterDelta(a, b),
        base = models['base']!.matrices['head.weight']!,
        merged = models['lora']!.matrices['head.weight']!;
    for (var i = 0; i < 259; i++) {
      for (var k = 0; k < 8; k++) {
        if ((base[i][k] + delta[i][k] - merged[i][k]).abs() > 1e-12) {
          throw const FormatException('LoRA merged/base contract');
        }
      }
    }
    final samples = List<AdaptationSample>.unmodifiable(
      (j['samples'] as List).map((s) => AdaptationSample.fromJson(s)),
    );
    if (samples.length != 6 ||
        samples.any(
          (s) =>
              !['SUPPORT', 'CONTRADICT'].contains(s.label) ||
              jsonEncode(s.ids) != jsonEncode(adaptationPrefix(s.text)),
        )) {
      throw const FormatException('Six actual source prefixes/labels');
    }
    return AdaptationAssets._(
      models,
      a,
      b,
      samples,
      Map.unmodifiable(j['report']),
      Map.unmodifiable(j['history']),
    );
  }

  ByteDecoderModel scaledAdapter(double scale) {
    if (!scale.isFinite || scale < 0 || scale > 2) {
      throw ArgumentError('Adapter scale0..2');
    }
    final base = models['base']!, delta = adapterDelta(a, b, scale: scale);
    final raw = <String, dynamic>{...base.matrices, ...base.vectors};
    raw['head.weight'] = [
      for (var i = 0; i < 259; i++)
        [
          for (var j = 0; j < 8; j++)
            base.matrices['head.weight']![i][j] + delta[i][j],
        ],
    ];
    return ByteDecoderModel.fromJson(raw);
  }
}
