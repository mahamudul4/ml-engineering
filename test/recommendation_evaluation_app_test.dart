import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/data/learning_repository.dart';
import 'package:ml_path/main.dart';
import 'package:ml_path/state/learning_controller.dart';
import 'package:ml_path/features/recommendation_evaluation/evaluation_labs.dart';
import 'package:ml_path/features/recommendation_evaluation/evaluation_model.dart';
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
    await RecommendationEvaluationAssets.load();
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
    testWidgets('Chapter 33 responsive overview and dark labs at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() => c.selectChapter('chapter_33'));
      await tester.pumpWidget(LearningApp(controller: c));
      await tester.pumpAndSettle();
      expect(
        find.text('Recommendation Evaluation\nMeasure. Compare. Question.'),
        findsOneWidget,
      );
      if (size.width < 1000) {
        expect(find.text('04 · Recommendation Evaluation'), findsOneWidget);
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
        find.text('Compare the same users. Keep the uncertainty.'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Toggle light / dark mode'));
      await settleStorage(tester, () => c.themeMode == ThemeMode.dark);
      await tester.scrollUntilVisible(
        find.text('Declare the logging policy. Plan the experiment.'),
        350,
        scrollable: find.byType(Scrollable).last,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('Chapter 33 mobile picker opens the first of twenty lessons', (
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
      find.text('04 · Recommendation Evaluation & Feedback Loops'),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    await Scrollable.ensureVisible(
      tester.element(
        find.text('04 · Recommendation Evaluation & Feedback Loops').last,
      ),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('04 · Recommendation Evaluation & Feedback Loops').last,
    );
    await settleStorage(tester, () => c.chapter.id == 'chapter_33');
    expect(c.chapter.id, 'chapter_33');
    await tester.ensureVisible(find.text('Start learning'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start learning'));
    await tester.runAsync(() async => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pumpAndSettle();
    expect(find.text('Recommender Systems · Chapter 4 · Lesson 1 of 21'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  Future<void> tapControl(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('Paired confidence, temporal window and scope reset', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: const Scaffold(
          body: SingleChildScrollView(child: PairedEvaluationLab()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Confidence: 95%'), findsOneWidget);
    await tapControl(tester, find.byKey(const Key('eval-confidence-0.99')));
    expect(find.text('Confidence: 99%'), findsOneWidget);
    await tapControl(tester, find.byKey(const ValueKey('eval-window-full')));
    await tester.tap(find.text('late').last);
    await tester.pumpAndSettle();
    expect(find.text('Scorecard: late window / warm cohort'), findsOneWidget);
    await tapControl(tester, find.byKey(const ValueKey('eval-scope-warm')));
    await tester.tap(find.text('cold').last);
    await tester.pumpAndSettle();
    expect(find.text('Scorecard: late window / cold cohort'), findsOneWidget);
    await tapControl(tester, find.text('Reset paired evaluation'));
    expect(find.text('Confidence: 95%'), findsOneWidget);
    expect(find.text('Scorecard: full window / warm cohort'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('MMR relevance weight changes actual source trace and resets', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: const Scaffold(
          body: SingleChildScrollView(child: DiversityRerankingLab()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('MMR relevance weight: 1.00'), findsOneWidget);
    await tapControl(tester, find.byKey(const Key('mmr-weight-0.5')));
    expect(find.text('MMR relevance weight: 0.50'), findsOneWidget);
    await tapControl(tester, find.text('Reset diversity reranking'));
    expect(find.text('MMR relevance weight: 1.00'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'Cold MMR source case is explicitly popularity-scored and resets',
    (tester) async {
      final a = await tester.runAsync(RecommendationEvaluationAssets.load);
      final cold = (a!.data['samples'] as List).last['user'];
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: DiversityRerankingLab()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tapControl(tester, find.byType(DropdownButtonFormField<int>));
      await tester.tap(find.text('User $cold · cold popularity scores').last);
      await tester.pumpAndSettle();
      expect(find.text('User $cold · cold popularity scores'), findsOneWidget);
      await tapControl(tester, find.text('Reset diversity reranking'));
      expect(find.text('MMR relevance weight: 1.00'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Chapter 33 all quiz questions show feedback and retry', (
    tester,
  ) async {
    await tester.runAsync(() => c.selectChapter('chapter_33'));
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
    'Chapter 33 saved coding scratchpad accepts the paired difference numeric check',
    (tester) async {
      await tester.runAsync(() => c.selectChapter('chapter_33'));
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
      expect(saved?['draft'], contains('differences'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Declared IPS clipping and experiment MDE controls reset', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: const Scaffold(
          body: SingleChildScrollView(child: ExposureExperimentLab()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('IPS 1.5625'), findsOneWidget);
    await tapControl(tester, find.byKey(const Key('exposure-clip')));
    expect(find.textContaining('IPS 0.8125'), findsOneWidget);
    await tapControl(tester, find.byKey(const Key('experiment-mde-0.005')));
    expect(find.text('Absolute MDE: 0.5 percentage points'), findsOneWidget);
    await tapControl(tester, find.text('Reset exposure experiment'));
    expect(find.textContaining('IPS 1.5625'), findsOneWidget);
    expect(find.text('Absolute MDE: 1.0 percentage points'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'all twenty evaluation lessons render full derivations, code and labs',
    (tester) async {
      await tester.runAsync(() => c.selectChapter('chapter_33'));
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
