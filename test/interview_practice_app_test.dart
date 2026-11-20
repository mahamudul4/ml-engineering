import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/data/learning_repository.dart';
import 'package:ml_path/main.dart';
import 'package:ml_path/state/learning_controller.dart';
import 'package:ml_path/features/interview_practice/practice_labs.dart';
import 'package:ml_path/features/interview_practice/practice_model.dart';
import 'package:ml_path/features/lessons/lesson_page.dart';
import 'package:ml_path/features/practice/quiz_page.dart';
import 'package:ml_path/features/practice/practice_page.dart';
import 'package:ml_path/ui/theme.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> waitSql(WidgetTester tester) async {
  for (var i = 0; i < 300; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 20));
    if (find.textContaining('SQLite returned').evaluate().isNotEmpty) break;
  }
  await tester.pumpAndSettle();
  expect(find.textContaining('could not run'), findsNothing);
  expect(find.textContaining('SQLite returned'), findsOneWidget);
}

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
    await PracticeAssets.load();
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
    testWidgets('Chapter 39 responsive overview and dark labs at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() => c.selectChapter('chapter_39'));
      await tester.pumpWidget(LearningApp(controller: c));
      await tester.pumpAndSettle();
      expect(
        find.text('Technical Interview Practice\nReason. Code. Defend.'),
        findsOneWidget,
      );
      if (size.width < 1000) {
        expect(find.text('05 · Interview Practice'), findsOneWidget);
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
      await waitSql(tester);
      await tester.pumpAndSettle();
      expect(find.text('State the invariant. Then select.'), findsOneWidget);
      await tester.tap(find.byTooltip('Toggle light / dark mode'));
      await settleStorage(tester, () => c.themeMode == ThemeMode.dark);
      await tester.scrollUntilVisible(
        find.text('Find the violated contract.'),
        350,
        scrollable: find.byType(Scrollable).last,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
    'Chapter 39 mobile picker opens the first of twenty-four lessons',
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
        find.text('05 · Technical Interview Practice'),
        160,
        scrollable: find.byType(Scrollable).last,
      );
      await Scrollable.ensureVisible(
        tester.element(find.text('05 · Technical Interview Practice').last),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('05 · Technical Interview Practice').last);
      await settleStorage(tester, () => c.chapter.id == 'chapter_39');
      expect(c.chapter.id, 'chapter_39');
      await tester.ensureVisible(find.text('Start learning'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start learning'));
      await tester.runAsync(() async => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pumpAndSettle();
      expect(find.text('ML Systems & Interviews · Chapter 5 · Lesson 1 of 31'), findsOneWidget);
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

  testWidgets('Top-K method,min support,K and reset preserve total order', (
    tester,
  ) async {
    await panel(tester, const TopKPracticeLab());
    expect(find.textContaining('Eligible movies: 1918'), findsOneWidget);
    for (final key in ['topk-method-merge', 'topk-min-50', 'topk-k-20']) {
      await tapControl(tester, find.byKey(Key(key)));
    }
    expect(find.textContaining('Returned items: 20'), findsOneWidget);
    await tapControl(tester, find.text('Reset Top-K practice'));
    expect(find.textContaining('Ranking comparisons: 2185'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Actual SQLite fanout,genre,window,top movies and reset', (
    tester,
  ) async {
    await panel(tester, const SqlInterviewLab());
    await waitSql(tester);
    expect(find.textContaining('Ratings counted: 80668'), findsOneWidget);
    await tapControl(tester, find.byKey(const Key('sql-variant-fanout')));
    await waitSql(tester);
    expect(find.textContaining('Ratings counted: 217203'), findsOneWidget);
    await tapControl(tester, find.byKey(const Key('sql-genre-Comedy')));
    await waitSql(tester);
    await tapControl(tester, find.byKey(const ValueKey('sql-task-summary')));
    await tester.tap(find.text('Latest rating per user').last);
    await tester.pumpAndSettle();
    await waitSql(tester);
    expect(find.text('SQLite returned 10 rows'), findsOneWidget);
    await tapControl(
      tester,
      find.byKey(const ValueKey('sql-task-latest_user')),
    );
    await tester.tap(find.text('Top movies with HAVING').last);
    await tester.pumpAndSettle();
    for (final key in ['sql-variant-fixed', 'sql-min-50', 'sql-k-5']) {
      await tapControl(tester, find.byKey(Key(key)));
    }
    await waitSql(tester);
    expect(find.text('SQLite returned 5 rows'), findsOneWidget);
    await tapControl(tester, find.text('Reset SQL practice'));
    await waitSql(tester);
    expect(find.textContaining('Ratings counted: 80668'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Metric bugs,probability threshold,cost and reset', (
    tester,
  ) async {
    await panel(tester, const MetricDebugLab());
    expect(find.textContaining('Contract check: PASS'), findsOneWidget);
    await tapControl(tester, find.byKey(const Key('debug-bug-precision_swap')));
    expect(find.textContaining('Contract check: FAIL'), findsOneWidget);
    for (final key in [
      'debug-threshold-0.8',
      'debug-cost-100',
      'debug-bug-logit_threshold',
    ]) {
      await tapControl(tester, find.byKey(Key(key)));
    }
    expect(find.textContaining('Contract check: FAIL'), findsOneWidget);
    await tapControl(tester, find.text('Reset metric debugging'));
    expect(find.textContaining('Contract check: PASS'), findsOneWidget);
    expect(find.textContaining('Stable mean BCE: 0.222773'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Chapter 39 all quiz questions show feedback and retry', (
    tester,
  ) async {
    await tester.runAsync(() => c.selectChapter('chapter_39'));
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
    'Chapter 39 saved coding scratchpad accepts the bounded heap numeric check',
    (tester) async {
      await tester.runAsync(() => c.selectChapter('chapter_39'));
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
      expect(saved?['draft'], contains('heapq'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Debug reset restores independent reported and actual precision',
    (tester) async {
      await panel(tester, const MetricDebugLab());
      await tapControl(
        tester,
        find.byKey(const Key('debug-bug-precision_swap')),
      );
      expect(
        find.textContaining('Reported precision: 0.882813'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Actual precision for these decisions: 0.918699'),
        findsOneWidget,
      );
      await tapControl(tester, find.text('Reset metric debugging'));
      expect(
        find.textContaining('Reported precision: 0.918699'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'all twenty-four interview-practice lessons render full derivations, code and labs',
    (tester) async {
      await tester.runAsync(() => c.selectChapter('chapter_39'));
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
