import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/data/learning_repository.dart';
import 'package:ml_path/main.dart';
import 'package:ml_path/state/learning_controller.dart';
import 'package:ml_path/features/factorization/factor_labs.dart';
import 'package:ml_path/features/factorization/factor_model.dart';
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
    await FactorAssets.load();
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
    testWidgets('Chapter 31 responsive overview and dark labs at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() => c.selectChapter('chapter_31'));
      await tester.pumpWidget(LearningApp(controller: c));
      await tester.pumpAndSettle();
      expect(
        find.text('Matrix Factorization\nFactors. Objectives. Interactions.'),
        findsOneWidget,
      );
      if (size.width < 1000) {
        expect(find.text('02 · Matrix Factorization'), findsOneWidget);
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
        find.text('Learn factors. Inspect the interactions.'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Toggle light / dark mode'));
      await settleStorage(tester, () => c.themeMode == ThemeMode.dark);
      await tester.scrollUntilVisible(
        find.text('Optimize the pair. Audit the ranking.'),
        350,
        scrollable: find.byType(Scrollable).last,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('Chapter 31 mobile picker opens the first of twenty lessons', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(LearningApp(controller: c));
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const ValueKey('book-chip-recsys'))),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('book-chip-recsys')));
    for (var i = 0; i < 100 && c.currentBook.id != 'recsys'; i++) {
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('02 · Matrix Factorization & Feature Interactions'),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    await Scrollable.ensureVisible(
      tester.element(
        find.text('02 · Matrix Factorization & Feature Interactions').last,
      ),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('02 · Matrix Factorization & Feature Interactions').last,
    );
    await settleStorage(tester, () => c.chapter.id == 'chapter_31');
    expect(c.chapter.id, 'chapter_31');
    await tester.ensureVisible(find.text('Start learning'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start learning'));
    await tester.runAsync(() async => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pumpAndSettle();
    expect(find.text('Recommender Systems · Chapter 2 · Lesson 1 of 21'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  Future<void> tapControl(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('Full factor method switching, genre input and reset', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: const Scaffold(
          body: SingleChildScrollView(child: FactorWorkbench()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Scoring: explicit_als · rank 8'), findsOneWidget);
    await tapControl(tester, find.byType(DropdownButtonFormField<String>));
    await tester.tap(find.text('fm').last);
    await tester.pumpAndSettle();
    await tapControl(tester, find.byKey(const Key('factor-genres')));
    expect(find.textContaining('Top-item FM:'), findsOneWidget);
    await tapControl(tester, find.text('Reset factor workbench'));
    expect(find.text('Scoring: explicit_als · rank 8'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Actual cold user uses explicit fallback and picker resets', (
    tester,
  ) async {
    final a = await tester.runAsync(FactorAssets.load);
    final cold = (a!.data['samples'] as List).last['user'];
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: const Scaffold(
          body: SingleChildScrollView(child: FactorWorkbench()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tapControl(tester, find.byType(DropdownButtonFormField<int>));
    await tester.tap(find.text('User $cold · cold').last);
    await tester.pumpAndSettle();
    expect(
      find.text('Fallback: popularity (no usable factors)'),
      findsOneWidget,
    );
    await tapControl(tester, find.text('Reset factor workbench'));
    expect(find.text('Scoring: explicit_als · rank 8'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Real ALS conditional solve, lambda controls, matrix and reset', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: const Scaffold(
          body: SingleChildScrollView(child: ALSUpdateLab()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Regularization: 10.0'), findsOneWidget);
    await tapControl(tester, find.byKey(const Key('als-reg-0.1')));
    expect(find.text('Regularization: 0.1'), findsOneWidget);
    await tapControl(tester, find.byKey(const Key('als-matrix')));
    expect(find.text('Normal equation: visible'), findsOneWidget);
    await tapControl(tester, find.text('Reset ALS update'));
    expect(find.text('Regularization: 10.0'), findsOneWidget);
    expect(find.text('Normal equation: hidden'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Chapter 31 all quiz questions show feedback and retry', (
    tester,
  ) async {
    await tester.runAsync(() => c.selectChapter('chapter_31'));
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
    'Chapter 31 saved coding scratchpad accepts the factor dot numeric check',
    (tester) async {
      await tester.runAsync(() => c.selectChapter('chapter_31'));
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
      expect(saved?['draft'], contains('contributions'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Pair loss, cohort, K and reset', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: const Scaffold(
          body: SingleChildScrollView(child: RankingLossLab()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Margin offset: 0.0'), findsOneWidget);
    await tapControl(tester, find.byKey(const Key('bpr-offset')));
    await tapControl(tester, find.byKey(const Key('factor-cohort')));
    expect(
      find.text('Cohort: all future-positive users / all positives'),
      findsOneWidget,
    );
    await tapControl(tester, find.byKey(const Key('factor-k-5')));
    expect(find.textContaining('Recall@5'), findsNWidgets(6));
    await tapControl(tester, find.text('Reset ranking loss audit'));
    expect(find.text('Margin offset: 0.0'), findsOneWidget);
    expect(
      find.text('Cohort: warm users / eligible positives'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'all twenty factorization lessons render full derivations, code and labs',
    (tester) async {
      await tester.runAsync(() => c.selectChapter('chapter_31'));
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
