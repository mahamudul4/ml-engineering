import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/data/learning_repository.dart';
import 'package:ml_path/main.dart';
import 'package:ml_path/state/learning_controller.dart';
import 'package:ml_path/features/mlops/mlops_labs.dart';
import 'package:ml_path/features/mlops/mlops_model.dart';
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
    await MLOpsAssets.load();
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
    testWidgets('Chapter 36 responsive overview and dark labs at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() => c.selectChapter('chapter_36'));
      await tester.pumpWidget(LearningApp(controller: c));
      await tester.pumpAndSettle();
      expect(
        find.text('Serving & MLOps\nPackage. Observe. Recover.'),
        findsOneWidget,
      );
      if (size.width < 1000) {
        expect(find.text('02 · Serving & MLOps'), findsOneWidget);
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
        find.text('Route the release. Keep a safe fallback.'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Toggle light / dark mode'));
      await settleStorage(tester, () => c.themeMode == ThemeMode.dark);
      await tester.scrollUntilVisible(
        find.text('Count good requests. Rehearse recovery.'),
        350,
        scrollable: find.byType(Scrollable).last,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('Chapter 36 mobile picker opens the first of twenty lessons', (
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
      find.text('02 · Serving, Monitoring & MLOps'),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    await Scrollable.ensureVisible(
      tester.element(find.text('02 · Serving, Monitoring & MLOps').last),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('02 · Serving, Monitoring & MLOps').last);
    await settleStorage(tester, () => c.chapter.id == 'chapter_36');
    expect(c.chapter.id, 'chapter_36');
    await tester.ensureVisible(find.text('Start learning'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start learning'));
    await tester.runAsync(() async => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pumpAndSettle();
    expect(find.text('ML Systems & Interviews · Chapter 2 · Lesson 1 of 21'), findsOneWidget);
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

  testWidgets('Canary,late arrivals and candidate contract fallback reset', (
    tester,
  ) async {
    await panel(tester, const ReleaseRoutingLab());
    expect(find.textContaining('Serving: candidate'), findsOneWidget);
    await tapControl(tester, find.byKey(const Key('mlops-canary-1000')));
    expect(find.text('Candidate traffic: 10%'), findsOneWidget);
    expect(find.textContaining('Candidate 22 · baseline 160'), findsOneWidget);
    await tapControl(tester, find.byKey(const Key('mlops-canary-10000')));
    await tapControl(
      tester,
      find.byKey(const Key('mlops-scenario-late_fixture')),
    );
    expect(find.textContaining('Serving: fallback'), findsOneWidget);
    await tapControl(tester, find.byKey(const Key('mlops-scenario-on_time')));
    await tapControl(tester, find.byKey(const Key('mlops-candidate-fault')));
    expect(find.textContaining('candidate_contract'), findsOneWidget);
    await tapControl(tester, find.text('Reset release routing'));
    expect(find.textContaining('Serving: candidate'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Actual source date selection and rollback independently reset', (
    tester,
  ) async {
    await panel(tester, const ReleaseRoutingLab());
    await tapControl(tester, find.byKey(const ValueKey('mlops-target-375')));
    await tester.tap(find.text('2012-06-29 · day545').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mlops-target-545')), findsOneWidget);
    await tapControl(tester, find.byKey(const Key('mlops-rollback')));
    expect(find.textContaining('Serving: baseline'), findsOneWidget);
    expect(find.textContaining('baseline 182'), findsOneWidget);
    await tapControl(tester, find.text('Reset release routing'));
    expect(find.byKey(const ValueKey('mlops-target-375')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Monitoring period,feature and label maturity change and reset', (
    tester,
  ) async {
    await panel(tester, const MonitoringDriftLab());
    expect(
      find.textContaining('Request rows 182 · mature labels 182'),
      findsOneWidget,
    );
    await tapControl(tester, find.byKey(const ValueKey('mlops-period-full')));
    await tester.tap(find.text('late').last);
    await tester.pumpAndSettle();
    await tapControl(tester, find.byKey(const ValueKey('mlops-feature-lag1')));
    await tester.tap(find.text('mean7').last);
    await tester.pumpAndSettle();
    await tapControl(tester, find.byKey(const Key('mlops-delay-7')));
    expect(
      find.textContaining('Request rows 91 · mature labels 84'),
      findsOneWidget,
    );
    await tapControl(tester, find.text('Reset monitoring audit'));
    expect(
      find.textContaining('Request rows 182 · mature labels 182'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Chapter 36 all quiz questions show feedback and retry', (
    tester,
  ) async {
    await tester.runAsync(() => c.selectChapter('chapter_36'));
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
    'Chapter 36 saved coding scratchpad accepts the standardized Ridge numeric check',
    (tester) async {
      await tester.runAsync(() => c.selectChapter('chapter_36'));
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
      expect(saved?['draft'], contains('standardized'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('SLO thresholds,budgets and verified local rollback reset', (
    tester,
  ) async {
    await panel(tester, const SLOIncidentLab());
    expect(find.textContaining('Composite good 16 / 20'), findsOneWidget);
    await tapControl(tester, find.byKey(const Key('mlops-latency-200')));
    await tapControl(tester, find.byKey(const Key('mlops-slo-0.95')));
    expect(find.textContaining('Composite good 18 / 20'), findsOneWidget);
    await tapControl(tester, find.byKey(const Key('mlops-rehearse-rollback')));
    expect(find.textContaining('Rehearsal: ROLLBACK VERIFIED'), findsOneWidget);
    await tapControl(tester, find.text('Reset SLO rehearsal'));
    expect(find.textContaining('Composite good 16 / 20'), findsOneWidget);
    expect(find.textContaining('Rehearsal: ROLLBACK VERIFIED'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'all twenty MLOps lessons render full derivations, code and labs',
    (tester) async {
      await tester.runAsync(() => c.selectChapter('chapter_36'));
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
