import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/features/rag/rag_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late RAGAssets a;
  late Map<String, dynamic> lab;
  setUpAll(() async {
    a = await RAGAssets.load();
    lab = jsonDecode(
      await rootBundle.loadString('assets/datasets/scifact_rag/rag_lab.json'),
    );
  });
  test('All30 Python complete pipeline traces match fresh Dart execution', () {
    for (final s in lab['samples']) {
      for (final name in [
        'rerank',
        'document_order',
        'small_budget',
        'empty_budget',
        'shallow',
      ]) {
        final r = a.system.run(
              s['text'],
              rerank: name != 'document_order',
              budget: name == 'small_budget'
                  ? 256
                  : name == 'empty_budget'
                  ? 0
                  : 1024,
              count: name == 'shallow' ? 5 : 10,
            ),
            g = s['cases'][name];
        expect(
          r.retrieved.map((h) => h.id).toList(),
          (g['retrieved'] as List).map((h) => h[0]).toList(),
        );
        expect(r.candidates.length, g['candidates'].length);
        for (var i = 0; i < r.candidates.length; i++) {
          final c = r.candidates[i], e = g['candidates'][i];
          expect(c.citation, '[${e['doc_id']}:${e['start']}-${e['end']}]');
          expect(c.text, e['text']);
          expect(c.score, closeTo(e['score'], 1e-12));
        }
        expect(r.pack.context, g['context']);
        expect(r.pack.answer, g['answer']);
        expect(r.pack.usedBytes, g['used_bytes']);
        expect(r.pack.abstained, g['abstained']);
        expect(
          r.pack.selected.map((c) => c.citation).toList(),
          (g['selected'] as List)
              .map((e) => '[${e['doc_id']}:${e['start']}-${e['end']}]')
              .toList(),
        );
        expect(
          r.pack.skipped.map((s) => s.reason).toList(),
          (g['skipped'] as List).map((s) => s['reason']).toList(),
        );
        expect(r.handoff, g['handoff']);
      }
    }
  });
  test(
    'Original sentence windows cover every source index with exact spans',
    () {
      expect(a.system.source.length, 5183);
      var sentences = 0;
      for (final doc in a.system.source.values) {
        sentences += doc.sentences.length;
        for (final size in [2, 3]) {
          final chunks = ragChunks(doc, size: size, overlap: 1);
          expect(
            {
              for (final c in chunks)
                for (var i = c.start; i < c.end; i++) i,
            },
            {for (var i = 0; i < doc.sentences.length; i++) i},
          );
          expect(
            chunks.every(
              (c) => ragAuditQuote(c, a.system.source)['exact_quote']!,
            ),
            isTrue,
          );
        }
      }
      expect(sentences, 45952);
    },
  );
  test(
    'Exact UTF8 packing boundaries,whole span skipping and parent uniqueness',
    () {
      final run = a.system.run(a.samples.first.text),
          c = run.pack.selected.first;
      expect(ragPack([c], a.system.source, budget: c.bytes).usedBytes, c.bytes);
      expect(
        ragPack([c], a.system.source, budget: c.bytes - 1).abstained,
        isTrue,
      );
      expect(
        ragPack(run.candidates, a.system.source, budget: 0).context,
        isEmpty,
      );
      expect(
        run.pack.selected.map((c) => c.docId).toSet().length,
        run.pack.selected.length,
      );
      expect(utf8.encode(run.pack.context).length, run.pack.usedBytes);
    },
  );
  test('Resolvable citations differ from exact quote and missing annotations are null', () {
    final c = a.system.run(a.samples.first.text).pack.selected.first;
    expect(
      ragAuditQuote(
        RAGChunk(c.docId, c.start, c.end, 'edited'),
        a.system.source,
      ),
      {'resolvable': true, 'exact_quote': false},
    );
    expect(ragAuditQuote(RAGChunk('missing', 0, 1, c.text), a.system.source), {
      'resolvable': false,
      'exact_quote': false,
    });
    expect(
      ragAuditQuote(
        RAGChunk(c.docId, -1, 1, c.text),
        a.system.source,
      )['resolvable'],
      isFalse,
    );
    expect(ragEvidenceMetrics(a.system.run('বাংলা').pack, {}, {}), isNull);
  });
  test(
    'Alternative rationale union and full-set hit have different denominators',
    () {
      final source = {
        '7': RAGDocument('7', 'Example', ['one', 'two', 'three']),
      };
      final p = ragPack([const RAGChunk('7', 0, 1, 'one', score: .5)], source);
      expect(
        ragEvidenceMetrics(
          p,
          {
            '7': [
              RAGRationale('SUPPORT', [0]),
              RAGRationale('SUPPORT', [1, 2]),
            ],
          },
          {'7'},
        ),
        {
          'sentence_union_recall': 1 / 3,
          'complete_rationale_hit': 1,
          'candidate_rationale_available': 1,
        },
      );
    },
  );
  test(
    'Invalid source spans,budgets,thresholds and duplicate candidates reject',
    () {
      final c = a.system.run(a.samples.first.text).pack.selected.first;
      for (final budget in [-1, 16385]) {
        expect(
          () => ragPack([c], a.system.source, budget: budget),
          throwsArgumentError,
        );
      }
      expect(() => ragPack([c, c], a.system.source), throwsArgumentError);
      expect(
        () => ragPack([
          RAGChunk(c.docId, c.start, c.end, c.text, score: double.nan),
        ], a.system.source),
        throwsArgumentError,
      );
      expect(
        () => ragPack([c], a.system.source, minimum: double.infinity),
        throwsArgumentError,
      );
      expect(
        () => ragChunks(a.system.source.values.first, size: 2, overlap: 2),
        throwsArgumentError,
      );
      expect(() => a.system.run('cell', count: 0), throwsArgumentError);
      expect(() => a.system.run('cell', budget: -1), throwsArgumentError);
    },
  );
  test(
    'OOV and zero context abstain without fabricated source or generation',
    () {
      for (final text in ['', 'বাংলা শেখা', 'zzzzzzzzzzzzzzzzzzzzzz']) {
        final r = a.system.run(text);
        expect(r.retrieved, isEmpty);
        expect(r.pack.abstained, isTrue);
        expect(r.pack.usedBytes, 0);
      }
      expect(
        a.system.run(a.samples.first.text, budget: 0).pack.abstained,
        isTrue,
      );
    },
  );
  test('Original role and immutable evidence contracts retain honest limitations', () {
    expect(a.report['cross_role_exact_claim_text_overlap'], 2);
    expect(a.report['evaluation']['train']['annotated_queries'], 505);
    expect(a.report['evaluation']['test']['annotated_queries'], 188);
    expect(
      a.report['evaluation']['test']['modes']['rerank']['complete_rationale_hit'],
      lessThan(.5),
    );
    expect(() => a.system.source.clear(), throwsUnsupportedError);
    expect(
      () => a.system.source.values.first.sentences.add('edited'),
      throwsUnsupportedError,
    );
    expect(() => a.samples.first.evidence.clear(), throwsUnsupportedError);
    expect(
      () => a.samples.first.evidence.values.first.first.sentences.add(9),
      throwsUnsupportedError,
    );
  });
}
