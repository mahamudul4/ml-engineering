import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/data/learning_repository.dart';
import 'package:ml_path/main.dart';
import 'package:ml_path/state/learning_controller.dart';
import 'package:ml_path/features/recommendation/recommendation_labs.dart';
import 'package:ml_path/features/recommendation/recommendation_model.dart';
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
    await RecommendationAssets.load();
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
    testWidgets('Chapter 30 responsive overview and dark labs at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() => c.selectChapter('chapter_30'));
      await tester.pumpWidget(LearningApp(controller: c));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Recommendation Foundations\nPreferences. Neighbors. Rankings.',
        ),
        findsOneWidget,
      );
      if (size.width < 1000) {
        expect(find.text('01 · Recommendation Foundations'), findsOneWidget);
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
        find.text('Observe the feedback. Build a baseline.'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Toggle light / dark mode'));
      await settleStorage(tester, () => c.themeMode == ThemeMode.dark);
      await tester.scrollUntilVisible(
        find.text('Freeze the timeline. Audit the denominator.'),
        350,
        scrollable: find.byType(Scrollable).last,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('Chapter 30 mobile picker opens the first of twenty lessons', (
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
      find.text('01 · Recommendation Foundations').last,
      160,
      scrollable: find.byType(Scrollable).last,
    );
    await Scrollable.ensureVisible(
      tester.element(find.text('01 · Recommendation Foundations').last),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('01 · Recommendation Foundations').last);
    await settleStorage(tester, () => c.chapter.id == 'chapter_30');
    expect(c.chapter.id, 'chapter_30');
    await tester.ensureVisible(find.text('Start learning'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start learning'));
    await tester.runAsync(() async => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pumpAndSettle();
    expect(find.text('Recommender Systems · Chapter 1 · Lesson 1 of 21'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  Future<void> tapControl(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('Feedback threshold, Bayesian prior and reset', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: const Scaffold(
          body: SingleChildScrollView(child: FeedbackBaselineLab()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Preference threshold: 4 stars'), findsOneWidget);
    await tapControl(tester, find.byKey(const Key('rec-threshold')));
    await tapControl(tester, find.byKey(const Key('rec-bayesian')));
    expect(
      find.textContaining('Threshold does not change this mean'),
      findsOneWidget,
    );
    await tapControl(tester, find.byKey(const Key('rec-strength')));
    await tapControl(tester, find.text('Reset feedback baseline'));
    expect(find.text('Prior strength: 20 ratings'), findsOneWidget);
    expect(find.text('Preference threshold: 4 stars'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Workbench methods, seen policy, neighbor limit and reset', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: const Scaffold(
          body: SingleChildScrollView(child: RecommendationWorkbench()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Neighbor limit: 20'), findsOneWidget);
    await tapControl(tester, find.byKey(const Key('rec-neighbors-5')));
    expect(find.text('Neighbor limit: 5'), findsOneWidget);
    await tapControl(tester, find.byKey(const Key('rec-seen')));
    expect(find.textContaining('Inspection mode:'), findsOneWidget);
    await tapControl(tester, find.text('Reset recommendation workbench'));
    expect(find.text('Neighbor limit: 20'), findsOneWidget);
    expect(find.textContaining('Inspection mode:'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Cold source user falls back, content selection and reset', (
    tester,
  ) async {
    final a = await tester.runAsync(RecommendationAssets.load);
    final cold = (a!.data['samples'] as List).last['user'];
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: const Scaffold(
          body: SingleChildScrollView(child: RecommendationWorkbench()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tapControl(tester, find.byType(DropdownButtonFormField<int>));
    await tester.tap(find.text('User $cold · cold history').last);
    await tester.pumpAndSettle();
    expect(find.text('Fallback: popularity (no fit history)'), findsOneWidget);
    await tapControl(tester, find.byType(DropdownButtonFormField<String>));
    await tester.tap(find.text('content').last);
    await tester.pumpAndSettle();
    expect(find.text('Fallback: popularity (no fit history)'), findsOneWidget);
    await tapControl(tester, find.text('Reset recommendation workbench'));
    expect(find.text('Neighbor limit: 20'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Chapter 30 all quiz questions show feedback and retry', (
    tester,
  ) async {
    await tester.runAsync(() => c.selectChapter('chapter_30'));
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
    'Chapter 30 saved coding scratchpad accepts the popularity numeric check',
    (tester) async {
      await tester.runAsync(() => c.selectChapter('chapter_30'));
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
      await tester.enterText(find.byType(TextField).last, 218.toString());
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
      expect(saved?['draft'], contains('positive'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Evaluation cohort, K, protocol and reset', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: const Scaffold(
          body: SingleChildScrollView(child: RecommendationEvaluationLab()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Cohort: warm users / eligible positives'),
      findsOneWidget,
    );
    await tapControl(tester, find.byKey(const Key('rec-cohort')));
    expect(
      find.text('Cohort: all future-positive users / all positives'),
      findsOneWidget,
    );
    await tapControl(tester, find.byKey(const Key('rec-k-5')));
    expect(find.textContaining('Recall@5'), findsNWidgets(4));
    await tapControl(tester, find.byKey(const Key('rec-protocol')));
    expect(find.text('Protocol audit: visible'), findsOneWidget);
    await tapControl(tester, find.text('Reset recommendation evaluation'));
    expect(
      find.text('Cohort: warm users / eligible positives'),
      findsOneWidget,
    );
    expect(find.text('Protocol audit: hidden'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'all twenty recommendation lessons render full derivations, code and labs',
    (tester) async {
      await tester.runAsync(() => c.selectChapter('chapter_30'));
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
