import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/data/learning_repository.dart';
import 'package:ml_path/main.dart';
import 'package:ml_path/state/learning_controller.dart';
import 'package:ml_path/features/deep_recommendation/deep_recommendation_labs.dart';
import 'package:ml_path/features/deep_recommendation/deep_recommendation_model.dart';
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
    await DeepRecommendationAssets.load();
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
    testWidgets('Chapter 32 responsive overview and dark labs at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() => c.selectChapter('chapter_32'));
      await tester.pumpWidget(LearningApp(controller: c));
      await tester.pumpAndSettle();
      expect(
        find.text('Deep Recommendation\nRetrieve. Rank. Inspect.'),
        findsOneWidget,
      );
      if (size.width < 1000) {
        expect(find.text('03 · Deep Recommendation'), findsOneWidget);
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
        find.text('Retrieve candidates. Rank the shortlist.'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Toggle light / dark mode'));
      await settleStorage(tester, () => c.themeMode == ThemeMode.dark);
      await tester.scrollUntilVisible(
        find.text('Trace the features. Audit the funnel.'),
        350,
        scrollable: find.byType(Scrollable).last,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
    'Chapter 32 mobile picker opens the first of twenty-one lessons',
    (tester) async {
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
        find.text('03 · Deep Recommendation & Ranking'),
        160,
        scrollable: find.byType(Scrollable).last,
      );
      await Scrollable.ensureVisible(
        tester.element(find.text('03 · Deep Recommendation & Ranking').last),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('03 · Deep Recommendation & Ranking').last);
      await settleStorage(tester, () => c.chapter.id == 'chapter_32');
      expect(c.chapter.id, 'chapter_32');
      await tester.ensureVisible(find.text('Start learning'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start learning'));
      await tester.runAsync(() async => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pumpAndSettle();
      expect(find.text('Recommender Systems · Chapter 3 · Lesson 1 of 23'), findsOneWidget);
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

  testWidgets('Candidate budget, hybrid/ranker controls and reset', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: const Scaffold(
          body: SingleChildScrollView(child: DeepRetrievalLab()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Neural budget: 50'), findsOneWidget);
    await tapControl(tester, find.byKey(const Key('deep-budget-100')));
    expect(find.text('Neural budget: 100'), findsOneWidget);
    await tapControl(tester, find.byKey(const Key('deep-hybrid')));
    await tapControl(tester, find.byKey(const Key('deep-rerank')));
    await tapControl(tester, find.text('Reset deep retrieval'));
    expect(find.text('Neural budget: 50'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Real cold user bypasses neural ranker and picker resets', (
    tester,
  ) async {
    final a = await tester.runAsync(DeepRecommendationAssets.load);
    final cold = (a!.data['samples'] as List).last['user'];
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: const Scaffold(
          body: SingleChildScrollView(child: DeepRetrievalLab()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tapControl(tester, find.byType(DropdownButtonFormField<int>));
    await tester.tap(find.text('User $cold · cold').last);
    await tester.pumpAndSettle();
    expect(
      find.text('Fallback: popularity; neural ranker bypassed'),
      findsOneWidget,
    );
    await tapControl(tester, find.text('Reset deep retrieval'));
    expect(
      find.text('Pipeline: normalized towers → candidate union → MLP'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Actual contrastive batch temperature and anchor reset', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: const Scaffold(
          body: SingleChildScrollView(child: ContrastiveBatchLab()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Temperature: 0.2'), findsOneWidget);
    await tapControl(tester, find.byKey(const Key('deep-temperature-1.0')));
    expect(find.text('Temperature: 1.0'), findsOneWidget);
    await tapControl(tester, find.byType(DropdownButtonFormField<int>));
    final a = await tester.runAsync(DeepRecommendationAssets.load);
    await tester.tap(
      find.text('Anchor 1 · User ${a!.data['first_batch']['users'][1]}').last,
    );
    await tester.pumpAndSettle();
    await tapControl(tester, find.text('Reset contrastive batch'));
    expect(find.text('Temperature: 0.2'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Chapter 32 all quiz questions show feedback and retry', (
    tester,
  ) async {
    await tester.runAsync(() => c.selectChapter('chapter_32'));
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
    'Chapter 32 saved coding scratchpad accepts the tower dot numeric check',
    (tester) async {
      await tester.runAsync(() => c.selectChapter('chapter_32'));
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
      expect(saved?['draft'], contains('products'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Frozen ranker feature intervention, config/cohort and reset', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: const Scaffold(
          body: SingleChildScrollView(child: DeepRankingAuditLab()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tapControl(tester, find.byKey(const Key('deep-neutral')));
    await tapControl(tester, find.byType(DropdownButtonFormField<String>));
    await tester.tap(find.text('hybrid50').last);
    await tester.pumpAndSettle();
    await tapControl(tester, find.byKey(const Key('deep-cohort')));
    expect(
      find.text('Cohort: all future-positive users / all positives'),
      findsOneWidget,
    );
    await tapControl(tester, find.text('Reset deep ranking audit'));
    expect(
      find.text('Cohort: warm users / eligible positives'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'all twenty-one deep recommendation lessons render full derivations, code and labs',
    (tester) async {
      await tester.runAsync(() => c.selectChapter('chapter_32'));
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
