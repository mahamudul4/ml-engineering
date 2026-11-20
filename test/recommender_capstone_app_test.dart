import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/data/learning_repository.dart';
import 'package:ml_path/main.dart';
import 'package:ml_path/state/learning_controller.dart';
import 'package:ml_path/features/recommender_capstone/capstone_labs.dart';
import 'package:ml_path/features/recommender_capstone/capstone_model.dart';
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
    await RecommenderCapstoneAssets.load();
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
    testWidgets('Chapter 34 responsive overview and dark labs at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() => c.selectChapter('chapter_34'));
      await tester.pumpWidget(LearningApp(controller: c));
      await tester.pumpAndSettle();
      expect(
        find.text('Recommender Capstone\nBuild. Audit. Defend.'),
        findsOneWidget,
      );
      if (size.width < 1000) {
        expect(find.text('05 · Recommender Capstone'), findsOneWidget);
      }
      expect(
        find.text('0 of ${c.chapter.lessons.length} completed'),
        findsOneWidget,
      );
      await tester.tap(
        find.text(size.width < 1000 ? 'Lab' : 'Interactive lab').first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Build the pool. Explain every rank.'), findsOneWidget);
      await tester.tap(find.byTooltip('Toggle light / dark mode'));
      await settleStorage(tester, () => c.themeMode == ThemeMode.dark);
      await tester.scrollUntilVisible(
        find.text('Version the model. Guard the response.'),
        350,
        scrollable: find.byType(Scrollable).last,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('Chapter 34 mobile picker opens the first of twenty lessons', (
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
      find.text('05 · Recommender Capstone'),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    await Scrollable.ensureVisible(
      tester.element(find.text('05 · Recommender Capstone').last),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('05 · Recommender Capstone').last);
    await settleStorage(tester, () => c.chapter.id == 'chapter_34');
    expect(c.chapter.id, 'chapter_34');
    await tester.ensureVisible(find.text('Start learning'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start learning'));
    await tester.runAsync(() async => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pumpAndSettle();
    expect(find.text('Recommender Systems · Chapter 5 · Lesson 1 of 21'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  Future<void> tapControl(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('Capstone source budget, fusion preset and reset', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: const Scaffold(
          body: SingleChildScrollView(child: CapstoneRetrievalLab()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Per-source budget: 50'), findsOneWidget);
    await tapControl(tester, find.byKey(const Key('capstone-budget-100')));
    expect(find.text('Per-source budget: 100'), findsOneWidget);
    await tapControl(
      tester,
      find.byKey(const ValueKey('capstone-policy-rrf_cf')),
    );
    await tester.tap(find.text('rrf_content').last);
    await tester.pumpAndSettle();
    await tapControl(tester, find.text('Reset capstone retrieval'));
    expect(find.text('Per-source budget: 50'), findsOneWidget);
    expect(find.text('rrf_cf'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Locked selector survives audit and cold cohort inspection', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: const Scaffold(
          body: SingleChildScrollView(child: CapstoneEvaluationLab()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Locked fusion selection: rrf_cf'),
      findsOneWidget,
    );
    await tapControl(
      tester,
      find.byKey(const ValueKey('capstone-role-validation')),
    );
    await tester.tap(find.text('audit').last);
    await tester.pumpAndSettle();
    await tapControl(tester, find.byKey(const ValueKey('capstone-scope-warm')));
    await tester.tap(find.text('cold').last);
    await tester.pumpAndSettle();
    expect(find.text('Scorecard: audit / cold'), findsOneWidget);
    expect(
      find.textContaining('Locked fusion selection: rrf_cf'),
      findsOneWidget,
    );
    await tapControl(tester, find.text('Reset capstone evaluation'));
    expect(find.text('Scorecard: validation / warm'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Cold source case shows declared popularity fallback', (
    tester,
  ) async {
    final a = await tester.runAsync(RecommenderCapstoneAssets.load);
    final cold = (a!.data['samples'] as List).last;
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: const Scaffold(
          body: SingleChildScrollView(child: CapstoneRetrievalLab()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tapControl(tester, find.byType(DropdownButtonFormField<int>));
    await tester.tap(find.text('User $cold · popularity fallback').last);
    await tester.pumpAndSettle();
    expect(find.text('User $cold · popularity fallback'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Chapter 34 all quiz questions show feedback and retry', (
    tester,
  ) async {
    await tester.runAsync(() => c.selectChapter('chapter_34'));
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
    'Chapter 34 saved coding scratchpad accepts the RRF contribution numeric check',
    (tester) async {
      await tester.runAsync(() => c.selectChapter('chapter_34'));
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
      expect(saved?['draft'], contains('sources'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Contract faults block replay and policy cache collisions reject',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: CapstoneServingLab()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Contract: READY'), findsOneWidget);
      await tapControl(
        tester,
        find.byKey(const ValueKey('capstone-cache-complete')),
      );
      await tester.tap(find.text('omit_policy').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('3 rejected collisions'), findsOneWidget);
      await tapControl(
        tester,
        find.byKey(const ValueKey('capstone-fault-none')),
      );
      await tester.tap(find.text('feature_schema').last);
      await tester.pumpAndSettle();
      expect(find.text('Contract: BLOCKED · feature_schema'), findsOneWidget);
      expect(find.textContaining('Replay: 5 requests'), findsNothing);
      await tapControl(tester, find.text('Reset capstone serving'));
      expect(find.text('Contract: READY'), findsOneWidget);
      expect(find.textContaining('0 rejected collisions'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'all twenty capstone lessons render full derivations, code and labs',
    (tester) async {
      await tester.runAsync(() => c.selectChapter('chapter_34'));
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
