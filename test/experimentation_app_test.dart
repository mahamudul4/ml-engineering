import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/data/learning_repository.dart';
import 'package:ml_path/main.dart';
import 'package:ml_path/state/learning_controller.dart';
import 'package:ml_path/features/experimentation/experiment_labs.dart';
import 'package:ml_path/features/experimentation/experiment_model.dart';
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
    await ExperimentAssets.load();
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
    testWidgets('Chapter 37 responsive overview and dark labs at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() => c.selectChapter('chapter_37'));
      await tester.pumpWidget(LearningApp(controller: c));
      await tester.pumpAndSettle();
      expect(
        find.text('Experiments & Causality\nAssign. Estimate. Question.'),
        findsOneWidget,
      );
      if (size.width < 1000) {
        expect(find.text('03 · Experiments & Causality'), findsOneWidget);
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
        find.text('Estimate the contrast. Keep uncertainty visible.'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Toggle light / dark mode'));
      await settleStorage(tester, () => c.themeMode == ThemeMode.dark);
      await tester.scrollUntilVisible(
        find.text('Change the comparison. Audit the assumptions.'),
        350,
        scrollable: find.byType(Scrollable).last,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('Chapter 37 mobile picker opens the first of twenty lessons', (
    tester,
  ) async {
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
      find.text('03 · Experimentation & Causal Reasoning'),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    await Scrollable.ensureVisible(
      tester.element(find.text('03 · Experimentation & Causal Reasoning').last),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('03 · Experimentation & Causal Reasoning').last);
    await settleStorage(tester, () => c.chapter.id == 'chapter_37');
    expect(c.chapter.id, 'chapter_37');
    await tester.ensureVisible(find.text('Start learning'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start learning'));
    await tester.runAsync(() async => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pumpAndSettle();
    expect(find.text('ML Systems & Interviews · Chapter 3 · Lesson 1 of 21'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
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
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Trial outcome and confidence recompute actual contrasts and reset',
    (tester) async {
      await panel(tester, const TrialInferenceLab());
      expect(
        find.textContaining('Observed contrast: 1794.342'),
        findsOneWidget,
      );
      await tapControl(tester, find.byKey(const Key('trial-outcome-positive')));
      await tapControl(tester, find.byKey(const Key('trial-confidence-0.99')));
      expect(
        find.textContaining('Observed contrast: 11.060 percentage points'),
        findsOneWidget,
      );
      expect(find.textContaining('Welch 99% CI:'), findsOneWidget);
      await tapControl(tester, find.text('Reset trial inference'));
      expect(
        find.textContaining('Observed contrast: 1794.342'),
        findsOneWidget,
      );
      expect(find.text('Confidence level: 95%'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Conditional randomization prefixes update actual tails and histogram then reset',
    (tester) async {
      await panel(tester, const TrialInferenceLab());
      await tapControl(tester, find.byKey(const Key('trial-draws-100')));
      expect(find.text('Randomization draws: 100'), findsOneWidget);
      expect(find.textContaining('/ 100\nPlus-one p'), findsOneWidget);
      await tapControl(tester, find.byKey(const Key('trial-draws-500')));
      expect(find.text('Randomization draws: 500'), findsOneWidget);
      await tapControl(tester, find.text('Reset trial inference'));
      expect(find.text('Randomization draws: 1000'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Power allocation alpha cluster assumptions and logging failure reset',
    (tester) async {
      await panel(tester, const ExperimentDesignLab());
      for (final key in [
        'design-mde-1000',
        'design-allocation-0.7',
        'design-alpha-0.01',
        'design-power-0.9',
        'design-cluster-5',
        'design-icc-0.05',
        'design-logging-loss',
      ]) {
        await tapControl(tester, find.byKey(Key(key)));
      }
      expect(
        find.text('Minimum detectable effect: 1000 source units'),
        findsOneWidget,
      );
      expect(find.textContaining('Design effect 1.200'), findsOneWidget);
      expect(
        find.textContaining('Logging rehearsal: LOSS INJECTED'),
        findsOneWidget,
      );
      expect(find.textContaining('dropped 77'), findsOneWidget);
      await tapControl(tester, find.text('Reset experiment design'));
      expect(
        find.text('Minimum detectable effect: 2000 source units'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Logging rehearsal: COMPLETE'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Chapter 37 all quiz questions show feedback and retry', (
    tester,
  ) async {
    await tester.runAsync(() => c.selectChapter('chapter_37'));
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
    'Chapter 37 saved coding scratchpad accepts the actual randomized mean contrast numeric check',
    (tester) async {
      await tester.runAsync(() => c.selectChapter('chapter_37'));
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
      expect(saved?['draft'], contains('treated'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Comparison source,derived outcome and descriptive standardization reset',
    (tester) async {
      await panel(tester, const ObservationalAuditLab());
      expect(find.textContaining('Comparison: psid'), findsOneWidget);
      await tapControl(tester, find.byKey(const Key('observational-adjust')));
      expect(
        find.textContaining('Shown stratified descriptive gap -5413.951'),
        findsOneWidget,
      );
      await tapControl(
        tester,
        find.byKey(const Key('observational-comparison-experimental')),
      );
      expect(find.textContaining('controls 260'), findsOneWidget);
      await tapControl(
        tester,
        find.byKey(const Key('observational-outcome-positive')),
      );
      expect(find.textContaining('Units: percentage points'), findsOneWidget);
      await tapControl(tester, find.text('Reset observational audit'));
      expect(find.textContaining('Comparison: psid'), findsOneWidget);
      expect(find.textContaining('Shown raw descriptive gap'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'all twenty experimentation lessons render full derivations, code and labs',
    (tester) async {
      await tester.runAsync(() => c.selectChapter('chapter_37'));
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
