import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/data/learning_repository.dart';
import 'package:ml_path/main.dart';
import 'package:ml_path/state/learning_controller.dart';
import 'package:ml_path/features/gen_capstone/gen_capstone_labs.dart';
import 'package:ml_path/features/gen_capstone/gen_capstone_model.dart';
import 'package:ml_path/features/lessons/lesson_page.dart';
import 'package:ml_path/features/practice/quiz_page.dart';
import 'package:ml_path/features/practice/practice_page.dart';
import 'package:ml_path/ui/theme.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
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
    await GenCapstoneAssets.load();
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
    testWidgets('Chapter 29 responsive overview and dark labs at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() => c.selectChapter('chapter_29'));
      await tester.pumpWidget(LearningApp(controller: c));
      await tester.pumpAndSettle();
      expect(
        find.text('LLM/Generative AI Capstone\nRetrieve. Generate. Audit.'),
        findsOneWidget,
      );
      if (size.width < 1000) {
        expect(find.text('10 · LLM/Generative AI Capstone'), findsOneWidget);
      }
      expect(
        find.text('0 of ${c.chapter.lessons.length} completed'),
        findsOneWidget,
      );
      await tester.tap(
        find.text(size.width < 1000 ? 'Lab' : 'Interactive lab').first,
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Retrieve. Generate a hypothesis. Check the source.'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Toggle light / dark mode'));
      await settleStorage(tester, () => c.themeMode == ThemeMode.dark);
      await tester.scrollUntilVisible(
        find.text('Pin the contract. Reject altered evidence.'),
        350,
        scrollable: find.byType(Scrollable).last,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('Chapter 29 mobile picker opens the first of twenty lessons', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(LearningApp(controller: c));
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const ValueKey('book-chip-llm'))),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('book-chip-llm')));
    for (var i = 0; i < 100 && c.currentBook.id != 'llm'; i++) {
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('10 · LLM/Generative AI Capstone'),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    await Scrollable.ensureVisible(
      tester.element(find.text('10 · LLM/Generative AI Capstone').last),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('10 · LLM/Generative AI Capstone').last);
    await settleStorage(tester, () => c.chapter.id == 'chapter_29');
    expect(c.chapter.id, 'chapter_29');
    await tester.ensureVisible(find.text('Start learning'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start learning'));
    await tester.runAsync(() async => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pumpAndSettle();
    expect(find.text('LLMs & GenAI · Chapter 10 · Lesson 1 of 21'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  Future<void> tapControl(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('Workbench empty retrieval and zero budget reset', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: const Scaffold(
          body: SingleChildScrollView(child: EvidenceWorkbench()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Context budget: 1024 bytes'), findsOneWidget);
    await tapControl(tester, find.byKey(const Key('capstone-budget')));
    expect(find.text('Policy: no_context'), findsOneWidget);
    await tapControl(tester, find.text('Reset evidence workbench'));
    expect(find.text('Context budget: 1024 bytes'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('capstone-query')), '');
    await tapControl(tester, find.text('Run offline pipeline'));
    expect(find.text('Policy: no_context'), findsOneWidget);
    await tapControl(tester, find.text('Reset evidence workbench'));
    expect(find.text('Policy: unverified_hypothesis'), findsOneWidget);
    // Unicode grapheme count differs from the retriever's UTF16 bound.
    await tester.enterText(
      find.byKey(const Key('capstone-query')),
      List.filled(2050, '😀').join(),
    );
    await tapControl(tester, find.text('Run offline pipeline'));
    expect(
      find.text('Query exceeds 4096 UTF16 units. Shorten it.'),
      findsOneWidget,
    );
    await tapControl(tester, find.text('Reset evidence workbench'));
    expect(
      find.text('Query exceeds 4096 UTF16 units. Shorten it.'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Selective threshold changes,empty set and reset', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: const Scaffold(
          body: SingleChildScrollView(child: CapstoneScorecard()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Confidence threshold: 0.00'), findsOneWidget);
    await tapControl(tester, find.byType(DropdownButtonFormField<String>));
    await tester.tap(find.text('query_only').last);
    await tester.pumpAndSettle();
    expect(find.text('Correct words: 82'), findsOneWidget);
    await tapControl(tester, find.byKey(const Key('capstone-strict')));
    expect(find.text('Confidence threshold: 0.90'), findsOneWidget);
    await tapControl(tester, find.byKey(const Key('capstone-empty')));
    expect(find.text('Confidence threshold: 1.00'), findsOneWidget);
    expect(find.textContaining('Accepted accuracy: undefined'), findsOneWidget);
    await tapControl(tester, find.text('Reset capstone scorecard'));
    expect(find.text('Confidence threshold: 0.00'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Altered source quotation rejects and resets', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: const Scaffold(
          body: SingleChildScrollView(child: CapstoneReleaseAudit()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Quote integrity: exact'), findsOneWidget);
    await tapControl(tester, find.byKey(const Key('capstone-tamper')));
    expect(find.text('Quote integrity: changed'), findsOneWidget);
    expect(find.text('Runtime gate: citation_mismatch'), findsOneWidget);
    await tapControl(tester, find.text('Reset release audit'));
    expect(find.text('Quote integrity: exact'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Chapter 29 all quiz questions show feedback and retry', (
    tester,
  ) async {
    await tester.runAsync(() => c.selectChapter('chapter_29'));
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
    'Chapter 29 saved coding scratchpad accepts the label accuracy numeric check',
    (tester) async {
      await tester.runAsync(() => c.selectChapter('chapter_29'));
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
        (89 / 188).toString(),
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
      expect(saved?['draft'], contains('correct'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Model card expands and resets', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: const Scaffold(
          body: SingleChildScrollView(child: CapstoneReleaseAudit()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Model card: hidden'), findsOneWidget);
    await tapControl(tester, find.byKey(const Key('capstone-manifest')));
    expect(find.text('Model card: visible'), findsOneWidget);
    await tapControl(tester, find.text('Reset release audit'));
    expect(find.text('Model card: hidden'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'all twenty capstone lessons render full derivations, code and labs',
    (tester) async {
      await tester.runAsync(() => c.selectChapter('chapter_29'));
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
