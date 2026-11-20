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
    'Chapter 32 Android upgrade, workbench,scorecard,source audit, practice and reopen',
    (tester) async {
      Future<void> waitFor(bool Function() ready) async {
        for (var i = 0; i < 100 && !ready(); i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(ready(), isTrue);
        await tester.pumpAndSettle();
      }

      final location = p.join(
        await getDatabasesPath(),
        'ml_deep_recommendation_integration.db',
      );
      await deleteDatabase(location);
      var repo = await LearningRepository.open(path: location);
      final previous = (await repo.chapters())
          .where((ch) => ch.number <= 31)
          .toList();
      // Simulate an existing thirty-one-chapter learner; never touch the app's main DB.
      await repo.db.delete(
        'chapters',
        where: 'id = ?',
        whereArgs: ['chapter_32'],
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
      await repo.setSetting('selected_chapter', 'chapter_31');
      await repo.setSetting('last_lesson:chapter_31', 'ch31_evaluation');
      await repo.setSetting('theme', 'dark');
      await repo.close();
      repo = await LearningRepository.open(path: location);
      var c = LearningController(repo);
      await c.load();
      expect(c.chapters.length, greaterThanOrEqualTo(32));
      expect(c.chapter.id, 'chapter_31');
      expect(c.nextLesson.id, 'ch31_evaluation');
      await tester.pumpWidget(LearningApp(controller: c));
      await tester.pumpAndSettle();
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('32 · Deep Recommendation & Ranking'),
        160,
        scrollable: find.byType(Scrollable).last,
      );
      await Scrollable.ensureVisible(
        tester.element(find.text('32 · Deep Recommendation & Ranking').last),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('32 · Deep Recommendation & Ranking').last);
      await tester.pumpAndSettle();
      expect(c.chapter.id, 'chapter_32');
      expect(find.text('32 · Deep Recommendation'), findsOneWidget);
      expect(c.answers, isEmpty);
      expect(
        (await rootBundle.load(
          'assets/datasets/movielens/deep_recommendation_workflow.py',
        )).lengthInBytes,
        greaterThan(5000),
      );
      await binding.takeScreenshot('172-chapter-32-home');
      await tester.ensureVisible(find.text('Start learning'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start learning'));
      await tester.pumpAndSettle();
      expect(find.text('Chapter 32 · Lesson 1 of 23'), findsOneWidget);
      await tester.tap(find.byTooltip('Write a note'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('note-field')),
        'Probability ও inference assumptions আগে লিখব।',
      );
      await tester.tap(find.text('Save note'));
      await waitFor(
        () =>
            find.byKey(const Key('note-field')).evaluate().isEmpty &&
            c.note('ch32_contract').contains('inference'),
      );
      await tester.tap(find.byTooltip('Bookmark lesson'));
      await waitFor(() => c.bookmarked('ch32_contract'));
      await tester.scrollUntilVisible(
        find.text('Mark lesson complete'),
        450,
        scrollable: find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            )
            .first,
      );
      await tester.tap(find.text('Mark lesson complete'));
      await waitFor(() => c.completed('ch32_contract'));
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lab'));
      await tester.pumpAndSettle();
      expect(
        find.text('Retrieve candidates. Rank the shortlist.'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('deep-budget-100')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.byKey(const Key('deep-budget-100')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('deep-budget-100')));
      await tester.pumpAndSettle();
      expect(find.text('Neural budget: 100'), findsOneWidget);
      await binding.takeScreenshot('173-chapter-32-retrieval');
      await tester.scrollUntilVisible(
        find.byKey(const Key('deep-temperature-1.0')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.byKey(const Key('deep-temperature-1.0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('deep-temperature-1.0')));
      await tester.pumpAndSettle();
      expect(find.text('Temperature: 1.0'), findsOneWidget);
      await binding.takeScreenshot('174-chapter-32-batch');
      await tester.scrollUntilVisible(
        find.byKey(const Key('deep-neutral')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.byKey(const Key('deep-neutral')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('deep-neutral')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('deep-cohort')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.byKey(const Key('deep-cohort')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('deep-cohort')));
      await tester.pumpAndSettle();
      expect(
        find.text('Cohort: all future-positive users / all positives'),
        findsOneWidget,
      );
      await binding.takeScreenshot('175-chapter-32-audit');
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
        await waitFor(() => c.answers.containsKey(question.id));
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
      await binding.takeScreenshot('176-chapter-32-quiz-results');
      await tester.ensureVisible(find.text('Try again'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Try again'));
      await waitFor(() => c.answers.isEmpty);
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
      await tester.enterText(
        find.byType(TextField).at(1),
        c.chapter.exercises.first.expected.toString(),
      );
      await tester.ensureVisible(find.text('Check answer').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Check answer').first);
      await waitFor(() => find.text('ফল মিলেছে').evaluate().isNotEmpty);
      expect(find.text('ফল মিলেছে'), findsOneWidget);
      await binding.takeScreenshot('177-chapter-32-coding');
      await c.visit('ch32_evaluation');
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      await repo.close();
      repo = await LearningRepository.open(path: location);
      c = LearningController(repo);
      await c.load();
      expect(c.chapter.id, 'chapter_32');
      expect(c.nextLesson.id, 'ch32_evaluation');
      expect(c.completedCount, 1);
      expect(c.note('ch32_contract'), contains('inference'));
      expect(c.bookmarked('ch32_contract'), isTrue);
      expect(
        (await repo.exercise('ch32_ex_dot'))?['draft'],
        contains('products'),
      );
      expect((await repo.exercise('ch32_ex_dot'))?['solved'], 1);
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
