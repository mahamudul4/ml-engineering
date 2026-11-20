import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/data/learning_repository.dart';
import 'package:ml_path/main.dart';
import 'package:ml_path/state/learning_controller.dart';
import 'package:ml_path/features/ensembles/ensemble_labs.dart';
import 'package:ml_path/features/ensembles/ensemble_model.dart';
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
    await EnsembleAssets.load();
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
    testWidgets('Chapter 10 responsive overview and dark labs at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() => c.selectChapter('chapter_10'));
      await tester.pumpWidget(LearningApp(controller: c));
      await tester.pumpAndSettle();
      expect(find.text('Ensembles\n& Boosting'), findsOneWidget);
      expect(
        find.text('0 of ${c.chapter.lessons.length} completed'),
        findsOneWidget,
      );
      await tester.tap(
        find.text(size.width < 1000 ? 'Lab' : 'Interactive lab').first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Which trees may vote?'), findsOneWidget);
      await tester.tap(find.byTooltip('Toggle light / dark mode'));
      await settleStorage(tester, () => c.themeMode == ThemeMode.dark);
      await tester.scrollUntilVisible(
        find.text('Add a correction. Recompute the residual.'),
        350,
        scrollable: find.byType(Scrollable).last,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('Chapter 10 mobile picker opens the first of eighteen lessons', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(LearningApp(controller: c));
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const ValueKey('book-chip-classical'))),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('book-chip-classical')));
    for (var i = 0; i < 100 && c.currentBook.id != 'classical'; i++) {
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('05 · Ensembles & Boosting').last);
    await settleStorage(tester, () => c.chapter.id == 'chapter_10');
    expect(c.chapter.id, 'chapter_10');
    await tester.ensureVisible(find.text('Start learning'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start learning'));
    await tester.runAsync(() async => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pumpAndSettle();
    expect(find.text('Classical ML · Chapter 5 · Lesson 1 of 19'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'Bagging controls preserve the OOB denominator and undefined support',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: BaggingLab()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Members considered: 1 / 24'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('ensemble-oob')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ensemble-oob')));
      await tester.pumpAndSettle();
      expect(
        find.text('Prediction unavailable (no OOB members)'),
        findsOneWidget,
      );
      expect(find.text('Eligible members: 0'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('ensemble-all')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ensemble-all')));
      await tester.pumpAndSettle();
      expect(
        find.text('Prediction unavailable (no OOB members)'),
        findsNothing,
      );
      expect(find.textContaining('Mean positive probability:'), findsOneWidget);
      await tester.ensureVisible(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      final asset = await EnsembleAssets.load();
      await tester.tap(find.text('Row #${asset.points[1].sourceRow}').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Reset bagging'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset bagging'));
      await tester.pumpAndSettle();
      expect(find.text('Members considered: 1 / 24'), findsOneWidget);
      expect(find.text('Row #${asset.points.first.sourceRow}'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Boosting controls show the additive update and independently refitted rates',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: BoostingLab()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Round 0: training-mean baseline'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('ensemble-next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ensemble-next')));
      await tester.pumpAndSettle();
      expect(find.text('Boosting round: 1 / 16'), findsOneWidget);
      expect(find.textContaining('Update:'), findsOneWidget);
      await tester.tap(find.byKey(const Key('ensemble-final')));
      await tester.pumpAndSettle();
      expect(find.text('Boosting round: 16 / 16'), findsOneWidget);
      await tester.ensureVisible(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1.0').last);
      await tester.pumpAndSettle();
      expect(find.text('Validation RMSE: 11.221 h'), findsOneWidget);
      await tester.ensureVisible(find.text('Reset boosting'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset boosting'));
      await tester.pumpAndSettle();
      expect(find.text('Round 0: training-mean baseline'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Chapter 10 all twenty-four quiz questions show feedback and retry',
    (tester) async {
      await tester.runAsync(() => c.selectChapter('chapter_10'));
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
      expect(find.text('24 / 24'), findsOneWidget);
      await tester.ensureVisible(find.text('Try again'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Try again'));
      await settleStorage(tester, () => c.answers.isEmpty);
      expect(c.answers, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Chapter 10 saved coding scratchpad accepts the soft-average numeric check',
    (tester) async {
      await tester.runAsync(() => c.selectChapter('chapter_10'));
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
        (1.97 / 3).toString(),
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
      expect(saved?['draft'], contains('sum(p)'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'all eighteen ensemble lessons render full derivations, code and labs',
    (tester) async {
      await tester.runAsync(() => c.selectChapter('chapter_10'));
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
