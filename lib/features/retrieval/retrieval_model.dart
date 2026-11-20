import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

const retrievalMethods = ['tfidf', 'lsa', 'hybrid'];
List<double> _vector(dynamic value) => List<double>.unmodifiable(
  (value as List).map((x) => (x as num).toDouble()),
);
void _finite(List<double> x) {
  if (x.isEmpty || x.any((v) => !v.isFinite)) {
    throw ArgumentError('Finite nonempty vector required');
  }
}

List<String> retrievalTokens(String text) => List.unmodifiable(
  RegExp(r'[A-Za-z0-9]+').allMatches(text).map((m) => m[0]!.toLowerCase()),
);
double retrievalDot(List<double> a, List<double> b) {
  _finite(a);
  _finite(b);
  if (a.length != b.length) throw ArgumentError('Same dimensions required');
  var total = 0.0;
  for (var i = 0; i < a.length; i++) {
    total += a[i] * b[i];
  }
  if (!total.isFinite) throw ArgumentError('Finite arithmetic required');
  return total;
}

List<double> retrievalUnit(List<double> x) {
  final norm = math.sqrt(retrievalDot(x, x));
  return List.unmodifiable(x.map((v) => norm > 0 ? v / norm : 0.0));
}

double retrievalCosine(List<double> a, List<double> b) =>
    retrievalDot(retrievalUnit(a), retrievalUnit(b));

class RetrievalHit {
  final String id;
  final double score;
  const RetrievalHit(this.id, this.score);
}

int _compare(RetrievalHit a, RetrievalHit b) {
  final comparison = b.score.compareTo(a.score);
  return comparison != 0
      ? comparison
      : int.parse(a.id).compareTo(int.parse(b.id));
}

List<RetrievalHit> retrievalFuse(
  List<List<RetrievalHit>> lists, {
  int constant = 60,
}) {
  if (constant < 1) throw ArgumentError('Positive RRF constant');
  final totals = <String, double>{};
  for (final hits in lists) {
    if (hits.map((h) => h.id).toSet().length != hits.length) {
      throw ArgumentError('Unique IDs in each candidate list');
    }
    for (var i = 0; i < hits.length; i++) {
      if (!RegExp(r'^\d+$').hasMatch(hits[i].id) || !hits[i].score.isFinite) {
        throw ArgumentError('Numeric document IDs and finite scores');
      }
      totals.update(
        hits[i].id,
        (s) => s + 1 / (constant + i + 1),
        ifAbsent: () => 1 / (constant + i + 1),
      );
    }
  }
  return List.unmodifiable(
    <RetrievalHit>[for (final e in totals.entries) RetrievalHit(e.key, e.value)]
      ..sort(_compare),
  );
}

Map<String, double> retrievalMetrics(
  List<String> ranked,
  Set<String> relevant,
  int k,
) {
  if (k < 1 || relevant.isEmpty || ranked.toSet().length != ranked.length) {
    throw ArgumentError('Positive cutoff,nonempty judgments,unique ranking');
  }
  var hits = 0, first = 0;
  var dcg = 0.0, ideal = 0.0;
  for (var i = 0; i < math.min(k, ranked.length); i++) {
    if (relevant.contains(ranked[i])) {
      hits++;
      if (first == 0) first = i + 1;
      dcg += math.ln2 / math.log(i + 2);
    }
  }
  for (var i = 1; i <= math.min(k, relevant.length); i++) {
    ideal += math.ln2 / math.log(i + 1);
  }
  return Map.unmodifiable({
    'recall': hits / relevant.length,
    'mrr': first > 0 ? 1 / first : 0.0,
    'ndcg': dcg / ideal,
  });
}

class RetrievalDocument {
  final String id, title, text;
  final List<int> indices;
  final List<double> values, dense;
  RetrievalDocument._(
    this.id,
    this.title,
    this.text,
    this.indices,
    this.values,
    this.dense,
  );
}

class RetrievalEncoding {
  final List<int> indices;
  final List<double> values, raw, unit;
  RetrievalEncoding._(this.indices, this.values, this.raw, this.unit);
  bool get outOfVocabulary => indices.isEmpty;
}

class RetrievalIndex {
  final List<String> vocabulary;
  final List<double> idf;
  final List<List<double>> components;
  final List<RetrievalDocument> documents;
  final Map<String, int> _terms;
  final Map<String, RetrievalDocument> byId;
  RetrievalIndex._(
    this.vocabulary,
    this.idf,
    this.components,
    this.documents,
    this._terms,
    this.byId,
  );

  factory RetrievalIndex.fromJson(
    Map<String, dynamic> j,
    List<dynamic> source,
  ) {
    if (j['schema_version'] != 1 ||
        j['recipe']['dimensions'] != 32 ||
        j['recipe']['candidate_depth'] != 100 ||
        j['recipe']['rrf_constant'] != 60 ||
        j['recipe']['vocabulary_cap'] != 4096 ||
        j['recipe']['seed'] != 23) {
      throw const FormatException('Versioned retrieval recipe');
    }
    final vocabulary = List<String>.unmodifiable(j['vocabulary']);
    final idf = _vector(j['idf']);
    final components = List<List<double>>.unmodifiable(
      (j['components'] as List).map(_vector),
    );
    if (vocabulary.length != 4096 ||
        vocabulary.toSet().length != 4096 ||
        vocabulary.any((s) => !RegExp(r'^[a-z0-9]+$').hasMatch(s)) ||
        idf.length != 4096 ||
        idf.any((v) => !v.isFinite || v < 1) ||
        components.length != 32 ||
        components.any((r) => r.length != 4096 || r.any((v) => !v.isFinite))) {
      throw const FormatException('Vocabulary,IDF and32x4096 projection');
    }
    final originals = {for (final d in source) d['_id'] as String: d};
    final rows = j['documents'] as List;
    if (rows.length != 5183 ||
        source.length != 5183 ||
        originals.length != 5183) {
      throw const FormatException('Complete original5183-document corpus');
    }
    final documents = <RetrievalDocument>[];
    final seen = <String>{};
    var previous = -1;
    for (final row in rows) {
      final id = row['id'] as String, original = originals[id];
      final numeric = int.tryParse(id);
      final indices = List<int>.unmodifiable(row['indices']);
      final values = _vector(row['values']), dense = _vector(row['dense']);
      if (numeric == null ||
          numeric <= previous ||
          !seen.add(id) ||
          original == null ||
          indices.length != values.length ||
          indices.toSet().length != indices.length ||
          indices.any((i) => i < 0 || i >= 4096) ||
          values.any((v) => !v.isFinite || v <= 0) ||
          dense.length != 32 ||
          dense.any((v) => !v.isFinite)) {
        throw const FormatException('Aligned immutable document vectors');
      }
      final sparseNorm = values.fold<double>(0, (s, v) => s + v * v);
      final denseNorm = retrievalDot(dense, dense);
      if ((sparseNorm > 0 && (sparseNorm - 1).abs() > 1e-9) ||
          (denseNorm > 0 && (denseNorm - 1).abs() > 1e-9)) {
        throw const FormatException('Zero or L2 unit document vectors');
      }
      documents.add(
        RetrievalDocument._(
          id,
          original['title'],
          original['text'],
          indices,
          values,
          dense,
        ),
      );
      previous = numeric;
    }
    return RetrievalIndex._(
      vocabulary,
      idf,
      components,
      List.unmodifiable(documents),
      Map.unmodifiable({
        for (var i = 0; i < vocabulary.length; i++) vocabulary[i]: i,
      }),
      Map.unmodifiable({for (final d in documents) d.id: d}),
    );
  }

  RetrievalEncoding encode(String text) {
    if (text.length > 4096) {
      throw ArgumentError('Query inspection budget4096 UTF16 units');
    }
    final counts = <int, int>{};
    for (final token in retrievalTokens(text)) {
      final index = _terms[token];
      if (index != null) counts.update(index, (n) => n + 1, ifAbsent: () => 1);
    }
    final indices = counts.keys.toList()..sort();
    final weights = [
      for (final i in indices) (1 + math.log(counts[i]!)) * idf[i],
    ];
    final values = weights.isEmpty ? <double>[] : retrievalUnit(weights);
    final raw = List<double>.filled(32, 0);
    for (var d = 0; d < 32; d++) {
      for (var i = 0; i < indices.length; i++) {
        raw[d] += values[i] * components[d][indices[i]];
      }
    }
    return RetrievalEncoding._(
      List.unmodifiable(indices),
      List.unmodifiable(values),
      List.unmodifiable(raw),
      retrievalUnit(raw),
    );
  }

  List<RetrievalHit> search(
    String text, {
    String method = 'hybrid',
    int k = 10,
    int depth = 100,
    Set<String>? allowed,
  }) {
    if (!retrievalMethods.contains(method) ||
        k < 1 ||
        k > 5183 ||
        depth < 1 ||
        depth > 5183 ||
        (allowed != null && allowed.any((id) => !byId.containsKey(id)))) {
      throw ArgumentError('Method,cutoff,candidate budget and filter IDs');
    }
    final query = encode(text);
    if (query.outOfVocabulary) return const [];
    final weights = {
      for (var i = 0; i < query.indices.length; i++)
        query.indices[i]: query.values[i],
    };
    final lexical = <RetrievalHit>[], dense = <RetrievalHit>[];
    final queryNonzero = query.unit.any((v) => v != 0);
    for (final doc in documents) {
      if (allowed != null && !allowed.contains(doc.id)) continue;
      var score = 0.0;
      for (var i = 0; i < doc.indices.length; i++) {
        score += doc.values[i] * (weights[doc.indices[i]] ?? 0);
      }
      if (score > 0) lexical.add(RetrievalHit(doc.id, score));
      if (queryNonzero && doc.dense.any((v) => v != 0)) {
        dense.add(RetrievalHit(doc.id, retrievalDot(query.unit, doc.dense)));
      }
    }
    lexical.sort(_compare);
    dense.sort(_compare);
    final result = method == 'tfidf'
        ? lexical
        : method == 'lsa'
        ? dense
        : retrievalFuse([
            lexical.take(depth).toList(),
            dense.take(depth).toList(),
          ]);
    return List.unmodifiable(result.take(k));
  }
}

class RetrievalSample {
  final String id, role, text;
  final Set<String> relevant;
  RetrievalSample.fromJson(Map<String, dynamic> j)
    : id = j['id'],
      role = j['role'],
      text = j['text'],
      relevant = Set.unmodifiable(List<String>.from(j['relevant']));
}

class RetrievalAssets {
  final RetrievalIndex index;
  final List<RetrievalSample> samples;
  final Map<String, dynamic> report;
  RetrievalAssets._(this.index, this.samples, this.report);
  static RetrievalAssets? _cached;
  static Future<RetrievalAssets>? _pending;
  static Future<RetrievalAssets> load() async =>
      _cached ??= await (_pending ??= _load());
  static Future<RetrievalAssets> _load() async {
    final raw = await Future.wait([
      rootBundle.loadString('assets/datasets/scifact/retrieval_index.json'),
      rootBundle.loadString('assets/datasets/scifact/corpus.jsonl'),
      rootBundle.loadString('assets/datasets/scifact/retrieval_lab.json'),
    ]);
    final source = const LineSplitter()
        .convert(raw[1])
        .where((s) => s.isNotEmpty)
        .map(jsonDecode)
        .toList();
    final lab = jsonDecode(raw[2]);
    return RetrievalAssets._(
      RetrievalIndex.fromJson(jsonDecode(raw[0]), source),
      List.unmodifiable(
        (lab['samples'] as List).map((j) => RetrievalSample.fromJson(j)),
      ),
      Map.unmodifiable(lab['report']),
    );
  }
}
