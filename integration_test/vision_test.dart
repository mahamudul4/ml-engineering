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
    'Chapter 18 Android upgrade, convolution, pooling, transfer, practice and reopen',
    (tester) async {
      final location = p.join(
        await getDatabasesPath(),
        'ml_vision_integration.db',
      );
      await deleteDatabase(location);
      var repo = await LearningRepository.open(path: location);
      final previous = (await repo.chapters())
          .where((ch) => ch.number <= 17)
          .toList();
      // Simulate an existing seventeen-chapter learner; never touch the app's main DB.
      await repo.db.delete(
        'chapters',
        where: 'id = ?',
        whereArgs: ['chapter_18'],
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
      await repo.setSetting('selected_chapter', 'chapter_17');
      await repo.setSetting('last_lesson:chapter_17', 'ch17_resume');
      await repo.setSetting('theme', 'dark');
      await repo.close();
      repo = await LearningRepository.open(path: location);
      var c = LearningController(repo);
      await c.load();
      expect(c.chapters.length, greaterThanOrEqualTo(18));
      expect(c.chapter.id, 'chapter_17');
      expect(c.nextLesson.id, 'ch17_resume');
      await tester.pumpWidget(LearningApp(controller: c));
      await tester.pumpAndSettle();
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('18 · CNNs, Computer Vision & Transfer Learning'),
        160,
        scrollable: find.byType(Scrollable).last,
      );
      await Scrollable.ensureVisible(
        tester.element(
          find.text('18 · CNNs, Computer Vision & Transfer Learning').last,
        ),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.text('18 · CNNs, Computer Vision & Transfer Learning').last,
      );
      await tester.pumpAndSettle();
      expect(c.chapter.id, 'chapter_18');
      expect(find.text('18 · CNNs & Vision'), findsOneWidget);
      expect(c.answers, isEmpty);
      expect(
        (await rootBundle.load('assets/datasets/digits/vision_workflow.py'))
            .lengthInBytes,
        greaterThan(5000),
      );
      await binding.takeScreenshot('88-chapter-18-home');
      await tester.ensureVisible(find.text('Start learning'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start learning'));
      await tester.pumpAndSettle();
      expect(find.text('Chapter 18 · Lesson 1 of 21'), findsOneWidget);
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
      expect(
        find.text('Slide the kernel. Account for every value.'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('conv-stride')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('conv-stride')));
      await tester.pumpAndSettle();
      expect(find.text('Output shape: [4, 4]'), findsOneWidget);
      await binding.takeScreenshot('89-chapter-18-convolution');
      await tester.scrollUntilVisible(
        find.byKey(const Key('pool-inspect-shift')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('pool-inspect-shift')));
      await tester.pumpAndSettle();
      expect(find.text('Shift: right 1'), findsOneWidget);
      await binding.takeScreenshot('90-chapter-18-pooling');
      await tester.scrollUntilVisible(
        find.byKey(const Key('transfer-finetune')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('transfer-finetune')));
      await tester.pumpAndSettle();
      expect(find.text('Branch: finetune'), findsOneWidget);
      await binding.takeScreenshot('91-chapter-18-transfer');
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
      await binding.takeScreenshot('92-chapter-18-quiz-results');
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
      await tester.enterText(find.byType(TextField).at(1), (-4).toString());
      await tester.ensureVisible(find.text('Check answer').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Check answer').first);
      await tester.pumpAndSettle();
      expect(find.text('ফল মিলেছে'), findsOneWidget);
      await binding.takeScreenshot('93-chapter-18-coding');
      await c.visit('ch18_transfer');
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      await repo.close();
      repo = await LearningRepository.open(path: location);
      c = LearningController(repo);
      await c.load();
      expect(c.chapter.id, 'chapter_18');
      expect(c.nextLesson.id, 'ch18_transfer');
      expect(c.completedCount, 1);
      expect(c.note('ch18_contract'), contains('inference'));
      expect(c.bookmarked('ch18_contract'), isTrue);
      expect(
        (await repo.exercise('ch18_ex_window'))?['draft'],
        contains('conv2d'),
      );
      expect((await repo.exercise('ch18_ex_window'))?['solved'], 1);
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
