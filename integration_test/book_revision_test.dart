import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ml_path/data/learning_repository.dart';
import 'package:ml_path/features/lessons/lesson_page.dart';
import 'package:ml_path/main.dart';
import 'package:ml_path/state/learning_controller.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'book revision preserves forty chapters and connects search, math, RL and practice',
    (tester) async {
      Future<void> ready(bool Function() condition) async {
        for (var i = 0; i < 100 && !condition(); i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(condition(), isTrue);
        await tester.pumpAndSettle();
      }

      Future<void> tap(Finder finder) async {
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await Scrollable.ensureVisible(
          tester.element(finder.first),
          alignment: .5,
        );
        await tester.pumpAndSettle();
        await tester.tap(finder.first);
        await tester.pumpAndSettle();
      }

      final path = p.join(
        await getDatabasesPath(),
        'ml_book_revision_integration.db',
      );
      await deleteDatabase(path); // Dedicated QA fixture, never ml_path.db.
      var repo = await LearningRepository.open(path: path);
      final originals = (await repo.chapters())
          .where((chapter) => chapter.number <= 40)
          .toList();
      for (final chapter in originals) {
        await repo.updateLesson(
          chapter.lessons.first.id,
          completed: true,
          bookmarked: true,
          note: 'Saved ${chapter.number}',
        );
        await repo.answer(
          chapter.quizzes.first.id,
          chapter.quizzes.first.answer,
        );
        await repo.saveExercise(
          chapter.exercises.first.id,
          'Draft ${chapter.number}',
          true,
        );
        // Simulate pre-revision content as well as pre-revision learner records.
        final stored = await repo.db.query(
          'chapters',
          where: 'id = ?',
          whereArgs: [chapter.id],
        );
        final content = jsonDecode(
          stored.single['content'] as String,
        ) as Map<String, dynamic>;
        content.remove('book');
        (content['lessons'] as List).removeWhere(
          (dynamic lesson) => (lesson['id'] as String).contains('_book_'),
        );
        await repo.db.update(
          'chapters',
          {'content': jsonEncode(content)},
          where: 'id = ?',
          whereArgs: [chapter.id],
        );
      }
      await repo.db.delete(
        'chapters',
        where: 'id = ?',
        whereArgs: ['chapter_41'],
      );
      await repo.close();
      repo = await LearningRepository.open(path: path);
      var c = LearningController(repo);
      await c.load();
      expect(c.chapters.length, 43);
      expect(
        c.chapters.fold<int>(
          0,
          (total, chapter) => total + chapter.quizzes.length,
        ),
        1010,
      );
      expect(
        c.chapters.fold<int>(
          0,
          (total, chapter) => total + chapter.exercises.length,
        ),
        394,
      );
      final reinforcement = c.chapters.singleWhere(
        (chapter) => chapter.id == 'chapter_41',
      );
      expect(reinforcement.quizzes.length, 20);
      expect(reinforcement.exercises.length, 10);
      expect(
        reinforcement.exercises.any(
          (exercise) => exercise.id == 'ch41_e_discounted_gradient_revision',
        ),
        isTrue,
      );
      expect(c.readingPath.take(4).map((chapter) => chapter.number), [
        1,
        6,
        7,
        8,
      ]);
      await tester.pumpWidget(LearningApp(controller: c));
      await tester.pumpAndSettle();
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await binding.takeScreenshot('230-book-home');
      await tap(find.byKey(const ValueKey('open-book')));
      await tester.enterText(
        find.byKey(const ValueKey('book-search')),
        'Poisson',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tap(find.byKey(const ValueKey('book-chapter_02')));
      await binding.takeScreenshot('231-book-search');
      await tap(find.text('Beyond squared loss: GLM ও Poisson Regression'));
      await ready(() => c.chapter.number == 2);
      expect(find.byType(LessonPage), findsOneWidget);
      await binding.takeScreenshot('232-book-glm');
      await tap(find.text('চেষ্টা শেষে উত্তর দেখুন'));
      await binding.takeScreenshot('233-book-checkpoint');
      await tap(find.text('Mark lesson complete'));
      await ready(() => c.completed('ch02_book_glm'));
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tap(find.byType(DropdownButtonFormField<String>));
      await tester.scrollUntilVisible(
        find.text('41 · Reinforcement Learning & Bandits'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tap(find.text('41 · Reinforcement Learning & Bandits').last);
      await ready(() => c.chapter.number == 41);
      await tap(find.text('Lab'));
      await tap(find.text('Next Bellman sweep'));
      await tap(find.text('Next Bellman sweep'));
      expect(find.text('Start · V = 2.250000'), findsOneWidget);
      expect(find.text('Middle · V = 2.770000'), findsOneWidget);
      await binding.takeScreenshot('234-book-bellman');
      await tap(find.byTooltip('Toggle light / dark mode'));
      await ready(() => c.themeMode == ThemeMode.dark);
      await binding.takeScreenshot('235-book-bellman-dark');
      await tap(find.text('Learn'));
      await tap(find.byKey(const ValueKey('open-book')));
      await tester.enterText(
        find.byKey(const ValueKey('book-search')),
        'Bellman',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tap(find.byKey(const ValueKey('book-chapter_41')));
      await binding.takeScreenshot('237-book-dark-path');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tap(find.text('Practice'));
      await tap(find.text('Start knowledge check'));
      await tap(find.text(c.chapter.quizzes.first.options.first));
      await ready(() => c.score == 1);
      await binding.takeScreenshot('236-book-rl-quiz');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      await repo.close();
      repo = await LearningRepository.open(path: path);
      c = LearningController(repo);
      await c.load();
      expect(c.chapter.number, 41);
      expect(c.score, 1);
      expect(c.completed('ch02_book_glm'), isTrue);
      expect(c.themeMode, ThemeMode.dark);
      for (final chapter in originals) {
        await c.selectChapter(chapter.id);
        expect(c.completed(chapter.lessons.first.id), isTrue);
        expect(c.bookmarked(chapter.lessons.first.id), isTrue);
        expect(c.note(chapter.lessons.first.id), 'Saved ${chapter.number}');
        expect(c.score, 1);
        expect(
          (await repo.exercise(chapter.exercises.first.id))!['draft'],
          'Draft ${chapter.number}',
        );
      }
      expect(tester.takeException(), isNull);
      c.dispose();
      await repo.close();
      await deleteDatabase(path);
    },
  );
}
