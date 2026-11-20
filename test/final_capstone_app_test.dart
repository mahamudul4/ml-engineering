import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/data/learning_repository.dart';
import 'package:ml_path/main.dart';
import 'package:ml_path/state/learning_controller.dart';
import 'package:ml_path/features/final_capstone/portfolio_labs.dart';
import 'package:ml_path/features/final_capstone/portfolio_model.dart';
import 'package:ml_path/features/lessons/lesson_page.dart';
import 'package:ml_path/features/practice/quiz_page.dart';
import 'package:ml_path/features/practice/practice_page.dart';
import 'package:ml_path/ui/theme.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late LearningController c;
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
  setUp(() async {
    final repo = await LearningRepository.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    c = LearningController(repo);
    await c.load();
    await PortfolioAssets.load();
  });
  tearDown(() async {
    c.dispose();
    await c.repository.close();
  });
  Future<void> settleStorage(WidgetTester tester, bool Function() ready) async {
    for (var i = 0; i < 100 && !ready(); i++) {
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  for (final size in [const Size(390, 844), const Size(1440, 768)]) {
    testWidgets('Chapter 40 responsive overview and dark labs at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() => c.selectChapter('chapter_40'));
      await tester.pumpWidget(LearningApp(controller: c));
      await tester.pumpAndSettle();
      expect(
        find.text('Final Capstone & Portfolio\nBuild. Verify. Defend.'),
        findsOneWidget,
      );
      if (size.width < 1000) {
        expect(find.text('06 · Final Capstone'), findsOneWidget);
      }
      expect(
        find.text('0 of ${c.chapter.lessons.length} completed'),
        findsOneWidget,
      );
      await tester.tap(
        find.text(size.width < 1000 ? 'Lab' : 'Interactive lab').first,
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pump(const Duration(milliseconds: 100));

      await tester.pumpAndSettle();
      expect(find.text('Connect each claim to evidence.'), findsOneWidget);
      await tester.tap(find.byTooltip('Toggle light / dark mode'));
      await settleStorage(tester, () => c.themeMode == ThemeMode.dark);
      await tester.scrollUntilVisible(
        find.text('Explain it. Write it. Review it.'),
        350,
        scrollable: find.byType(Scrollable).last,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
    'Chapter 40 mobile picker opens the first of twenty-five lessons',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(LearningApp(controller: c));
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(find.byKey(const ValueKey('book-chip-systems'))),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('book-chip-systems')));
      for (var i = 0; i < 100 && c.currentBook.id != 'systems'; i++) {
        await tester.runAsync(
          () async => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('06 · Final Capstone, Portfolio & Mock Interviews'),
        160,
        scrollable: find.byType(Scrollable).last,
      );
      await Scrollable.ensureVisible(
        tester.element(
          find.text('06 · Final Capstone, Portfolio & Mock Interviews').last,
        ),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.text('06 · Final Capstone, Portfolio & Mock Interviews').last,
      );
      await settleStorage(tester, () => c.chapter.id == 'chapter_40');
      expect(c.chapter.id, 'chapter_40');
      await tester.ensureVisible(find.text('Start learning'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start learning'));
      await tester.runAsync(() async => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pumpAndSettle();
      expect(find.text('ML Systems & Interviews · Chapter 6 · Lesson 1 of 28'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  Future<void> tapControl(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> panel(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Evidence project,slice andreset recompute denominators', (
    tester,
  ) async {
    await panel(tester, const PortfolioEvidenceLab());
    expect(find.text('n: 313'), findsOneWidget);
    await tapControl(
      tester,
      find.byKey(const ValueKey('evidence-project-classical')),
    );
    await tester.tap(find.text('Deep Learning · White Wine').last);
    await tester.pumpAndSettle();
    expect(find.text('n: 955'), findsOneWidget);
    await tapControl(tester, find.byKey(const Key('evidence-scope-first5')));
    expect(find.text('n: 5'), findsOneWidget);
    await tapControl(tester, find.text('Reset evidence review'));
    expect(find.text('n: 313'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Audit source,license,unsupported production andreset gates', (
    tester,
  ) async {
    await panel(tester, const PortfolioAuditLab());
    expect(find.textContaining('Evidence gate: PASS'), findsOneWidget);
    for (final fault in [
      'source_mismatch',
      'license_missing',
      'production_claim',
    ]) {
      await tapControl(tester, find.byKey(Key('audit-fault-$fault')));
      expect(find.textContaining('Evidence gate: BLOCKED'), findsOneWidget);
    }
    await tapControl(tester, find.text('Reset portfolio audit'));
    expect(find.textContaining('Evidence gate: PASS'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'Mock draft,checks,role/round scope,clear/reload andSQLite reopen',
    (tester) async {
      await panel(tester, MockDefenseLab(controller: c));
      await settleStorage(
        tester,
        () => find.byKey(const Key('mock-save')).evaluate().isNotEmpty,
      );
      await tester.enterText(
        find.byKey(const Key('mock-draft')),
        'My evidence andcounterexample',
      );
      await tapControl(tester, find.byKey(const Key('mock-check-source')));
      await tapControl(tester, find.byKey(const Key('mock-save')));
      await settleStorage(
        tester,
        () => find.text('Draft saved on this device.').evaluate().isNotEmpty,
      );
      final saved = await tester.runAsync(
        () => MockDraftStore(c.repository).load('ml_engineer', 'project'),
      );
      expect(saved!.text, 'My evidence andcounterexample');
      await tapControl(
        tester,
        find.byKey(const Key('mock-role-data_scientist')),
      );
      await settleStorage(
        tester,
        () =>
            !(tester
                    .widget<TextField>(find.byKey(const Key('mock-draft')))
                    .enabled ==
                false),
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('mock-draft')))
            .controller!
            .text,
        isEmpty,
      );
      await tapControl(tester, find.byKey(const Key('mock-round-statistics')));
      await settleStorage(
        tester,
        () =>
            tester
                .widget<TextField>(find.byKey(const Key('mock-draft')))
                .enabled ==
            true,
      );
      await tapControl(tester, find.byKey(const Key('mock-role-ml_engineer')));
      await settleStorage(
        tester,
        () =>
            tester
                .widget<TextField>(find.byKey(const Key('mock-draft')))
                .enabled ==
            true,
      );
      await tapControl(tester, find.byKey(const Key('mock-round-project')));
      await settleStorage(
        tester,
        () => tester
            .widget<TextField>(find.byKey(const Key('mock-draft')))
            .controller!
            .text
            .isNotEmpty,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('mock-draft')))
            .controller!
            .text,
        'My evidence andcounterexample',
      );
      await tapControl(tester, find.text('Clear current edits'));
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('mock-draft')))
            .controller!
            .text,
        isEmpty,
      );
      await tapControl(tester, find.text('Reload saved draft'));
      await settleStorage(
        tester,
        () => tester
            .widget<TextField>(find.byKey(const Key('mock-draft')))
            .controller!
            .text
            .isNotEmpty,
      );
      expect(find.text('Self-reviewed evidence items: 1 / 6'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Chapter 40 all quiz questions show feedback and retry', (
    tester,
  ) async {
    await tester.runAsync(() => c.selectChapter('chapter_40'));
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: QuizPage(controller: c),
      ),
    );
    await tester.pumpAndSettle();
    for (final q in c.chapter.quizzes) {
      final option = find.text(q.options[q.answer]);
      await tester.ensureVisible(option);
      await tester.pumpAndSettle();
      await tester.tap(option);
      await settleStorage(tester, () => c.answers.containsKey(q.id));
      expect(find.text(q.explanation), findsOneWidget);
      final next = find.text(
        q.id == c.chapter.quizzes.last.id ? 'See results' : 'Next question →',
      );
      await tester.ensureVisible(next);
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pumpAndSettle();
    }
    final quizCount = c.chapter.quizzes.length;
    expect(find.text('$quizCount / $quizCount'), findsOneWidget);
    await tester.ensureVisible(find.text('Try again'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Try again'));
    await settleStorage(tester, () => c.answers.isEmpty);
    expect(c.answers, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'Chapter 40 saved coding scratchpad accepts the row-level policy cost numeric check',
    (tester) async {
      await tester.runAsync(() => c.selectChapter('chapter_40'));
      final exercise = c.chapter.exercises.first;
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ExerciseCard(controller: c, exercise: exercise),
            ),
          ),
        ),
      );
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, exercise.solution);
      await tester.enterText(
        find.byType(TextField).last,
        exercise.expected.toString(),
      );
      await tester.ensureVisible(find.text('Check answer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Check answer'));
      await settleStorage(
        tester,
        () => find.text('ফল মিলেছে').evaluate().isNotEmpty,
      );
      expect(find.text('ফল মিলেছে'), findsOneWidget);
      final saved = await tester.runAsync(
        () => c.repository.exercise(exercise.id),
      );
      expect(saved?['solved'], 1);
      expect(saved?['draft'], contains('fp'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('RAG evidence never turns exact quotes into truth accuracy', (
    tester,
  ) async {
    await panel(tester, const PortfolioEvidenceLab());
    await tapControl(
      tester,
      find.byKey(const ValueKey('evidence-project-classical')),
    );
    await tester.tap(find.text('RAG / Generative AI · SciFact').last);
    await tester.pumpAndSettle();
    expect(find.text('n: 6'), findsOneWidget);
    expect(find.text('truth_accuracy: undefined'), findsOneWidget);
    expect(find.text('verified_answers: 0'), findsOneWidget);
    await tapControl(tester, find.text('Reset evidence review'));
    expect(find.text('n: 313'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'all twenty-five final-capstone lessons render full derivations, code and labs',
    (tester) async {
      await tester.runAsync(() => c.selectChapter('chapter_40'));
      for (final lesson in c.chapter.lessons) {
        await tester.pumpWidget(
          MaterialApp(
            theme: appTheme(Brightness.light),
            home: LessonPage(
              key: ValueKey(lesson.id),
              controller: c,
              lesson: lesson,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(lesson.title), findsOneWidget);
        expect(tester.takeException(), isNull, reason: lesson.id);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
}
