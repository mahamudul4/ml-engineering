import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/features/retrieval/retrieval_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late RetrievalAssets a;
  late Map<String, dynamic> lab;
  setUpAll(() async {
    a = await RetrievalAssets.load();
    lab = jsonDecode(
      await rootBundle.loadString('assets/datasets/scifact/retrieval_lab.json'),
    );
  });
  test(
    'Geometry,ASCII token contract,zero convention and finite arithmetic',
    () {
      expect(retrievalCosine([3, 4], [4, 3]), closeTo(.96, 1e-14));
      expect(retrievalCosine([6, 8], [4, 3]), closeTo(.96, 1e-14));
      expect(retrievalDot([6, 8], [4, 3]), 48);
      expect(retrievalCosine([0, 0], [4, 3]), 0);
      expect(retrievalUnit([0, 0]), [0, 0]);
      expect(retrievalTokens('Cell-β বাংলা PrP 42'), ['cell', 'prp', '42']);
      expect(() => retrievalDot([1], [1, 2]), throwsArgumentError);
      expect(() => retrievalUnit([]), throwsArgumentError);
      expect(() => retrievalUnit([double.nan]), throwsArgumentError);
      expect(() => retrievalDot([1e308], [1e308]), throwsArgumentError);
    },
  );
  test('All six original query sparse weights and every projected coordinate match Python', () {
    for (final s in lab['samples']) {
      final q = a.index.encode(s['text']);
      final expected = {
        for (var i = 0; i < s['sparse']['indices'].length; i++)
          s['sparse']['indices'][i]: s['sparse']['values'][i],
      };
      expect(q.indices.toSet(), expected.keys.toSet());
      for (var i = 0; i < q.indices.length; i++) {
        expect(q.values[i], closeTo(expected[q.indices[i]], 1e-12));
      }
      for (var i = 0; i < 32; i++) {
        expect(q.raw[i], closeTo(s['raw'][i], 1e-12));
        expect(q.unit[i], closeTo(s['unit'][i], 1e-12));
      }
      expect(retrievalDot(q.unit, q.unit), closeTo(1, 1e-12));
    }
  });
  test('All18 complete top10 rankings and six shallow candidate fusions match Python', () {
    for (final s in lab['samples']) {
      for (final method in retrievalMethods) {
        final hits = a.index.search(s['text'], method: method);
        final expected = s['rankings'][method] as List;
        expect(
          hits.map((h) => h.id).toList(),
          expected.map((h) => h[0]).toList(),
          reason: '${s['id']} $method',
        );
        for (var i = 0; i < hits.length; i++) {
          expect(hits[i].score, closeTo(expected[i][1], 1e-11));
        }
        expect(
          a.index.search(s['text'], method: method, k: 5).map((h) => h.id),
          hits.take(5).map((h) => h.id),
        );
      }
      final shallow = a.index.search(s['text'], depth: 5);
      expect(
        shallow.map((h) => h.id).toList(),
        (s['depth5_hybrid'] as List).map((h) => h[0]).toList(),
      );
    }
  });
  test('Metadata eligibility is enforced before ranking in all branches and fusion', () {
    final allowed = {
      for (final d in a.index.documents)
        if (retrievalTokens(d.title).contains('cell')) d.id,
    };
    expect(allowed.length, allOf(greaterThan(0), lessThan(5183)));
    final query = a.samples[2].text;
    for (final method in retrievalMethods) {
      final hits = a.index.search(query, method: method, allowed: allowed);
      expect(hits.every((h) => allowed.contains(h.id)), isTrue);
      expect(hits.map((h) => h.id).toSet().length, hits.length);
      expect(a.index.search(query, method: method, allowed: {}), isEmpty);
    }
    final subset = a.index.documents.take(3).map((d) => d.id).toSet();
    final restricted = a.index.search(
      query,
      method: 'lsa',
      k: 10,
      allowed: subset,
    );
    expect(restricted.length, 3);
    expect(restricted.map((h) => h.id).toSet(), subset);
  });
  test(
    'Empty,Unicode-only and unseen-term queries yield no fabricated matches',
    () {
      for (final query in [
        '',
        'বাংলা শেখা',
        '---',
        'zzzzzzzzzzzzzzzzzzzzzzzz',
      ]) {
        expect(a.index.encode(query).outOfVocabulary, isTrue);
        for (final method in retrievalMethods) {
          expect(a.index.search(query, method: method), isEmpty);
        }
      }
      final q = a.index.encode('cell cell cell');
      expect(q.indices.length, 1);
      expect(q.values, [1]);
    },
  );
  test(
    'RRF uses one-based ranks,absent0,numeric ties and validates candidate IDs',
    () {
      final fused = retrievalFuse([
        [const RetrievalHit('7', .9), const RetrievalHit('10', .8)],
        [const RetrievalHit('7', .2), const RetrievalHit('2', .1)],
      ]);
      expect(fused.first.id, '7');
      expect(fused.first.score, closeTo(2 / 61, 1e-15));
      expect(fused.skip(1).map((h) => h.id).toList(), ['2', '10']);
      expect(fused[1].score, closeTo(1 / 62, 1e-15));
      expect(retrievalFuse([[], []]), isEmpty);
      expect(
        () => retrievalFuse([
          [const RetrievalHit('1', 0), const RetrievalHit('1', 0)],
        ]),
        throwsArgumentError,
      );
      expect(() => retrievalFuse([], constant: 0), throwsArgumentError);
      expect(
        () => retrievalFuse([
          [const RetrievalHit('x', 0)],
        ]),
        throwsArgumentError,
      );
      expect(
        () => retrievalFuse([
          [const RetrievalHit('1', double.nan)],
        ]),
        throwsArgumentError,
      );
    },
  );
  test('Binary relevance metrics have correct ideal denominator and first-hit cutoff', () {
    final m = retrievalMetrics(['1', '2', '3', '4'], {'2', '4'}, 4);
    expect(m['recall'], 1);
    expect(m['mrr'], .5);
    expect(
      m['ndcg'],
      closeTo(
        (1 / (math.log(3) / math.ln2) + 1 / (math.log(5) / math.ln2)) /
            (1 + 1 / (math.log(3) / math.ln2)),
        1e-14,
      ),
    );
    expect(retrievalMetrics(['1', '2'], {'2', '4'}, 2)['recall'], .5);
    expect(retrievalMetrics(['1', '2'], {'2', '4'}, 1), {
      'recall': 0,
      'mrr': 0,
      'ndcg': 0,
    });
    expect(retrievalMetrics([], {'2'}, 10), {'recall': 0, 'mrr': 0, 'ndcg': 0});
    expect(() => retrievalMetrics(['1', '1'], {'1'}, 2), throwsArgumentError);
    expect(() => retrievalMetrics([], {}, 10), throwsArgumentError);
    expect(() => retrievalMetrics([], {'1'}, 0), throwsArgumentError);
  });
  test(
    'Source role counts,weak dense result and immutable artifacts are explicit',
    () {
      expect(a.index.documents.length, 5183);
      expect(a.index.vocabulary.length, 4096);
      expect(a.samples.where((s) => s.role == 'train').length, 3);
      expect(a.samples.where((s) => s.role == 'test').length, 3);
      expect(a.report['evaluation']['train']['queries'], 809);
      expect(a.report['evaluation']['test']['queries'], 300);
      final scores = a.report['evaluation']['test']['methods'];
      expect(
        scores['tfidf']['10']['recall'],
        greaterThan(scores['hybrid']['10']['recall']),
      );
      expect(
        scores['hybrid']['10']['recall'],
        greaterThan(scores['lsa']['10']['recall']),
      );
      expect(() => a.index.vocabulary[0] = 'changed', throwsUnsupportedError);
      expect(() => a.index.idf[0] = 0, throwsUnsupportedError);
      expect(() => a.index.components[0][0] = 0, throwsUnsupportedError);
      expect(() => a.index.documents[0].values[0] = 0, throwsUnsupportedError);
      expect(() => a.index.documents[0].indices[0] = 0, throwsUnsupportedError);
      expect(() => a.index.documents[0].dense[0] = 0, throwsUnsupportedError);
      expect(() => a.samples[0].relevant.add('1'), throwsUnsupportedError);
    },
  );
  test(
    'Invalid query contracts,methods,cutoffs,budgets and filter IDs reject',
    () {
      final query = a.samples.first.text;
      expect(
        () => a.index.encode(List.filled(4097, 'a').join()),
        throwsArgumentError,
      );
      for (final k in [0, -1, 5184]) {
        expect(() => a.index.search(query, k: k), throwsArgumentError);
        expect(() => a.index.search(query, depth: k), throwsArgumentError);
      }
      expect(
        () => a.index.search(query, method: 'neural'),
        throwsArgumentError,
      );
      expect(
        () => a.index.search(query, allowed: {'missing'}),
        throwsArgumentError,
      );
    },
  );
  test('Corrupt schema,vocabulary,weights,source alignment and unit vectors reject', () async {
    final raw = jsonDecode(
      await rootBundle.loadString(
        'assets/datasets/scifact/retrieval_index.json',
      ),
    ) as Map<String, dynamic>;
    final source = const LineSplitter()
        .convert(
          await rootBundle.loadString('assets/datasets/scifact/corpus.jsonl'),
        )
        .map(jsonDecode)
        .toList();
    expect(
      () => RetrievalIndex.fromJson({...raw, 'schema_version': 2}, source),
      throwsFormatException,
    );
    expect(
      () => RetrievalIndex.fromJson({
        ...raw,
        'vocabulary': List.filled(4096, 'a'),
      }, source),
      throwsFormatException,
    );
    expect(
      () => RetrievalIndex.fromJson({
        ...raw,
        'idf': List.filled(4096, double.nan),
      }, source),
      throwsFormatException,
    );
    expect(
      () => RetrievalIndex.fromJson({...raw, 'components': []}, source),
      throwsFormatException,
    );
    expect(
      () => RetrievalIndex.fromJson(raw, source.skip(1).toList()),
      throwsFormatException,
    );
    final docs = raw['documents'] as List;
    final first = docs.first;
    expect(
      () => RetrievalIndex.fromJson({
        ...raw,
        'documents': [
          {...first, 'dense': List.filled(32, 1.0)},
          ...docs.skip(1),
        ],
      }, source),
      throwsFormatException,
    );
    expect(
      () => RetrievalIndex.fromJson({
        ...raw,
        'documents': [
          {...first, 'id': 'missing'},
          ...docs.skip(1),
        ],
      }, source),
      throwsFormatException,
    );
    expect(
      () => RetrievalIndex.fromJson({
        ...raw,
        'documents': [
          {
            ...first,
            'indices': [-1],
          },
          ...docs.skip(1),
        ],
      }, source),
      throwsFormatException,
    );
  });
}
