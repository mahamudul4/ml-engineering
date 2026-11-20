import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/features/final_capstone/portfolio_model.dart';
import 'package:ml_path/data/learning_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late PortfolioAssets a;
  setUpAll(() async {
    a = await PortfolioAssets.load();
  });
  void same(dynamic actual, dynamic expected) {
    if (expected is Map) {
      expect((actual as Map).keys.toSet(), expected.keys.toSet());
      for (final k in expected.keys) {
        same(actual[k], expected[k]);
      }
    } else if (expected is List) {
      expect((actual as List).length, expected.length);
      for (var j = 0; j < expected.length; j++) {
        same(actual[j], expected[j]);
      }
    } else if (expected is num) {
      expect(
        actual,
        closeTo(expected, math.max(1e-11, expected.abs() * 1e-11)),
      );
    } else {
      expect(actual, expected);
    }
  }

  test('Four projects,nine immutable dependencies andzero new-training/holdout/hiring claims', () {
    final r = a.data['report'];
    expect(r['projects'], 4);
    expect((r['dependencies'] as Map).length, 9);
    expect(r['reserved_outcomes_newly_scored'], 0);
    expect(r['new_training_runs'], 0);
    expect(r['production_measured'], false);
    expect(r['hiring_outcomes_observed'], false);
    expect((a.data['records'] as Map).keys.toSet(), portfolioProjects.toSet());
  });
  test('All12 project/slice summaries match independent Python references', () {
    for (final entry in (a.data['summaries'] as Map).entries) {
      final p = (entry.key as String).split(':');
      same(a.summary(p[0], scope: p[1]), entry.value);
    }
  });
  test('Classical/deep frozen decision rows exactly match original source artifact arrays', () async {
    final red = jsonDecode(
          await rootBundle.loadString(
            'assets/datasets/wine_quality/capstone_lab.json',
          ),
        ),
        white = jsonDecode(
          await rootBundle.loadString(
            'assets/datasets/wine_quality/deep_capstone_lab.json',
          ),
        );
    same(a.data['records']['classical'], red['decision_predictions']);
    same(a.data['records']['deep'], white['decision_rows']);
    expect(a.summary('classical')['n'], 313);
    expect(a.summary('deep')['n'], 955);
  });
  test('Actual classifiers preserve thresholdedconfusion,cost denominator andundefinedclass slices', () {
    final red = a.summary('classical'), white = a.summary('deep');
    expect([red['tp'], red['fp'], red['tn'], red['fn']], [148, 67, 83, 15]);
    expect(red['mean_cost'], 127 / 313);
    expect(
      [white['tp'], white['fp'], white['tn'], white['fn']],
      [609, 270, 65, 11],
    );
    expect(white['mean_cost'], 314 / 955);
    expect(a.summary('classical', scope: 'first5')['recall'], isNull);
    expect(a.summary('classical', scope: 'last5')['accuracy'], 1);
  });
  test('Recommender macro metrics recompute with independently accumulated per-user gains', () {
    final rows = a.data['records']['recommendation'] as List;
    var n = 0, hits = 0;
    double precision = 0, recall = 0, ndcg = 0;
    for (final row in rows) {
      final gold = (row['eligible'] as List).toSet();
      if (gold.isEmpty) continue;
      n++;
      final ranking = (row['rankings']['rrf_cf'] as List).take(10).toList();
      final userHits = ranking.where(gold.contains).length;
      hits += userHits;
      precision += userHits / 10;
      recall += userHits / gold.length;
      double gain = 0, ideal = 0;
      for (var j = 0; j < ranking.length; j++) {
        if (gold.contains(ranking[j])) gain += math.ln2 / math.log(j + 2);
      }
      for (var j = 0; j < math.min(10, gold.length); j++) {
        ideal += math.ln2 / math.log(j + 2);
      }
      ndcg += gain / ideal;
    }
    final r = a.summary('recommendation');
    expect(r['n'], 74);
    expect(r['eligible_users'], n);
    expect(r['excluded_users'], 74 - n);
    expect(r['hits'], hits);
    expect(r['precision'], closeTo(precision / n, 1e-12));
    expect(r['recall'], closeTo(recall / n, 1e-12));
    expect(r['ndcg'], closeTo(ndcg / n, 1e-12));
  });
  test('Six RAG sample provenance/format/emission flags never imply verifiedtruthaccuracy', () {
    final r = a.summary('rag');
    expect(r['n'], 6);
    expect(r['format_valid'], 6);
    expect(r['exact_packs'], 6);
    expect(r['emitted'], 6);
    expect(r['verified_answers'], 0);
    expect(r['truth_accuracy'], isNull);
    final rows = a.data['records']['rag'] as List;
    expect(rows.map((r) => r['role']).toSet().length, greaterThan(1));
    expect(rows.every((r) => r['reason'] == 'unverified_hypothesis'), true);
  });
  test('All16 metadatafault audits blockexactfieldmismatch andpreserve original contracts', () {
    for (final project in portfolioProjects) {
      final card = Map<String, dynamic>.from(a.data['cards'][project]);
      final original = jsonEncode(card);
      for (final fault in portfolioFaults) {
        same(
          portfolioAudit(card, fault: fault),
          a.data['audits']['$project:$fault'],
        );
      }
      expect(jsonEncode(card), original);
      expect(portfolioAudit(card)['passed'], true);
      expect(portfolioAudit(card, fault: 'production_claim')['issues'], [
        'production_measured',
      ]);
    }
  });
  test('Empty/invalid evidence helpers andduplicate ranking guard definedboundaries', () {
    for (final project in portfolioProjects) {
      final r = portfolioSummary(project, []);
      expect(r['n'], 0);
      if (project == 'classical' || project == 'deep') {
        expect(r['accuracy'], isNull);
      }
      if (project == 'recommendation') expect(r['ndcg'], isNull);
    }
    expect(() => portfolioSummary('unknown', []), throwsArgumentError);
    expect(
      () => portfolioSummary('deep', [], scope: 'random'),
      throwsArgumentError,
    );
    expect(() => portfolioAudit({}, fault: 'unknown'), throwsArgumentError);
    expect(
      () => portfolioSummary('deep', [
        {'positive': 1, 'probability': double.nan},
      ]),
      throwsArgumentError,
    );
    expect(
      () => portfolioSummary('recommendation', [
        {
          'eligible': [1],
          'rankings': {
            'rrf_cf': [1, 1],
          },
        },
      ]),
      throwsArgumentError,
    );
  });
  test('Draft schema,8000characterboundary,immutablechecks androle/roundkeyvalidation', () {
    final checked = {'source'};
    final d = MockDraft('evidence', checked);
    checked.add('limits');
    expect(d.checked, {'source'});
    expect(() => d.checked.add('failure'), throwsUnsupportedError);
    same(MockDraft.fromJson(d.toJson()).toJson(), d.toJson());
    expect(MockDraft('x' * 8000, {}).text.length, 8000);
    expect(() => MockDraft('x' * 8001, {}), throwsFormatException);
    expect(() => MockDraft('', {'score'}), throwsFormatException);
    for (final json in [
      {'version': 2, 'text': '', 'checked': []},
      {'version': 1, 'text': 1, 'checked': []},
      {
        'version': 1,
        'text': '',
        'checked': [1],
      },
    ]) {
      expect(() => MockDraft.fromJson(json), throwsFormatException);
    }
    expect(() => MockDraftStore.key('unknown', 'project'), throwsArgumentError);
    expect(
      () => MockDraftStore.key('ml_engineer', 'unknown'),
      throwsArgumentError,
    );
  });
  test('All16 role-round drafts persist independently after SQLiteclose/reopen withouttouchinglearnerstate', () async {
    final dir = await Directory.systemTemp.createTemp('ml_portfolio40_');
    var repo = await LearningRepository.open(
      factory: databaseFactoryFfi,
      path: '${dir.path}/learner.db',
    );
    await repo.updateLesson(
      'ml_basics',
      note: 'Preserved note',
      completed: true,
    );
    await repo.setSetting('selected_chapter', 'chapter_39');
    var store = MockDraftStore(repo);
    for (final role in mockRoles) {
      for (final round in mockRounds) {
        expect((await store.load(role, round)).text, isEmpty);
        await store.save(
          role,
          round,
          MockDraft('$role:$round evidence', {'source', 'limits'}),
        );
      }
    }
    await repo.close();
    repo = await LearningRepository.open(
      factory: databaseFactoryFfi,
      path: '${dir.path}/learner.db',
    );
    store = MockDraftStore(repo);
    for (final role in mockRoles) {
      for (final round in mockRounds) {
        final d = await store.load(role, round);
        expect(d.text, '$role:$round evidence');
        expect(d.checked, {'source', 'limits'});
      }
    }
    expect(await repo.setting('selected_chapter'), 'chapter_39');
    expect(
      (await repo.progress()).firstWhere(
        (r) => r['lesson_id'] == 'ml_basics',
      )['note'],
      'Preserved note',
    );
    await store.save('ml_engineer', 'project', MockDraft.empty());
    expect((await store.load('ml_engineer', 'systems')).text, isNotEmpty);
    await repo.close();
    await dir.delete(recursive: true);
  });
  test('Corruptsaved draft errors preserve storedbytes andall16 promptcardkeys/reviewfields', () async {
    final repo = await LearningRepository.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    final key = MockDraftStore.key('ml_engineer', 'project');
    await repo.setSetting(key, '{"version":999}');
    await expectLater(
      MockDraftStore(repo).load('ml_engineer', 'project'),
      throwsFormatException,
    );
    expect(await repo.setting(key), '{"version":999}');
    await repo.close();
    expect((a.data['mock_cards'] as Map).length, 16);
    for (final role in mockRoles) {
      for (final round in mockRounds) {
        final card = a.data['mock_cards']['$role:$round'];
        expect((card['review'] as Map).keys.toSet(), mockChecks.toSet());
        expect((card['prompt'] as String).isNotEmpty, true);
      }
    }
  });
  test(
    'CV AP selection andfixeddecisioncost havehonestlydifferent winnerclaims',
    () async {
      final d = jsonDecode(
        await rootBundle.loadString(
          'assets/datasets/wine_quality/deep_capstone_lab.json',
        ),
      );
      expect(d['selection']['winner'], 'mlp');
      expect(d['selection']['test_rows_in_labs'], 0);
      expect(
        a.summary('deep')['mean_cost'],
        greaterThan(d['decision_metrics']['logistic']['mean_cost']),
      );
      expect(
        (a.data['cards']['deep']['limits'] as String),
        contains('not fresh confirmation'),
      );
    },
  );
}
