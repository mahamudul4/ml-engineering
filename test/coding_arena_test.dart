import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/data/learning_repository.dart';
import 'package:ml_path/features/coding/coding_arena_page.dart';
import 'package:ml_path/features/coding/coding_problem_page.dart';
import 'package:ml_path/models/coding_problem.dart';
import 'package:ml_path/state/learning_controller.dart';
import 'package:ml_path/ui/theme.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

CodingProblem _sampleProblem() => const CodingProblem(
  id: 'dm_sample_dt_split',
  number: 1,
  title: 'Decision Tree: Find Best Gini Split',
  category: 'classical_ml',
  categoryLabel: 'Classical ML',
  difficulty: 'Medium',
  chapterRef: 'chapter_09',
  tags: ['Decision Tree', 'Gini Impurity', 'CART'],
  summary:
      'একটি পূর্ণাঙ্গ Decision Tree ক্লাসের ভেতর সেরা Feature ও Threshold বেছে নেওয়ার ফাংশনটি বুঝুন ও ইমপ্লিমেন্ট করুন।',
  problemStatement:
      'নিচের DecisionTreeClassifier কোডবেসে `gini_impurity` এবং `predict` ইতিমধ্যেই দেওয়া আছে। আপনার কাজ হলো `find_best_split(X, y)` ফাংশনটির লজিক তৈরি করা।',
  mathFormula:
      r'\Delta G = G(S) - \frac{|S_L|}{|S|}G(S_L) - \frac{|S_R|}{|S|}G(S_R)',
  targetFunction: 'find_best_split(X, y)',
  codebaseTemplate:
      'class DecisionTree:\n    def find_best_split(self, X, y):\n        # TODO: Implement best Gini split\n        raise NotImplementedError\n',
  examples: [
    CodingExample(
      input: 'X = [[1.0], [2.0], [3.0], [4.0]], y = [0, 0, 1, 1]',
      output: '(0, 2.5, 0.5)',
      explanation: 'Threshold 2.5 দুটি ১০০% Pure child তৈরি করে।',
    ),
  ],
  thinkQuestions: [
    ThinkQuestion(
      question:
          'Candidate threshold হিসেবে sorted unique মানগুলোর midpoint কেন নেওয়া হয়?',
      options: [
        'র‍্যান্ডম শব্দ কমানোর জন্য',
        'দুই পাশাপাশি মানের মাঝখানে সর্বোচ্চ Margin ও স্থিতিশীল Split পাওয়ার জন্য',
        'মেমোরি অর্ধেক করার জন্য',
        'Gradient শূন্য করার জন্য',
      ],
      answer: 1,
      explanation:
          'পাশাপাশি দুটি unique মানের midpoint ঠিক মাঝখান দিয়ে ভাগ করে, ফলে সামান্য noise-এও সিদ্ধান্ত স্থিতিশীল থাকে।',
    ),
  ],
  hints: [
    'Hint 1: প্রতিটি feature column sort করে unique মানগুলোর midpoint নিন।',
    'Hint 2: খালি child তৈরি হলে সেই split বাদ দিন।',
  ],
  solutionCode:
      'def find_best_split(X, y):\n    return (0, 2.5, 0.5)\nassert find_best_split([[1],[2],[3],[4]], [0,0,1,1])[1] == 2.5\n',
  walkthrough:
      'প্রথমে parent node-এর Gini Impurity বের করে প্রতিটি feature-এর candidate midpoint পরীক্ষা করা হয়েছে।',
  complexity: CodingComplexity(time: 'O(d * n log n)', space: 'O(n)'),
  edgeCases: [
    'Pure node হলে কোনো split না করে None ফেরত দিন।',
    'সব feature মান সমান হলে valid midpoint থাকে না।',
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUpAll(() async {
    for (final family in [
      'Manrope',
      'NotoSansBengali',
      'NotoSansMath',
      'NotoSans',
    ]) {
      await (FontLoader(
        family,
      )..addFont(rootBundle.load('assets/fonts/$family.ttf'))).load();
    }
  });

  late LearningController c;

  setUp(() async {
    final repo = await LearningRepository.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    c = LearningController(repo);
    await c.load();
  });

  tearDown(() async {
    await c.repository.close();
    c.dispose();
  });

  testWidgets(
    'Two-Fragment CodingProblemPage separates Problem & Think from gated Solution Fragment',
    (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sample = _sampleProblem();
      c.codingProblems = [sample];

      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: CodingProblemPage(controller: c, problem: sample),
        ),
      );
      await tester.pumpAndSettle();

      // Fragment 1: Problem & Think shows codebase with # TODO and Think Question
      expect(find.text('Decision Tree: Find Best Gini Split'), findsOneWidget);
      expect(find.byKey(const ValueKey('think-q-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('solution-gate-panel')), findsNothing);

      // Answer Think-First question and verify explanation appears
      final opt = find.byKey(const ValueKey('think-q-0-opt-1'));
      await tester.ensureVisible(opt);
      await tester.pumpAndSettle();
      await tester.tap(opt);
      await tester.pumpAndSettle();
      expect(find.text('একদম সঠিক চিন্তা!'), findsOneWidget);

      // Save personal pseudocode note
      final noteField = find.byKey(const ValueKey('coding-note-field'));
      await tester.ensureVisible(noteField);
      await tester.pumpAndSettle();
      await tester.enterText(noteField, 'sort unique values -> midpoints');
      final saveBtn = find.byKey(const ValueKey('coding-note-save'));
      await tester.ensureVisible(saveBtn);
      await tester.pumpAndSettle();
      await tester.tap(saveBtn);
      for (var i = 0; i < 50 && c.codingNote(sample.id).isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(c.codingNote(sample.id), 'sort unique values -> midpoints');

      // Switch to separate Solution Fragment — Think-First Gate protects against spoilers!
      await tester.tap(find.byKey(const ValueKey('tab-solution-fragment')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('solution-gate-panel')), findsOneWidget);
      expect(find.text('VERIFIED PYTHON SOLUTION'), findsNothing);

      // Explicitly reveal the verified solution
      await tester.tap(find.byKey(const ValueKey('reveal-solution-btn')));
      await tester.pumpAndSettle();
      expect(find.text('VERIFIED PYTHON SOLUTION'), findsOneWidget);
      expect(find.text('LINE-BY-LINE WALKTHROUGH'), findsOneWidget);

      // Mark as solved
      final markSolved = find.byKey(const ValueKey('mark-coding-solved'));
      await tester.ensureVisible(markSolved);
      await tester.pumpAndSettle();
      await tester.tap(markSolved);
      for (var i = 0; i < 50 && !c.isCodingSolved(sample.id); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(c.isCodingSolved(sample.id), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'Coding Arena progress, stars and notes survive JSON backup and restore',
    () async {
      await c.toggleCodingSolved('dm_dt_best_split');
      await c.toggleCodingStar('dm_dt_best_split');
      await c.saveCodingNote('dm_dt_best_split', 'Gini gain invariant');

      final exported = await c.exportBackup();
      final temp = await Directory.systemTemp.createTemp('ml_coding_backup_');
      addTearDown(() => temp.delete(recursive: true));
      final freshRepo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/fresh.db',
      );
      final fresh = LearningController(freshRepo);
      addTearDown(freshRepo.close);
      addTearDown(fresh.dispose);
      await fresh.load();

      expect(fresh.isCodingSolved('dm_dt_best_split'), isFalse);
      await fresh.importBackup(exported);
      expect(fresh.isCodingSolved('dm_dt_best_split'), isTrue);
      expect(fresh.isCodingStarred('dm_dt_best_split'), isTrue);
      expect(fresh.codingNote('dm_dt_best_split'), 'Gini gain invariant');
    },
  );

  testWidgets(
    'CodingArenaPage filters, searches and renders without narrow-screen overflow',
    (tester) async {
      final problems = c.codingProblems.isNotEmpty
          ? c.codingProblems
          : [_sampleProblem()];
      if (c.codingProblems.isEmpty) {
        c.codingProblems = problems;
      }

      for (final width in [320.0, 390.0]) {
        for (final scale in [1.0, 1.6]) {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          await tester.pumpWidget(
            MaterialApp(
              theme: appTheme(scale == 1.6 ? Brightness.dark : Brightness.light),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: CodingArenaPage(controller: c),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'w=$width s=$scale');
          await tester.pumpWidget(const SizedBox());
        }
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );

  test(
    'full 120-problem Coding Arena catalog is complete, unique and valid when wired',
    () async {
      if (c.codingProblems.isEmpty) return;
      expect(c.codingProblems.length, 120);
      expect(c.codingProblems.map((p) => p.id).toSet().length, 120);
      expect(
        c.codingProblems.map((p) => p.number).toList(),
        List.generate(120, (i) => i + 1),
      );
      final chapterIds = c.chapters.map((ch) => ch.id).toSet();
      for (final p in c.codingProblems) {
        expect(chapterIds, contains(p.chapterRef), reason: p.id);
        expect(p.codebaseTemplate, contains('# TODO'), reason: p.id);
        expect(p.thinkQuestions.length, greaterThanOrEqualTo(2), reason: p.id);
        expect(p.hints.length, greaterThanOrEqualTo(2), reason: p.id);
        expect(p.examples.length, greaterThanOrEqualTo(2), reason: p.id);
        expect(p.edgeCases.length, greaterThanOrEqualTo(2), reason: p.id);
      }
    },
  );
}

