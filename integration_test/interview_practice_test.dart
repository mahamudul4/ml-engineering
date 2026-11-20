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
    'Chapter 39 Android upgrade,Top-K,SQLite,debugging,practice and reopen',
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
        'ml_interview_practice_integration.db',
      );
      await deleteDatabase(location);
      var repo = await LearningRepository.open(path: location);
      final previous = (await repo.chapters())
          .where((ch) => ch.number <= 38)
          .toList();
      // Simulate an existing thirty-eight-chapter learner; never touch the app's main DB.
      await repo.db.delete(
        'chapters',
        where: 'id = ?',
        whereArgs: ['chapter_39'],
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
      await repo.setSetting('selected_chapter', 'chapter_38');
      await repo.setSetting('last_lesson:chapter_38', 'ch38_evaluation');
      await repo.setSetting('theme', 'dark');
      await repo.close();
      repo = await LearningRepository.open(path: location);
      var c = LearningController(repo);
      await c.load();
      expect(c.chapters.length, greaterThanOrEqualTo(39));
      expect(c.chapter.id, 'chapter_38');
      expect(c.nextLesson.id, 'ch38_evaluation');
      await tester.pumpWidget(LearningApp(controller: c));
      await tester.pumpAndSettle();
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('39 · Technical Interview Practice'),
        160,
        scrollable: find.byType(Scrollable).last,
      );
      await Scrollable.ensureVisible(
        tester.element(find.text('39 · Technical Interview Practice').last),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('39 · Technical Interview Practice').last);
      await tester.pumpAndSettle();
      expect(c.chapter.id, 'chapter_39');
      expect(find.text('39 · Interview Practice'), findsOneWidget);
      expect(c.answers, isEmpty);
      expect(
        (await rootBundle.load(
          'assets/datasets/interview_practice/interview_workflow.py',
        )).lengthInBytes,
        greaterThan(5000),
      );
      await binding.takeScreenshot('214-chapter-39-home');
      await tester.ensureVisible(find.text('Start learning'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start learning'));
      await tester.pumpAndSettle();
      expect(find.text('Chapter 39 · Lesson 1 of 31'), findsOneWidget);
      await tester.tap(find.byTooltip('Write a note'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('note-field')),
        'Contract ও heap invariant আগে লিখব।',
      );
      await tester.tap(find.text('Save note'));
      await waitFor(
        () =>
            find.byKey(const Key('note-field')).evaluate().isEmpty &&
            c.note('ch39_contract').contains('invariant'),
      );
      await tester.tap(find.byTooltip('Bookmark lesson'));
      await waitFor(() => c.bookmarked('ch39_contract'));
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
      await waitFor(() => c.completed('ch39_contract'));
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lab'));
      await tester.pumpAndSettle();
      expect(find.text('State the invariant. Then select.'), findsOneWidget);
      Future<void> tapLab(Finder f) async {
        await tester.scrollUntilVisible(
          f,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(f);
        await tester.pumpAndSettle();
        await tester.tap(f);
        await tester.pumpAndSettle();
      }

      await tapLab(find.byKey(const Key('topk-method-merge')));
      expect(find.textContaining('Eligible movies: 1918'), findsOneWidget);
      await binding.takeScreenshot('215-chapter-39-topk');
      await tapLab(find.byKey(const Key('sql-variant-fanout')));
      for (
        var i = 0;
        i < 100 &&
            find.textContaining('Ratings counted: 217203').evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.textContaining('Ratings counted: 217203'), findsOneWidget);
      await tester.ensureVisible(
        find.textContaining('Ratings counted: 217203'),
      );
      await tester.pumpAndSettle();
      await binding.takeScreenshot('216-chapter-39-sql');
      await tapLab(find.byKey(const Key('debug-bug-precision_swap')));
      expect(find.textContaining('Contract check: FAIL'), findsOneWidget);
      await tester.ensureVisible(find.textContaining('Contract check: FAIL'));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('217-chapter-39-debug');
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
      expect(find.text('32 / 32'), findsOneWidget);
      await binding.takeScreenshot('218-chapter-39-quiz-results');
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
      await binding.takeScreenshot('219-chapter-39-coding');
      await c.visit('ch39_communication');
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      await repo.close();
      repo = await LearningRepository.open(path: location);
      c = LearningController(repo);
      await c.load();
      expect(c.chapter.id, 'chapter_39');
      expect(c.nextLesson.id, 'ch39_communication');
      expect(c.completedCount, 1);
      expect(c.note('ch39_contract'), contains('invariant'));
      expect(c.bookmarked('ch39_contract'), isTrue);
      expect(
        (await repo.exercise('ch39_ex_topk'))?['draft'],
        contains('heapq'),
      );
      expect((await repo.exercise('ch39_ex_topk'))?['solved'], 1);
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
