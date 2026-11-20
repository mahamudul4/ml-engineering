import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ml_path/data/learning_repository.dart';
import 'package:ml_path/main.dart';
import 'package:ml_path/features/statistics/statistics_model.dart';
import 'package:ml_path/state/learning_controller.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Chapter 8 Android upgrade, Bayes, intervals, practice and reopen',
    (tester) async {
      final location = p.join(
        await getDatabasesPath(),
        'ml_statistics_integration.db',
      );
      await deleteDatabase(location);
      var repo = await LearningRepository.open(path: location);
      final previous = (await repo.chapters())
          .where((ch) => ch.number <= 7)
          .toList();
      // Simulate an existing seven-chapter learner; never touch the app's main DB.
      await repo.db.delete(
        'chapters',
        where: 'id = ?',
        whereArgs: ['chapter_08'],
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
      await repo.setSetting('selected_chapter', 'chapter_07');
      await repo.setSetting('last_lesson:chapter_07', 'ch07_checking');
      await repo.setSetting('theme', 'dark');
      await repo.close();
      repo = await LearningRepository.open(path: location);
      var c = LearningController(repo);
      await c.load();
      expect(c.chapters.length, greaterThanOrEqualTo(8));
      expect(c.chapter.id, 'chapter_07');
      expect(c.nextLesson.id, 'ch07_checking');
      await tester.pumpWidget(LearningApp(controller: c));
      await tester.pumpAndSettle();
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text('08 · Probability, Statistics & Inference').last,
      );
      await tester.pumpAndSettle();
      expect(c.chapter.id, 'chapter_08');
      expect(c.answers, isEmpty);
      expect(
        (await rootBundle.load('assets/datasets/adult/statistics_workflow.py'))
            .lengthInBytes,
        greaterThan(5000),
      );
      await binding.takeScreenshot('31-chapter-08-home');
      await tester.ensureVisible(find.text('Start learning'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start learning'));
      await tester.pumpAndSettle();
      expect(find.text('Chapter 8 · Lesson 1 of 17'), findsOneWidget);
      await tester.tap(find.byTooltip('Write a note'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('note-field')),
        'Probability ও inference assumptions আগে লিখব।',
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
      expect(find.text('P(event | flag): 15.38%'), findsOneWidget);
      for (final pair in [
        ('stats-perfect', 'P(event | flag): 100.00%'),
        ('stats-no-flags', 'P(event | flag): undefined (no flags)'),
      ]) {
        await tester.ensureVisible(find.byKey(Key(pair.$1)));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(Key(pair.$1)));
        await tester.pumpAndSettle();
        expect(find.text(pair.$2), findsOneWidget);
      }
      await tester.ensureVisible(find.text('Reset Bayes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset Bayes'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('P(event | flag): 15.38%'));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('32-chapter-08-bayes');
      await tester.scrollUntilVisible(
        find.byKey(const Key('stats-successes')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      final slider = tester.getRect(find.byKey(const Key('stats-successes')));
      await tester.tapAt(Offset(slider.left + 1, slider.center.dy));
      await tester.pumpAndSettle();
      expect(find.text('Selected interval: [0.000, 0.161]'), findsOneWidget);
      await tester.ensureVisible(
        find.byType(DropdownButtonFormField<IntervalMethod>),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<IntervalMethod>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Wald normal (clipped)').last);
      await tester.pumpAndSettle();
      expect(find.text('Selected interval: [0.000, 0.000]'), findsOneWidget);
      await tester.ensureVisible(find.text('Selected interval misses p'));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('33-chapter-08-coverage');
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
      await binding.takeScreenshot('34-chapter-08-quiz-results');
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
      await tester.enterText(find.byType(TextField).at(1), (2 / 13).toString());
      await tester.ensureVisible(find.text('Check answer').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Check answer').first);
      await tester.pumpAndSettle();
      expect(find.text('ফল মিলেছে'), findsOneWidget);
      await binding.takeScreenshot('35-chapter-08-coding');
      await c.visit('ch08_intervals');
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      await repo.close();
      repo = await LearningRepository.open(path: location);
      c = LearningController(repo);
      await c.load();
      expect(c.chapter.id, 'chapter_08');
      expect(c.nextLesson.id, 'ch08_intervals');
      expect(c.completedCount, 1);
      expect(c.note('ch08_estimands'), contains('inference'));
      expect(c.bookmarked('ch08_estimands'), isTrue);
      expect(
        (await repo.exercise('ch08_ex_bayes'))?['draft'],
        contains('posterior'),
      );
      expect((await repo.exercise('ch08_ex_bayes'))?['solved'], 1);
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
