import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ml_path/data/learning_repository.dart';
import 'package:ml_path/main.dart';
import 'package:ml_path/state/learning_controller.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Chapter 7 Android upgrade, geometry, descent, practice and reopen',
    (tester) async {
      final location = p.join(
        await getDatabasesPath(),
        'ml_math_integration.db',
      );
      await deleteDatabase(location);
      var repo = await LearningRepository.open(path: location);
      final previous = (await repo.chapters())
          .where((ch) => ch.number <= 6)
          .toList();
      // Simulate an existing six-chapter learner; never touch the app's main DB.
      await repo.db.delete(
        'chapters',
        where: 'id = ?',
        whereArgs: ['chapter_07'],
      );
      for (final ch in previous) {
        await repo.updateLesson(
          ch.lessons.first.id,
          completed: true,
          bookmarked: true,
          note: 'Saved chapter ${ch.number}',
        );
        await repo.answer(ch.quizzes.first.id, ch.quizzes.first.answer);
        await repo.saveExercise(
          ch.exercises.first.id,
          'Draft chapter ${ch.number}',
          true,
        );
      }
      await repo.setSetting('selected_chapter', 'chapter_06');
      await repo.setSetting('last_lesson:chapter_06', 'ch06_arrays');
      await repo.setSetting('theme', 'dark');
      await repo.close();
      repo = await LearningRepository.open(path: location);
      var c = LearningController(repo);
      await c.load();
      expect(c.chapters.length, greaterThanOrEqualTo(7));
      expect(c.chapter.id, 'chapter_06');
      expect(c.nextLesson.id, 'ch06_arrays');
      await tester.pumpWidget(LearningApp(controller: c));
      await tester.pumpAndSettle();
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text('07 · Linear Algebra, Calculus & Optimization').last,
      );
      await tester.pumpAndSettle();
      expect(c.chapter.id, 'chapter_07');
      expect(c.answers, isEmpty);
      expect(
        (await rootBundle.load('assets/datasets/adult/math_workflow.py'))
            .lengthInBytes,
        greaterThan(5000),
      );
      await binding.takeScreenshot('26-chapter-07-home');
      await tester.ensureVisible(find.text('Start learning'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start learning'));
      await tester.pumpAndSettle();
      expect(find.text('Chapter 7 · Lesson 1 of 18'), findsOneWidget);
      await tester.tap(find.byTooltip('Write a note'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('note-field')),
        'Projection ও derivative assumptions আগে লিখব।',
      );
      await tester.tap(find.text('Save note'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Bookmark lesson'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Mark lesson complete'),
        450,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Mark lesson complete'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lab'));
      await tester.pumpAndSettle();
      expect(find.text('Projection: (3.000, 0.000)'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('math-zero')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('math-zero')));
      await tester.pumpAndSettle();
      expect(find.text('Nonzero-direction formula undefined'), findsOneWidget);
      await tester.ensureVisible(find.text('Reset projection'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset projection'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('math-angle')));
      await tester.pumpAndSettle();
      final angle = tester.getRect(find.byKey(const Key('math-angle')));
      await tester.tapAt(Offset(angle.right - 1, angle.center.dy));
      await tester.pumpAndSettle();
      expect(find.text('Direction angle: 180°'), findsOneWidget);
      expect(find.text('Projection: (3.000, 0.000)'), findsOneWidget);
      await tester.ensureVisible(find.text('Projection: (3.000, 0.000)'));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('27-chapter-07-projection');
      await tester.scrollUntilVisible(
        find.byKey(const Key('math-20')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('math-20')));
      await tester.pumpAndSettle();
      expect(find.text('Steps: 20'), findsOneWidget);
      expect(find.text('Within stable step range'), findsOneWidget);
      await tester.ensureVisible(find.textContaining('Current θ:'));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('28-chapter-07-curvature');
      await tester.ensureVisible(find.byKey(const Key('math-rate')));
      await tester.pumpAndSettle();
      final rate = tester.getRect(find.byKey(const Key('math-rate')));
      await tester.tapAt(Offset(rate.right - 1, rate.center.dy));
      await tester.pumpAndSettle();
      expect(find.text('Outside stable step range'), findsOneWidget);
      for (
        var i = 0;
        i < 5 && find.text('Divergence guard reached').evaluate().isEmpty;
        i++
      ) {
        await tester.ensureVisible(find.byKey(const Key('math-20')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('math-20')));
        await tester.pumpAndSettle();
      }
      expect(find.text('Divergence guard reached'), findsOneWidget);
      await tester.tap(find.text('Practice'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Start knowledge check'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Start knowledge check'));
      await tester.pumpAndSettle();
      for (final question in c.chapter.quizzes) {
        await tester.ensureVisible(
          find.text(question.options[question.answer]),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(question.options[question.answer]));
        await tester.pumpAndSettle();
        final next = find.text(
          question.id == c.chapter.quizzes.last.id
              ? 'See results'
              : 'Next question →',
        );
        await tester.ensureVisible(next);
        await tester.pumpAndSettle();
        await tester.tap(next);
        await tester.pumpAndSettle();
      }
      expect(find.text('20 / 20'), findsOneWidget);
      await binding.takeScreenshot('29-chapter-07-quiz-results');
      await tester.ensureVisible(find.text('Try again'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(c.answers, isEmpty);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Coding exercises'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Coding exercises'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(TextField).first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).first,
        c.chapter.exercises.first.solution,
      );
      await tester.ensureVisible(find.byType(TextField).at(1));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), '4');
      await tester.ensureVisible(find.text('Check answer').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Check answer').first);
      await tester.pumpAndSettle();
      expect(find.text('ফল মিলেছে'), findsOneWidget);
      await binding.takeScreenshot('30-chapter-07-coding');
      await c.visit('ch07_checking');
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      await repo.close();
      repo = await LearningRepository.open(path: location);
      c = LearningController(repo);
      await c.load();
      expect(c.chapter.id, 'chapter_07');
      expect(c.nextLesson.id, 'ch07_checking');
      expect(c.completedCount, 1);
      expect(c.note('ch07_vectors'), contains('derivative'));
      expect(c.bookmarked('ch07_vectors'), isTrue);
      expect(
        (await repo.exercise('ch07_ex_projection'))?['draft'],
        contains('linalg.norm'),
      );
      expect((await repo.exercise('ch07_ex_projection'))?['solved'], 1);
      for (final ch in previous) {
        await c.selectChapter(ch.id);
        expect(c.score, 1);
        expect(c.completedCount, 1);
        expect(c.bookmarked(ch.lessons.first.id), isTrue);
        expect(c.note(ch.lessons.first.id), 'Saved chapter ${ch.number}');
        expect(
          (await repo.exercise(ch.exercises.first.id))?['draft'],
          'Draft chapter ${ch.number}',
        );
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      await repo.close();
      await deleteDatabase(location);
    },
  );
}
