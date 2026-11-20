import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/data/learning_repository.dart';
import 'package:ml_path/main.dart';
import 'package:ml_path/state/learning_controller.dart';
import 'package:ml_path/features/statistics/statistics_labs.dart';
import 'package:ml_path/features/statistics/statistics_model.dart';
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
    testWidgets('Chapter 8 responsive overview and dark labs at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() => c.selectChapter('chapter_08'));
      await tester.pumpWidget(LearningApp(controller: c));
      await tester.pumpAndSettle();
      expect(find.text('Probability, Statistics\n& Inference'), findsOneWidget);
      expect(
        find.text('0 of ${c.chapter.lessons.length} completed'),
        findsOneWidget,
      );
      await tester.tap(
        find.text(size.width < 1000 ? 'Lab' : 'Interactive lab').first,
      );
      await tester.pumpAndSettle();
      expect(find.text('P(event | flag): 15.38%'), findsOneWidget);
      await tester.tap(find.byTooltip('Toggle light / dark mode'));
      await settleStorage(tester, () => c.themeMode == ThemeMode.dark);
      await tester.scrollUntilVisible(
        find.text('A confidence level belongs to a procedure.'),
        350,
        scrollable: find.byType(Scrollable).last,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('Chapter 8 mobile picker opens the first of sixteen lessons', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(LearningApp(controller: c));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('04 · Probability, Statistics & Inference').last,
    );
    await settleStorage(tester, () => c.chapter.id == 'chapter_08');
    expect(c.chapter.id, 'chapter_08');
    await tester.ensureVisible(find.text('Start learning'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start learning'));
    await tester.runAsync(() async => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pumpAndSettle();
    expect(find.text('ML Foundations · Chapter 4 · Lesson 1 of 17'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'Bayes controls handle perfect specificity and undefined conditioning',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: const Scaffold(body: SingleChildScrollView(child: BayesLab())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('P(event | flag): 15.38%'), findsOneWidget);
      for (final pair in [
        ('stats-perfect', 'P(event | flag): 100.00%'),
        ('stats-no-flags', 'P(event | flag): undefined (no flags)'),
      ]) {
        await tester.ensureVisible(find.byKey(Key(pair.$1)));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(Key(pair.$1)));
        await tester.pumpAndSettle();
        expect(find.text(pair.$2), findsOneWidget);
      }
      await tester.ensureVisible(find.text('Reset Bayes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset Bayes'));
      await tester.pumpAndSettle();
      expect(find.text('P(event | flag): 15.38%'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Coverage controls expose Wald boundary failure and reset', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: const Scaffold(body: SingleChildScrollView(child: CoverageLab())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Wilson coverage: 95.63%'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('stats-successes')));
    await tester.pumpAndSettle();
    final slider = tester.getRect(find.byKey(const Key('stats-successes')));
    await tester.tapAt(Offset(slider.left + 1, slider.center.dy));
    await tester.pumpAndSettle();
    expect(find.text('Selected interval: [0.000, 0.161]'), findsOneWidget);
    await tester.ensureVisible(
      find.byType(DropdownButtonFormField<IntervalMethod>),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<IntervalMethod>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wald normal (clipped)').last);
    await tester.pumpAndSettle();
    expect(find.text('Selected interval: [0.000, 0.000]'), findsOneWidget);
    expect(find.text('Selected interval misses p'), findsOneWidget);
    await tester.ensureVisible(
      find.byType(DropdownButtonFormField<ConfidenceLevel>),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<ConfidenceLevel>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('99%').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Reset coverage'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset coverage'));
    await tester.pumpAndSettle();
    expect(find.text('Selected interval covers p'), findsOneWidget);
    expect(find.text('Selected interval: [0.081, 0.416]'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Chapter 8 all twenty quiz questions show feedback and retry', (
    tester,
  ) async {
    await tester.runAsync(() => c.selectChapter('chapter_08'));
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
    expect(find.text('20 / 20'), findsOneWidget);
    await tester.ensureVisible(find.text('Try again'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Try again'));
    await settleStorage(tester, () => c.answers.isEmpty);
    expect(c.answers, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'Chapter 8 saved coding scratchpad accepts the Bayes numeric check',
    (tester) async {
      await tester.runAsync(() => c.selectChapter('chapter_08'));
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
      await tester.enterText(find.byType(TextField).last, (2 / 13).toString());
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
      expect(saved?['draft'], contains('posterior'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'all sixteen statistics lessons render full derivations, code and labs',
    (tester) async {
      await tester.runAsync(() => c.selectChapter('chapter_08'));
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
