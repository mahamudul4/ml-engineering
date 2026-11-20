import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

const lmPad = 256, lmBos = 257, lmEos = 258, lmVocab = 259, lmContext = 32;
typedef LMMatrix = List<List<double>>;
typedef LMHeads = List<LMMatrix>;
List<double> _v(dynamic x) =>
    List<double>.unmodifiable((x as List).map((v) => (v as num).toDouble()));
LMMatrix _m(dynamic x) => List<List<double>>.unmodifiable((x as List).map(_v));
void _finite(Iterable<double> x) {
  if (x.any((v) => !v.isFinite)) {
    throw ArgumentError('Finite decoder arithmetic');
  }
}

class BytePairMerge {
  final int left, right, id, count;
  BytePairMerge.fromJson(Map<String, dynamic> j)
    : left = j['pair'][0],
      right = j['pair'][1],
      id = j['id'],
      count = j['count'];
}

class ByteTokenizer {
  final List<BytePairMerge> merges;
  final Map<int, List<int>> pieces;
  ByteTokenizer._(this.merges, this.pieces);
  factory ByteTokenizer.fromJson(List<dynamic> rows) {
    final merges = List<BytePairMerge>.unmodifiable(
          rows.map((m) => BytePairMerge.fromJson(m)),
        ),
        pieces = <int, List<int>>{
          for (var i = 0; i < 256; i++) i: List<int>.unmodifiable([i]),
        };
    if (merges.length != 16) {
      throw const FormatException('Sixteen bounded demonstration merges');
    }
    for (var i = 0; i < merges.length; i++) {
      final m = merges[i];
      if (m.id != 259 + i ||
          m.count < 1 ||
          !pieces.containsKey(m.left) ||
          !pieces.containsKey(m.right)) {
        throw const FormatException('Ranked byte-pair vocabulary');
      }
      pieces[m.id] = List.unmodifiable([
        ...pieces[m.left]!,
        ...pieces[m.right]!,
      ]);
    }
    return ByteTokenizer._(merges, Map.unmodifiable(pieces));
  }
  List<int> encode(String text, {bool bpe = false}) {
    List<int> ids = utf8.encode(text);
    if (ids.length > 4096) {
      throw ArgumentError('Tokenizer inspection budget4096 bytes');
    }
    if (bpe) {
      for (final m in merges) {
        final next = <int>[];
        for (var i = 0; i < ids.length;) {
          if (i + 1 < ids.length && ids[i] == m.left && ids[i + 1] == m.right) {
            next.add(m.id);
            i += 2;
          } else {
            next.add(ids[i]);
            i++;
          }
        }
        ids = next;
      }
    }
    return List.unmodifiable(ids);
  }

  List<int> decodeBytes(List<int> ids) {
    final out = <int>[];
    for (final id in ids) {
      final p = pieces[id];
      if (p == null) {
        throw ArgumentError('Byte/BPE token ID,not a neural special');
      }
      out.addAll(p);
    }
    return List.unmodifiable(out);
  }

  String decode(List<int> ids) => utf8.decode(decodeBytes(ids));
}

List<double> lmDistribution(
  List<double> logits, {
  double temperature = 1,
  int topK = 0,
  double topP = 1,
}) {
  if (logits.length != 259 ||
      !temperature.isFinite ||
      temperature <= 0 ||
      ![0, 5, 20].contains(topK) ||
      !topP.isFinite ||
      topP <= 0 ||
      topP > 1) {
    throw ArgumentError('259 logits,finite temperature>0,k0/5/20,p(0,1]');
  }
  _finite(logits);
  final order =
      [
        for (var i = 0; i < 259; i++)
          if (i != lmPad && i != lmBos) i,
      ]..sort((a, b) {
        final c = logits[b].compareTo(logits[a]);
        return c == 0 ? a.compareTo(b) : c;
      });
  final keep = topK == 0 ? order : order.take(topK).toList(),
      highest = logits[keep.first];
  final values = [
        for (final id in keep) exp((logits[id] - highest) / temperature),
      ],
      sum = values.reduce((a, b) => a + b),
      prob = values.map((v) => v / sum).toList();
  var count = keep.length;
  if (topP < 1) {
    var cumulative = 0.0;
    for (var i = 0; i < keep.length; i++) {
      cumulative += prob[i];
      if (cumulative >= topP) {
        count = i + 1;
        break;
      }
    }
  }
  final mass = prob.take(count).reduce((a, b) => a + b),
      result = List.filled(259, 0.0);
  for (var i = 0; i < count; i++) {
    result[keep[i]] = prob[i] / mass;
  }
  return List.unmodifiable(result);
}

int lmChoose(List<double> probability, double u) {
  if (probability.length != 259 ||
      !u.isFinite ||
      u < 0 ||
      u >= 1 ||
      probability.any((v) => !v.isFinite || v < 0) ||
      (probability.reduce((a, b) => a + b) - 1).abs() > 1e-10) {
    throw ArgumentError('Probability259 and uniform draw[0,1)');
  }
  var cumulative = 0.0, last = -1;
  for (var i = 0; i < 259; i++) {
    if (probability[i] > 0) {
      last = i;
    }
    cumulative += probability[i];
    if (u < cumulative) {
      return i;
    }
  }
  return last;
}

List<double> lmUniforms({int seed = 22, int count = 8}) {
  if (seed < 0 || seed > 0xffffffff || count < 1 || count > 32) {
    throw ArgumentError('Declared32-bit seed and count1..32');
  }
  var state = seed;
  return List.unmodifiable([
    for (var i = 0; i < count; i++)
      ((state = (1664525 * state + 1013904223) & 0xffffffff) + .5) / 4294967296,
  ]);
}

class LMTrace {
  final Map<String, LMMatrix> matrices;
  final LMHeads weights;
  LMTrace(Map<String, LMMatrix> m, LMHeads a)
    : matrices = Map.unmodifiable(m.map((k, v) => MapEntry(k, _m(v)))),
      weights = List.unmodifiable(a.map(_m));
}

class ByteDecoderModel {
  final Map<String, LMMatrix> matrices;
  final Map<String, List<double>> vectors;
  ByteDecoderModel.fromJson(Map<String, dynamic> raw)
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
      'embedding.weight': [259, 8],
      'attn.in_proj_weight': [24, 8],
      'attn.out_proj.weight': [8, 8],
      'ff1.weight': [16, 8],
      'ff2.weight': [8, 16],
      'head.weight': [259, 8],
      'position': [32, 8],
    };
    const sizes = {
      'norm1.weight': 8,
      'norm1.bias': 8,
      'attn.in_proj_bias': 24,
      'attn.out_proj.bias': 8,
      'norm2.weight': 8,
      'norm2.bias': 8,
      'ff1.bias': 16,
      'ff2.bias': 8,
      'final_norm.weight': 8,
      'final_norm.bias': 8,
      'head.bias': 259,
    };
    if (raw.length != 18 || matrices.length != 7 || vectors.length != 11) {
      throw const FormatException('Byte decoder state layout');
    }
    for (final e in shapes.entries) {
      final m = matrices[e.key];
      if (m == null ||
          m.length != e.value[0] ||
          m.any((r) => r.length != e.value[1])) {
        throw const FormatException('Decoder matrix shape');
      }
      for (final r in m) {
        _finite(r);
      }
    }
    for (final e in sizes.entries) {
      final v = vectors[e.key];
      if (v == null || v.length != e.value) {
        throw const FormatException('Decoder vector shape');
      }
      _finite(v);
    }
    for (var i = 0; i < 32; i++) {
      for (var d = 0; d < 8; d++) {
        final angle = i / pow(10000, 2 * (d ~/ 2) / 8),
            expected = d.isEven ? sin(angle) : cos(angle);
        if ((matrices['position']![i][d] - expected).abs() > 1e-12) {
          throw const FormatException('Sinusoidal context offsets');
        }
      }
    }
    if (matrices['embedding.weight']![lmPad].any((v) => v != 0)) {
      throw const FormatException('Zero PAD embedding row');
    }
  }
  LMMatrix _linear(LMMatrix x, String key) {
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

  LMMatrix _norm(LMMatrix x, String key) => [
    for (final r in x)
      _normRow(r, vectors['$key.weight']!, vectors['$key.bias']!),
  ];
  List<double> _normRow(List<double> x, List<double> w, List<double> b) {
    _finite(x);
    final mean = x.reduce((a, b) => a + b) / 8,
        variance =
            x.map((v) => pow(v - mean, 2).toDouble()).reduce((a, b) => a + b) /
            8;
    _finite([mean, variance]);
    return [
      for (var i = 0; i < 8; i++)
        (x[i] - mean) / sqrt(variance + 1e-5) * w[i] + b[i],
    ];
  }

  LMTrace run(List<int> ids, {bool causal = true}) {
    if (ids.isEmpty ||
        ids.length > 32 ||
        ids.first == lmPad ||
        ids.any((id) => id < 0 || id >= 259)) {
      throw ArgumentError('Nonempty context<=32,IDs0..258,first key nonpad');
    }
    final T = ids.length,
        x = [
          for (var i = 0; i < T; i++)
            [
              for (var j = 0; j < 8; j++)
                matrices['embedding.weight']![ids[i]][j] +
                    matrices['position']![i][j],
            ],
        ],
        n = _norm(x, 'norm1');
    final iw = matrices['attn.in_proj_weight']!,
        ib = vectors['attn.in_proj_bias']!,
        packed = [
          for (final r in n)
            [
              for (var j = 0; j < 24; j++)
                ib[j] +
                    List.generate(
                      8,
                      (k) => r[k] * iw[j][k],
                    ).fold(0.0, (s, v) => s + v),
            ],
        ];
    LMHeads split(int offset) => [
      for (var h = 0; h < 2; h++)
        [
          for (final r in packed)
            [for (var d = 0; d < 4; d++) r[offset + h * 4 + d]],
        ],
    ];
    final q = split(0), k = split(8), v = split(16), attention = <LMMatrix>[];
    for (var h = 0; h < 2; h++) {
      final rows = <List<double>>[];
      for (var i = 0; i < T; i++) {
        final scores = [
          for (var j = 0; j < T; j++)
            List.generate(
                  4,
                  (d) => q[h][i][d] * k[h][j][d],
                ).fold(0.0, (s, v) => s + v) /
                2,
        ];
        _finite(scores);
        final allowed = [
              for (var j = 0; j < T; j++)
                ids[j] != lmPad && (!causal || j <= i),
            ],
            maximum = [
              for (var j = 0; j < T; j++)
                if (allowed[j]) scores[j],
            ].reduce(max);
        final ex = [
              for (var j = 0; j < T; j++)
                allowed[j] ? exp(scores[j] - maximum) : 0.0,
            ],
            sum = ex.reduce((a, b) => a + b);
        rows.add(ex.map((v) => v / sum).toList());
      }
      attention.add(rows);
    }
    final mixed = [
          for (var i = 0; i < T; i++)
            [
              for (var h = 0; h < 2; h++)
                for (var d = 0; d < 4; d++)
                  List.generate(
                    T,
                    (j) => attention[h][i][j] * v[h][j][d],
                  ).fold(0.0, (s, v) => s + v),
            ],
        ],
        out = _linear(mixed, 'attn.out_proj');
    final r1 = [
          for (var i = 0; i < T; i++)
            [for (var d = 0; d < 8; d++) x[i][d] + out[i][d]],
        ],
        n2 = _norm(r1, 'norm2'),
        hidden = _linear(
          n2,
          'ff1',
        ).map((r) => r.map((v) => max(0.0, v)).toList()).toList(),
        ff = _linear(hidden, 'ff2');
    final state = [
          for (var i = 0; i < T; i++)
            [for (var d = 0; d < 8; d++) r1[i][d] + ff[i][d]],
        ],
        normalized = _norm(state, 'final_norm'),
        logits = _linear(normalized, 'head');
    final all = {
      'embedding': x,
      'norm1': n,
      'attention': out,
      'residual1': r1,
      'norm2': n2,
      'ff_hidden': hidden,
      'ff_output': ff,
      'state': state,
      'normalized': normalized,
      'logits': logits,
    };
    for (final m in all.values) {
      for (final row in m) {
        _finite(row);
      }
    }
    return LMTrace(all, attention);
  }

  double lastTokenLogitGap({
    required List<double> residual,
    required List<double> ffnUpdate,
    required int target,
    required int contrast,
  }) {
    if (residual.length != 8 || ffnUpdate.length != residual.length) {
      throw const FormatException('Byte decoder residual and FFN width');
    }
    final state = [
      for (var coordinate = 0; coordinate < residual.length; coordinate++)
        residual[coordinate] + ffnUpdate[coordinate],
    ];
    final logits = _linear(_norm([state], 'final_norm'), 'head').single;
    return logits[target] - logits[contrast];
  }

  List<int> generate(
    List<int> prefix, {
    String mode = 'sample',
    double temperature = 1,
    int topK = 0,
    double topP = 1,
  }) {
    if (prefix.isEmpty ||
        prefix.length > 24 ||
        prefix.contains(lmPad) ||
        !['sample', 'greedy'].contains(mode)) {
      throw ArgumentError('Prefix<=24,mode sample/greedy');
    }
    final ids = [...prefix], next = <int>[];
    for (final u in lmUniforms()) {
      final p = lmDistribution(
        run(ids).matrices['logits']!.last,
        temperature: temperature,
        topK: topK,
        topP: topP,
      );
      var token = 0;
      if (mode == 'greedy') {
        for (var i = 1; i < 259; i++) {
          if (p[i] > p[token]) {
            token = i;
          }
        }
      } else {
        token = lmChoose(p, u);
      }
      next.add(token);
      ids.add(token);
      if (token == lmEos) {
        break;
      }
    }
    return List.unmodifiable(next);
  }
}

class LMPrefix {
  final int sourceChapter;
  final String role, text;
  final List<int> ids, targets;
  LMPrefix.fromJson(Map<String, dynamic> j)
    : sourceChapter = j['source_chapter'],
      role = j['role'],
      text = j['text'],
      ids = List.unmodifiable(List<int>.from(j['ids'])),
      targets = List.unmodifiable(List<int>.from(j['targets'])) {
    final bytes = utf8.encode(text);
    if (![1, 3, 9].contains(sourceChapter) ||
        role != (sourceChapter < 9 ? 'fit' : 'validation') ||
        ids.length < 2 ||
        ids.length > 24 ||
        ids.first != lmBos ||
        ids.length != bytes.length + 1 ||
        targets.length != ids.length ||
        targets.any((id) => id < 0 || id > 255) ||
        !List.generate(
          bytes.length,
          (i) => ids[i + 1] == bytes[i] && targets[i] == bytes[i],
        ).every((v) => v)) {
      throw const FormatException('Actual shifted byte prefix');
    }
  }
}

class LLMAssets {
  final ByteTokenizer tokenizer;
  final ByteDecoderModel model;
  final List<LMPrefix> samples;
  final List<String> examples;
  LLMAssets.fromJson(Map<String, dynamic> j)
    : tokenizer = ByteTokenizer.fromJson(j['merges']),
      model = ByteDecoderModel.fromJson(j['weights']),
      samples = List.unmodifiable(
        (j['samples'] as List).map((s) => LMPrefix.fromJson(s)),
      ),
      examples = List.unmodifiable(
        (j['examples'] as List).map((e) => e['text'] as String),
      ) {
    if (j['parameters'] != 5019 ||
        j['context'] != 32 ||
        j['vocab'] != 259 ||
        j['width'] != 8 ||
        j['heads'] != 2 ||
        j['ff_width'] != 16 ||
        j['dtype'] != 'float64' ||
        j['special_ids']['pad'] != 256 ||
        j['special_ids']['bos'] != 257 ||
        j['special_ids']['eos'] != 258 ||
        samples.length != 3 ||
        samples.map((s) => s.sourceChapter).toSet().length != 3 ||
        examples.length != 3) {
      throw const FormatException('Bounded byte-decoder evidence');
    }
    for (final e in j['examples'] as List) {
      if (tokenizer.decode(tokenizer.encode(e['text'], bpe: true)) !=
              e['text'] ||
          jsonEncode(tokenizer.encode(e['text'], bpe: true)) !=
              jsonEncode(e['bpe_ids']) ||
          jsonEncode(tokenizer.encode(e['text'])) != jsonEncode(e['bytes'])) {
        throw const FormatException('Source tokenization round-trip');
      }
    }
  }
  static LLMAssets? _cache;
  static Future<LLMAssets> load() async => _cache ??= LLMAssets.fromJson(
    jsonDecode(
      await rootBundle.loadString('assets/datasets/alice/llm_lab.json'),
    ),
  );
}
