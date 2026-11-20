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
    'Chapter 16 Android upgrade, forward, backprop, training, practice and reopen',
    (tester) async {
      final location = p.join(
        await getDatabasesPath(),
        'ml_neural_integration.db',
      );
      await deleteDatabase(location);
      var repo = await LearningRepository.open(path: location);
      final previous = (await repo.chapters())
          .where((ch) => ch.number <= 15)
          .toList();
      // Simulate an existing fifteen-chapter learner; never touch the app's main DB.
      await repo.db.delete(
        'chapters',
        where: 'id = ?',
        whereArgs: ['chapter_16'],
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
      await repo.setSetting('selected_chapter', 'chapter_15');
      await repo.setSetting('last_lesson:chapter_15', 'ch15_microscope');
      await repo.setSetting('theme', 'dark');
      await repo.close();
      repo = await LearningRepository.open(path: location);
      var c = LearningController(repo);
      await c.load();
      expect(c.chapters.length, greaterThanOrEqualTo(16));
      expect(c.chapter.id, 'chapter_15');
      expect(c.nextLesson.id, 'ch15_microscope');
      await tester.pumpWidget(LearningApp(controller: c));
      await tester.pumpAndSettle();
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('16 · Neural Networks & Backpropagation'),
        160,
        scrollable: find.byType(Scrollable).last,
      );
      await Scrollable.ensureVisible(
        tester.element(
          find.text('16 · Neural Networks & Backpropagation').last,
        ),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.text('16 · Neural Networks & Backpropagation').last,
      );
      await tester.pumpAndSettle();
      expect(c.chapter.id, 'chapter_16');
      expect(find.text('16 · Neural Networks'), findsOneWidget);
      expect(c.answers, isEmpty);
      expect(
        (await rootBundle.load(
          'assets/datasets/wine_quality/neural_workflow.py',
        )).lengthInBytes,
        greaterThan(5000),
      );
      await binding.takeScreenshot('76-chapter-16-home');
      await tester.ensureVisible(find.text('Start learning'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start learning'));
      await tester.pumpAndSettle();
      expect(find.text('Chapter 16 · Lesson 1 of 21'), findsOneWidget);
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
      expect(find.text('Follow one row through the network.'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('forward-final')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('forward-final')));
      await tester.pumpAndSettle();
      expect(find.text('Epoch 120'), findsOneWidget);
      await binding.takeScreenshot('77-chapter-16-forward');
      await tester.scrollUntilVisible(
        find.byKey(const Key('backprop-sum')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('backprop-sum')));
      await tester.pumpAndSettle();
      expect(find.text('Reduction: sum'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('backprop-detach')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('backprop-detach')));
      await tester.pumpAndSettle();
      expect(
        find.text('First-layer gradients: None (disconnected)'),
        findsOneWidget,
      );
      await binding.takeScreenshot('78-chapter-16-backprop');
      await tester.scrollUntilVisible(
        find.byKey(const Key('training-final')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('training-final')));
      await tester.pumpAndSettle();
      expect(find.text('Epoch: 120 / 120'), findsOneWidget);
      await binding.takeScreenshot('79-chapter-16-training');
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
      expect(find.text('24 / 24'), findsOneWidget);
      await binding.takeScreenshot('80-chapter-16-quiz-results');
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
      await tester.enterText(find.byType(TextField).at(1), (-2).toString());
      await tester.ensureVisible(find.text('Check answer').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Check answer').first);
      await tester.pumpAndSettle();
      expect(find.text('ফল মিলেছে'), findsOneWidget);
      await binding.takeScreenshot('81-chapter-16-coding');
      await c.visit('ch16_diagnostics');
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      await repo.close();
      repo = await LearningRepository.open(path: location);
      c = LearningController(repo);
      await c.load();
      expect(c.chapter.id, 'chapter_16');
      expect(c.nextLesson.id, 'ch16_diagnostics');
      expect(c.completedCount, 1);
      expect(c.note('ch16_contract'), contains('inference'));
      expect(c.bookmarked('ch16_contract'), isTrue);
      expect(
        (await repo.exercise('ch16_ex_chain'))?['draft'],
        contains('relu'),
      );
      expect((await repo.exercise('ch16_ex_chain'))?['solved'], 1);
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
