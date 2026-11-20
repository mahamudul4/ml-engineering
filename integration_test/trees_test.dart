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
    'Chapter 9 Android upgrade, split, pruning, practice and reopen',
    (tester) async {
      final location = p.join(
        await getDatabasesPath(),
        'ml_trees_integration.db',
      );
      await deleteDatabase(location);
      var repo = await LearningRepository.open(path: location);
      final previous = (await repo.chapters())
          .where((ch) => ch.number <= 8)
          .toList();
      // Simulate an existing eight-chapter learner; never touch the app's main DB.
      await repo.db.delete(
        'chapters',
        where: 'id = ?',
        whereArgs: ['chapter_09'],
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
      await repo.setSetting('selected_chapter', 'chapter_08');
      await repo.setSetting('last_lesson:chapter_08', 'ch08_intervals');
      await repo.setSetting('theme', 'dark');
      await repo.close();
      repo = await LearningRepository.open(path: location);
      var c = LearningController(repo);
      await c.load();
      expect(c.chapters.length, greaterThanOrEqualTo(9));
      expect(c.chapter.id, 'chapter_08');
      expect(c.nextLesson.id, 'ch08_intervals');
      await tester.pumpWidget(LearningApp(controller: c));
      await tester.pumpAndSettle();
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('09 · Decision Trees').last);
      await tester.pumpAndSettle();
      expect(c.chapter.id, 'chapter_09');
      expect(c.answers, isEmpty);
      expect(
        (await rootBundle.load('assets/datasets/adult/tree_workflow.py'))
            .lengthInBytes,
        greaterThan(5000),
      );
      await binding.takeScreenshot('36-chapter-09-home');
      await tester.ensureVisible(find.text('Start learning'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start learning'));
      await tester.pumpAndSettle();
      expect(find.text('Chapter 9 · Lesson 1 of 17'), findsOneWidget);
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
      expect(find.text('Rule: age ≤ 35.0 → left'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('tree-best')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tree-best')));
      await tester.pumpAndSettle();
      expect(find.text('Admissible split'), findsOneWidget);
      await tester.ensureVisible(
        find.textContaining('Weighted child impurity:'),
      );
      await tester.pumpAndSettle();
      await binding.takeScreenshot('37-chapter-09-split');
      await tester.ensureVisible(find.byKey(const Key('tree-empty')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tree-empty')));
      await tester.pumpAndSettle();
      expect(find.text('Gain: undefined'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('tree-root')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('tree-root')));
      await tester.pumpAndSettle();
      expect(find.text('Root-only tree'), findsOneWidget);
      expect(find.text('Leaves: 1'), findsOneWidget);
      await tester.ensureVisible(find.text('Leaves: 1'));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('38-chapter-09-pruning');
      await tester.ensureVisible(find.text('Restore full tree'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restore full tree'));
      await tester.pumpAndSettle();
      expect(find.text('Leaves: 29'), findsOneWidget);
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
      await binding.takeScreenshot('39-chapter-09-quiz-results');
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
      await tester.enterText(find.byType(TextField).at(1), .375.toString());
      await tester.ensureVisible(find.text('Check answer').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Check answer').first);
      await tester.pumpAndSettle();
      expect(find.text('ফল মিলেছে'), findsOneWidget);
      await binding.takeScreenshot('40-chapter-09-coding');
      await c.visit('ch09_pruning');
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      await repo.close();
      repo = await LearningRepository.open(path: location);
      c = LearningController(repo);
      await c.load();
      expect(c.chapter.id, 'chapter_09');
      expect(c.nextLesson.id, 'ch09_pruning');
      expect(c.completedCount, 1);
      expect(c.note('ch09_rules'), contains('inference'));
      expect(c.bookmarked('ch09_rules'), isTrue);
      expect((await repo.exercise('ch09_ex_gini'))?['draft'], contains('gini'));
      expect((await repo.exercise('ch09_ex_gini'))?['solved'], 1);
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
