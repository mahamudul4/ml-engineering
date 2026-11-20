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
    'Chapter 24 Android upgrade, source chunks,context packing,citation audit, practice and reopen',
    (tester) async {
      final location = p.join(
        await getDatabasesPath(),
        'ml_rag_integration.db',
      );
      await deleteDatabase(location);
      var repo = await LearningRepository.open(path: location);
      final previous = (await repo.chapters())
          .where((ch) => ch.number <= 23)
          .toList();
      // Simulate an existing twenty-three-chapter learner; never touch the app's main DB.
      await repo.db.delete(
        'chapters',
        where: 'id = ?',
        whereArgs: ['chapter_24'],
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
      await repo.setSetting('selected_chapter', 'chapter_23');
      await repo.setSetting('last_lesson:chapter_23', 'ch23_evaluation');
      await repo.setSetting('theme', 'dark');
      await repo.close();
      repo = await LearningRepository.open(path: location);
      var c = LearningController(repo);
      await c.load();
      expect(c.chapters.length, greaterThanOrEqualTo(24));
      expect(c.chapter.id, 'chapter_23');
      expect(c.nextLesson.id, 'ch23_evaluation');
      await tester.pumpWidget(LearningApp(controller: c));
      await tester.pumpAndSettle();
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('24 · RAG Systems'),
        160,
        scrollable: find.byType(Scrollable).last,
      );
      await Scrollable.ensureVisible(
        tester.element(find.text('24 · RAG Systems').last),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('24 · RAG Systems').last);
      await tester.pumpAndSettle();
      expect(c.chapter.id, 'chapter_24');
      expect(find.text('24 · RAG Systems'), findsOneWidget);
      expect(c.answers, isEmpty);
      expect(
        (await rootBundle.load('assets/datasets/scifact_rag/rag_workflow.py'))
            .lengthInBytes,
        greaterThan(5000),
      );
      await binding.takeScreenshot('124-chapter-24-home');
      await tester.ensureVisible(find.text('Start learning'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start learning'));
      await tester.pumpAndSettle();
      expect(find.text('Chapter 24 · Lesson 1 of 21'), findsOneWidget);
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
      expect(find.text('Keep the boundary. Keep the source.'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('rag-size')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.byKey(const Key('rag-size')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('rag-size')));
      await tester.pumpAndSettle();
      expect(find.text('Chunk size: 3'), findsOneWidget);
      await binding.takeScreenshot('125-chapter-24-chunks');
      await tester.scrollUntilVisible(
        find.byKey(const Key('rag-order')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.byKey(const Key('rag-order')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('rag-order')));
      await tester.pumpAndSettle();
      expect(find.text('Ranking: document order'), findsOneWidget);
      await binding.takeScreenshot('126-chapter-24-pipeline');
      await tester.scrollUntilVisible(
        find.byKey(const Key('rag-tamper')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.byKey(const Key('rag-tamper')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('rag-tamper')));
      await tester.pumpAndSettle();
      expect(find.text('Audit: quote mismatch'), findsOneWidget);
      await binding.takeScreenshot('127-chapter-24-audit');
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
      await binding.takeScreenshot('128-chapter-24-quiz-results');
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
      await tester.enterText(find.byType(TextField).at(1), 3200.toString());
      await tester.ensureVisible(find.text('Check answer').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Check answer').first);
      await tester.pumpAndSettle();
      expect(find.text('ফল মিলেছে'), findsOneWidget);
      await binding.takeScreenshot('129-chapter-24-coding');
      await c.visit('ch24_evaluation');
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      await repo.close();
      repo = await LearningRepository.open(path: location);
      c = LearningController(repo);
      await c.load();
      expect(c.chapter.id, 'chapter_24');
      expect(c.nextLesson.id, 'ch24_evaluation');
      expect(c.completedCount, 1);
      expect(c.note('ch24_contract'), contains('inference'));
      expect(c.bookmarked('ch24_contract'), isTrue);
      expect(
        (await repo.exercise('ch24_ex_budget'))?['draft'],
        contains('available'),
      );
      expect((await repo.exercise('ch24_ex_budget'))?['solved'], 1);
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
