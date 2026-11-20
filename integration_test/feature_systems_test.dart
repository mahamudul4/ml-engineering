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
    'Chapter 35 Android upgrade, workbench,scorecard,source audit, practice and reopen',
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
        'ml_feature_systems_integration.db',
      );
      await deleteDatabase(location);
      var repo = await LearningRepository.open(path: location);
      final previous = (await repo.chapters())
          .where((ch) => ch.number <= 34)
          .toList();
      // Simulate an existing thirty-four-chapter learner; never touch the app's main DB.
      await repo.db.delete(
        'chapters',
        where: 'id = ?',
        whereArgs: ['chapter_35'],
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
      await repo.setSetting('selected_chapter', 'chapter_34');
      await repo.setSetting('last_lesson:chapter_34', 'ch34_evaluation');
      await repo.setSetting('theme', 'dark');
      await repo.close();
      repo = await LearningRepository.open(path: location);
      var c = LearningController(repo);
      await c.load();
      expect(c.chapters.length, greaterThanOrEqualTo(35));
      expect(c.chapter.id, 'chapter_34');
      expect(c.nextLesson.id, 'ch34_evaluation');
      await tester.pumpWidget(LearningApp(controller: c));
      await tester.pumpAndSettle();
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('35 · ML Data Pipelines & Feature Systems'),
        160,
        scrollable: find.byType(Scrollable).last,
      );
      await Scrollable.ensureVisible(
        tester.element(
          find.text('35 · ML Data Pipelines & Feature Systems').last,
        ),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.text('35 · ML Data Pipelines & Feature Systems').last,
      );
      await tester.pumpAndSettle();
      expect(c.chapter.id, 'chapter_35');
      expect(find.text('35 · Data Pipelines & Features'), findsOneWidget);
      expect(c.answers, isEmpty);
      expect(
        (await rootBundle.load(
          'assets/datasets/bike_sharing/pipeline_workflow.py',
        )).lengthInBytes,
        greaterThan(5000),
      );
      await binding.takeScreenshot('190-chapter-35-home');
      await tester.ensureVisible(find.text('Start learning'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start learning'));
      await tester.pumpAndSettle();
      expect(find.text('Chapter 35 · Lesson 1 of 21'), findsOneWidget);
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
            c.note('ch35_contract').contains('inference'),
      );
      await tester.tap(find.byTooltip('Bookmark lesson'));
      await waitFor(() => c.bookmarked('ch35_contract'));
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
      await waitFor(() => c.completed('ch35_contract'));
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lab'));
      await tester.pumpAndSettle();
      expect(find.text('Ask what was available then.'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('feature-latest')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.byKey(const Key('feature-latest')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('feature-latest')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Lookup: LATEST'), findsOneWidget);
      await binding.takeScreenshot('191-chapter-35-point-in-time');
      await tester.scrollUntilVisible(
        find.byKey(const Key('pipeline-duplicates')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.byKey(const Key('pipeline-duplicates')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pipeline-duplicates')));
      await tester.pumpAndSettle();
      expect(find.textContaining('duplicate no-ops 547'), findsOneWidget);
      await binding.takeScreenshot('192-chapter-35-replay');
      await tester.scrollUntilVisible(
        find.byKey(const Key('feature-serving-latest')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(
        find.byKey(const Key('feature-serving-latest')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('feature-serving-latest')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Consistency: SKEW'), findsOneWidget);
      await binding.takeScreenshot('193-chapter-35-consistency');
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
      await binding.takeScreenshot('194-chapter-35-quiz-results');
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
      await binding.takeScreenshot('195-chapter-35-coding');
      await c.visit('ch35_evaluation');
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      await repo.close();
      repo = await LearningRepository.open(path: location);
      c = LearningController(repo);
      await c.load();
      expect(c.chapter.id, 'chapter_35');
      expect(c.nextLesson.id, 'ch35_evaluation');
      expect(c.completedCount, 1);
      expect(c.note('ch35_contract'), contains('inference'));
      expect(c.bookmarked('ch35_contract'), isTrue);
      expect(
        (await repo.exercise('ch35_ex_mean'))?['draft'],
        contains('eligible'),
      );
      expect((await repo.exercise('ch35_ex_mean'))?['solved'], 1);
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
