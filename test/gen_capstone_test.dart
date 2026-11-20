import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/features/gen_capstone/gen_capstone_model.dart';
import 'package:ml_path/features/rag/rag_model.dart';

Matcher nearList(List<double> expected, [double tolerance = 1e-10]) =>
    pairwiseCompare<double, double>(
      expected,
      (a, b) => (a - b).abs() < tolerance,
      'near CPU reference',
    );
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GenCapstoneAssets a;
  setUpAll(() async {
    a = await GenCapstoneAssets.load();
  });
  test('All six actual retrieval contexts and 256D features match Python', () {
    for (final s in a.samples) {
      for (final entry in (s['cases'] as Map).entries) {
        final budget = entry.key == 'empty_budget' ? 0 : 1024;
        final run = a.rag.system.run(s['text'], budget: budget);
        final r = entry.value;
        expect(run.pack.context, r['pack']['context']);
        expect(run.pack.usedBytes, r['pack']['used_bytes']);
        final text = entry.key == 'query_only'
            ? ''
            : run.pack.selected.map((c) => c.text).join('\n');
        expect(
          capstoneFeatures(s['text'], text),
          nearList(GenCapstoneAssets.vector(r['features'])),
        );
      }
    }
  });
  test('All eighteen complete GRU decoder traces match saved CPU hidden and probabilities', () {
    for (final s in a.samples) {
      for (final r in (s['cases'] as Map).values) {
        final g = a.generate(GenCapstoneAssets.vector(r['features'])),
            ref = r['generation'];
        expect(g.text, ref['text']);
        expect(g.ended, ref['ended']);
        expect(g.formatValid, ref['format_valid']);
        expect(g.ids, ref['ids']);
        expect(
          g.initialHidden,
          nearList(GenCapstoneAssets.vector(ref['initial_hidden'])),
        );
        expect(g.confidence, closeTo(ref['first_token_confidence'], 1e-10));
        for (var i = 0; i < g.trace.length; i++) {
          final step = g.trace[i], gold = ref['trace'][i];
          expect(step.previous, gold['previous']);
          expect(step.chosen, gold['chosen']);
          expect(
            step.hidden,
            nearList(GenCapstoneAssets.vector(gold['hidden'])),
          );
          expect(
            step.probabilities,
            nearList(GenCapstoneAssets.vector(gold['probabilities'])),
          );
          expect(step.probabilities.take(2), [0, 0]);
        }
      }
    }
  });
  test(
    'All 564 frozen diagnostic rows and thresholds reproduce full scorecards',
    () {
      for (final mode in ['retrieved', 'query_only', 'rotated_context']) {
        final v = a.data['variants'][mode];
        for (final pair in [(0.0, 'summary'), (.9, 'strict')]) {
          final r = capstoneScore(v['rows'], threshold: pair.$1);
          for (final key in r.keys) {
            final ref = v[pair.$2][key], actual = r[key];
            if (ref is num && actual is num) {
              expect(actual, closeTo(ref, 1e-12));
            } else {
              expect(actual, ref);
            }
          }
        }
      }
    },
  );
  test('Paired diagnostic IDs, majority failure and original rationale bookkeeping are explicit', () {
    final variants = a.data['variants'];
    final rows = variants['retrieved']['rows'] as List;
    for (final mode in ['query_only', 'rotated_context']) {
      expect(
        (variants[mode]['rows'] as List).map((dynamic r) => r['id']),
        rows.map((dynamic r) => r['id']),
      );
    }
    expect(rows.length, 188);
    expect(capstoneScore(rows)['correct'], 89);
    expect(capstoneScore(rows)['joint_hits'], 33);
    expect(capstoneScore(rows)['complete_rationale_hits'], 68);
    expect(a.report['majority_accuracy'], closeTo(124 / 188, 1e-12));
  });
  test(
    'Deterministic hash blocks, empty queries and ignored non-ASCII text',
    () {
      expect(capstoneFeatures('', ''), List.filled(256, 0));
      expect(capstoneFeatures('বাংলা', ''), List.filled(256, 0));
      expect(capstoneBucket('evidence'), inInclusiveRange(0, 127));
      expect(
        capstoneFeatures('evidence claim', ''),
        capstoneFeatures('CLAIM evidence', ''),
      );
    },
  );
  test('Runtime gate has no gold input and preserves explicit rejection precedence', () {
    String decide(bool context, bool exact, bool valid, double c, double t) =>
        capstoneDecision(
          hasContext: context,
          quotesExact: exact,
          formatValid: valid,
          confidence: c,
          threshold: t,
        );
    expect(decide(false, false, false, .99, 0), 'no_context');
    expect(decide(true, false, true, .99, 0), 'citation_mismatch');
    expect(decide(true, true, false, .99, 0), 'invalid_format');
    expect(decide(true, true, true, .8, .9), 'low_confidence');
    expect(decide(true, true, true, .9, .9), 'unverified_hypothesis');
  });
  test('Threshold1 empty set accuracy/risk stays undefined', () {
    final r = capstoneScore(
      a.data['variants']['retrieved']['rows'],
      threshold: 1,
    );
    expect(r['accepted'], 0);
    expect(r['coverage'], 0);
    expect(r['accepted_accuracy'], isNull);
    expect(r['accepted_risk'], isNull);
  });
  test(
    'Actual source quotation mutation resolves ID but fails exact provenance',
    () {
      final j = a.samples[3]['cases']['retrieved']['pack']['selected'][0];
      final q = RAGChunk(j['doc_id'], j['start'], j['end'], j['text']);
      expect(ragAuditQuote(q, a.rag.system.source)['exact_quote'], isTrue);
      final changed = RAGChunk(q.docId, q.start, q.end, '${q.text} [edited]');
      expect(ragAuditQuote(changed, a.rag.system.source), {
        'resolvable': true,
        'exact_quote': false,
      });
    },
  );
  test('Invalid finite shapes, tokens, thresholds and malformed vocabulary are rejected', () async {
    for (final f in [
      () => a.generate([0]),
      () => a.initial(List.filled(256, double.nan)),
      () => a.step(14, List.filled(16, 0)),
      () => capstoneScore([]),
      () => capstoneDecision(
        hasContext: true,
        quotesExact: true,
        formatValid: true,
        confidence: .5,
        threshold: double.nan,
      ),
    ]) {
      expect(f, throwsArgumentError);
    }
    final j = jsonDecode(
      await rootBundle.loadString(
        'assets/datasets/scifact_rag/capstone_lab.json',
      ),
    ) as Map<String, dynamic>;
    j['vocabulary'][2] = 'bad';
    expect(() => GenCapstoneAssets.fromJson(j, a.rag), throwsFormatException);
  });
  test('Frozen nested source evidence and generated traces are immutable', () {
    expect(() => a.samples.clear(), throwsUnsupportedError);
    expect(
      () => a.data['weights']['condition.weight'][0][0] = 0,
      throwsUnsupportedError,
    );
    final g = a.generate(
      GenCapstoneAssets.vector(a.samples[0]['cases']['retrieved']['features']),
    );
    expect(() => g.trace.clear(), throwsUnsupportedError);
    expect(() => g.trace[0].hidden.clear(), throwsUnsupportedError);
  });
}
