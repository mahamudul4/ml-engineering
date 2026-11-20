import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/data/learning_repository.dart';
import 'package:ml_path/features/practice/practice_page.dart';
import 'package:ml_path/features/practice/quiz_page.dart';
import 'package:ml_path/state/learning_controller.dart';
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
    await c.selectChapter('chapter_41');
  });
  tearDown(() async {
    c.dispose();
    await c.repository.close();
  });
  Future<void> settle(WidgetTester tester, bool Function() condition) async {
    for (var i = 0; i < 100 && !condition(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    expect(condition(), isTrue);
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('all RL quiz feedback, score and scoped retry work', (
    tester,
  ) async {
    final legacyId = c.chapters.first.quizzes.first.id;
    await tester.runAsync(() => c.repository.answer(legacyId, 0));
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: QuizPage(controller: c),
      ),
    );
    await tester.pumpAndSettle();
    for (final question in c.chapter.quizzes) {
      await tap(tester, find.text(question.options[question.answer]));
      await settle(tester, () => c.answers.containsKey(question.id));
      expect(find.text(question.explanation), findsOneWidget);
      await tap(
        tester,
        find.text(
          question == c.chapter.quizzes.last
              ? 'See results'
              : 'Next question →',
        ),
      );
    }
    final quizCount = c.chapter.quizzes.length;
    expect(find.text('$quizCount / $quizCount'), findsOneWidget);
    await tap(tester, find.text('Try again'));
    await settle(tester, () => c.answers.isEmpty);
    final answers = await tester.runAsync(() => c.repository.answers());
    expect(answers![legacyId], 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rounded softmax result passes in the exercise UI and persists', (
    tester,
  ) async {
    await tester.runAsync(() => c.selectChapter('chapter_03'));
    final exercise = c.chapter.exercises.firstWhere(
      (value) => value.id == 'ch03_ex_softmax',
    );
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
    await settle(tester, () => find.byType(TextField).evaluate().length == 2);
    await tester.enterText(find.byType(TextField).last, '0.334');
    await tap(tester, find.text('Check answer'));
    await settle(
      tester,
      () => find.textContaining('ফল মেলেনি।').evaluate().isNotEmpty,
    );
    await tester.enterText(find.byType(TextField).last, '0.333');
    await tap(tester, find.text('Check answer'));
    await settle(tester, () => find.text('ফল মিলেছে').evaluate().isNotEmpty);
    final saved = await tester.runAsync(
      () => c.repository.exercise(exercise.id),
    );
    expect(saved!['solved'], 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wrong RL answer has feedback without awarding a point', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: QuizPage(controller: c),
      ),
    );
    await tester.pumpAndSettle();
    final question = c.chapter.quizzes.first;
    await tap(tester, find.text(question.options[1]));
    await settle(tester, () => c.answers.isNotEmpty);
    expect(c.score, 0);
    expect(find.text(question.explanation), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'tiny contrastive loss rejects zero in the actual scratchpad UI',
    (tester) async {
      await tester.runAsync(() => c.selectChapter('chapter_23'));
      final exercise = c.chapter.exercises.firstWhere(
        (exercise) => exercise.id == 'ch23_ex_contrastive',
      );
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
      await settle(tester, () => find.byType(TextField).evaluate().length == 2);
      await tester.enterText(find.byType(TextField).last, '0');
      await tap(tester, find.text('Check answer'));
      await settle(
        tester,
        () => find.textContaining('ফল মেলেনি।').evaluate().isNotEmpty,
      );
      expect(find.text('ফল মিলেছে'), findsNothing);
      await tester.enterText(
        find.byType(TextField).last,
        exercise.expected.toString(),
      );
      await tap(tester, find.text('Check answer'));
      await settle(tester, () => find.text('ফল মিলেছে').evaluate().isNotEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'RL code draft and numerical result persist for all six exercises',
    (tester) async {
      for (final exercise in c.chapter.exercises) {
        await tester.pumpWidget(
          MaterialApp(
            theme: appTheme(Brightness.light),
            home: Scaffold(
              body: SingleChildScrollView(
                child: ExerciseCard(
                  key: ValueKey(exercise.id),
                  controller: c,
                  exercise: exercise,
                ),
              ),
            ),
          ),
        );
        await settle(
          tester,
          () => find.byType(TextField).evaluate().length == 2,
        );
        await tester.enterText(find.byType(TextField).first, exercise.solution);
        await tester.enterText(
          find.byType(TextField).last,
          exercise.expected.toString(),
        );
        await tap(tester, find.text('Check answer'));
        await settle(
          tester,
          () => find.text('ফল মিলেছে').evaluate().isNotEmpty,
        );
        final saved = await tester.runAsync(
          () => c.repository.exercise(exercise.id),
        );
        expect(saved!['draft'], exercise.solution);
        expect(saved['solved'], 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
}
