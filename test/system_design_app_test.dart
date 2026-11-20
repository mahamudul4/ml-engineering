import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/data/learning_repository.dart';
import 'package:ml_path/main.dart';
import 'package:ml_path/state/learning_controller.dart';
import 'package:ml_path/features/system_design/design_labs.dart';
import 'package:ml_path/features/system_design/design_model.dart';
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
    await DesignAssets.load();
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
    testWidgets('Chapter 38 responsive overview and dark labs at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() => c.selectChapter('chapter_38'));
      await tester.pumpWidget(LearningApp(controller: c));
      await tester.pumpAndSettle();
      expect(
        find.text('ML System Design\nConnect. Budget. Defend.'),
        findsOneWidget,
      );
      if (size.width < 1000) {
        expect(find.text('04 · ML System Design'), findsOneWidget);
      }
      expect(
        find.text('0 of ${c.chapter.lessons.length} completed'),
        findsOneWidget,
      );
      await tester.tap(
        find.text(size.width < 1000 ? 'Lab' : 'Interactive lab').first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Map the path. Budget the bottleneck.'), findsOneWidget);
      await tester.tap(find.byTooltip('Toggle light / dark mode'));
      await settleStorage(tester, () => c.themeMode == ThemeMode.dark);
      await tester.scrollUntilVisible(
        find.text('Replay the dependency. Defend the response.'),
        350,
        scrollable: find.byType(Scrollable).last,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('Chapter 38 mobile picker opens the first of twenty lessons', (
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
      find.text('04 · ML System Design Cases'),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    await Scrollable.ensureVisible(
      tester.element(find.text('04 · ML System Design Cases').last),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('04 · ML System Design Cases').last);
    await settleStorage(tester, () => c.chapter.id == 'chapter_38');
    expect(c.chapter.id, 'chapter_38');
    await tester.ensureVisible(find.text('Start learning'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start learning'));
    await tester.runAsync(() async => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pumpAndSettle();
    expect(find.text('ML Systems & Interviews · Chapter 4 · Lesson 1 of 22'), findsOneWidget);
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
    'Architecture case,load,cache,replicas,path scale and deadline reset',
    (tester) async {
      await panel(tester, const ArchitectureCapacityLab());
      expect(find.textContaining('Critical path 20.000 ms'), findsOneWidget);
      await tapControl(
        tester,
        find.byKey(const ValueKey('architecture-case-recommendation')),
      );
      await tester.tap(find.text('Retrieval-augmented response').last);
      await tester.pumpAndSettle();
      for (final key in [
        'architecture-qps-10000',
        'architecture-hit-0.0',
        'architecture-replicas-1',
        'architecture-scale-2.0',
        'architecture-deadline-50',
      ]) {
        await tapControl(tester, find.byKey(Key(key)));
      }
      expect(find.textContaining('Planning state: OVERLOAD'), findsOneWidget);
      expect(find.textContaining('Critical path 104.000 ms'), findsOneWidget);
      await tapControl(tester, find.text('Reset architecture plan'));
      expect(
        find.byKey(const ValueKey('architecture-case-recommendation')),
        findsOneWidget,
      );
      expect(find.textContaining('Utilization 0.625'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Selective review thresholds,budget,overflow,cost and contract gate reset',
    (tester) async {
      await panel(tester, const SelectiveReviewLab());
      expect(find.textContaining('Unresolved decisions 132'), findsOneWidget);
      for (final key in [
        'review-low-0.4',
        'review-high-0.6',
        'review-budget-20',
        'review-overflow-allow',
        'review-cost-10',
      ]) {
        await tapControl(tester, find.byKey(Key(key)));
      }
      expect(find.text('Overflow policy: allow'), findsOneWidget);
      await tapControl(tester, find.byKey(const Key('review-contract-fault')));
      expect(find.textContaining('contract blocked 738'), findsOneWidget);
      expect(
        find.textContaining('Conditional automatic accuracy undefined'),
        findsOneWidget,
      );
      await tapControl(tester, find.text('Reset review policy'));
      expect(
        find.textContaining('Auto-allow 418 · auto-block 188'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Source-backed forecast fallback and RAG abstention change with case and reset',
    (tester) async {
      await panel(tester, const CaseFailureLab());
      await tapControl(
        tester,
        find.byKey(const ValueKey('failure-case-recommendation')),
      );
      await tester.tap(find.text('Daily demand forecasting').last);
      await tester.pumpAndSettle();
      await tapControl(tester, find.byKey(const Key('failure-fault-upstream')));
      expect(find.textContaining('Served by seasonal7'), findsOneWidget);
      expect(find.text('prediction: 2368.000'), findsOneWidget);
      await tapControl(
        tester,
        find.byKey(const ValueKey('failure-case-forecast')),
      );
      await tester.tap(find.text('Retrieval-augmented response').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('Response: ABSTAIN'), findsOneWidget);
      expect(
        find.textContaining('Reason empty_context_fixture'),
        findsOneWidget,
      );
      await tapControl(tester, find.text('Reset case failure replay'));
      expect(find.textContaining('Served by weighted_rrf'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Chapter 38 all quiz questions show feedback and retry', (
    tester,
  ) async {
    await tester.runAsync(() => c.selectChapter('chapter_38'));
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
    'Chapter 38 saved coding scratchpad accepts the parallel critical path numeric check',
    (tester) async {
      await tester.runAsync(() => c.selectChapter('chapter_38'));
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
      expect(saved?['draft'], contains('stage_times'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Manifest incompatibility blocks request outputs and reset restores source replay',
    (tester) async {
      await panel(tester, const CaseFailureLab());
      await tapControl(
        tester,
        find.byKey(const Key('failure-fault-model_mismatch')),
      );
      expect(find.textContaining('Response: BLOCKED'), findsOneWidget);
      expect(find.textContaining('items:'), findsNothing);
      await tapControl(tester, find.text('Reset case failure replay'));
      expect(find.textContaining('Response: OK'), findsOneWidget);
      expect(find.textContaining('items:'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'all twenty system-design lessons render full derivations, code and labs',
    (tester) async {
      await tester.runAsync(() => c.selectChapter('chapter_38'));
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
