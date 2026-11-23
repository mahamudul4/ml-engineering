import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/data/learning_repository.dart';
import 'package:ml_path/features/reinforcement/bellman_model.dart';
import 'package:ml_path/models/book_part.dart';
import 'package:ml_path/state/learning_controller.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test(
    'reading path is complete, topological and keeps permanent IDs',
    () async {
      final repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      final c = LearningController(repo);
      addTearDown(c.dispose);
      addTearDown(repo.close);
      await c.load();
      expect(c.chapters.length, 51);
      final path = c.readingPath;
      expect(path.take(8).map((ch) => ch.number), [1, 6, 7, 8, 4, 2, 3, 5]);
      expect(path.map((ch) => ch.id).toSet().length, 51);
      expect(path.map((ch) => ch.book.order), List.generate(51, (i) => i + 1));
      expect(path.skip(27).take(4).map((ch) => ch.number), [26, 42, 43, 27]);
      expect(BookPart.values.length, 6);
      for (final book in BookPart.values) {
        final bookChapters = c.chaptersForBook(book);
        expect(bookChapters.length, book.chapterCount, reason: book.id);
        expect(
          bookChapters.map((ch) => ch.bookChapterNumber),
          List.generate(book.chapterCount, (i) => i + 1),
          reason: '${book.id} chapters must start at Chapter 1',
        );
      }
      final seen = <String>{};
      for (final chapter in path) {
        final parts = BookPart.values.where(
          (part) => part.containsStep(chapter.book.order),
        );
        expect(parts, hasLength(1), reason: chapter.id);
        expect(chapter.book.part, parts.single.label);
        expect(chapter.book.purpose, isNotEmpty);
        expect(chapter.book.outcomes.length, greaterThanOrEqualTo(2));
        expect(chapter.book.recall.length, greaterThanOrEqualTo(2));
        for (final id in chapter.book.prerequisites) {
          expect(seen, contains(id), reason: '${chapter.id} needs $id first');
        }
        seen.add(chapter.id);
      }
      expect(c.previousChapter, isNull);
      expect(c.nextChapter!.number, 6);
      // Test multi-book switching and per-book chapter resume
      await c.selectBook(BookPart.classical);
      expect(c.chapter.id, 'chapter_02');
      expect(c.chapter.bookChapterNumber, 1);
      await c.selectChapter('chapter_09');
      expect(c.chapter.bookChapterNumber, 4);
      await c.selectBook(BookPart.llm);
      expect(c.chapter.id, 'chapter_22');
      expect(c.chapter.bookChapterNumber, 1);
      await c.selectChapter('chapter_24');
      expect(c.chapter.bookChapterNumber, 3);
      await c.selectBook(BookPart.recommender);
      expect(c.chapter.id, 'chapter_30');
      expect(c.chapter.bookChapterNumber, 1);
      await c.selectBook(BookPart.classical);
      expect(c.chapter.id, 'chapter_09');
      await c.selectBook(BookPart.llm);
      expect(c.chapter.id, 'chapter_24');
      await c.selectChapter('chapter_21');
      expect(c.nextChapter!.number, 41);
      expect(c.nextChapterInBook!.number, 41);
      await c.selectChapter('chapter_41');
      expect(c.nextChapter!.number, 44);
      expect(c.nextChapterInBook!.number, 44);
      await c.selectChapter('chapter_44');
      expect(c.nextChapter!.number, 22);
      expect(c.nextChapterInBook, isNull);
      await c.selectChapter('chapter_46');
      expect(c.nextChapter!.number, 51);
      expect(c.nextChapterInBook!.number, 51);
      await c.selectChapter('chapter_51');
      expect(c.nextChapter!.number, 30);
      expect(c.nextChapterInBook, isNull);
      await c.selectChapter('chapter_40');
      expect(c.nextChapter!.number, 48);
      expect(c.previousChapter!.number, 39);
      await c.selectChapter('chapter_50');
      expect(c.nextChapter, isNull);
      expect(c.previousChapter!.number, 49);
    },
  );

  test(
    'all forty chapters gain targeted lessons and RL is fully registered',
    () async {
      final repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      addTearDown(repo.close);
      final chapters = await repo.chapters();
      var additions = 0;
      for (final chapter in chapters.take(40)) {
        final lessons = chapter.lessons
            .where((lesson) => lesson.id.contains('_book_'))
            .toList();
        expect(lessons, isNotEmpty, reason: chapter.id);
        additions += lessons.length;
        for (final lesson in lessons) {
          expect(lesson.blocks.length, greaterThanOrEqualTo(8));
          expect(lesson.blocks.where((b) => b.type == 'math'), isNotEmpty);
          expect(lesson.blocks.where((b) => b.type == 'code'), isNotEmpty);
          for (final block in lesson.blocks.where((b) => b.type == 'code')) {
            expect(block.body.trim(), isNotEmpty);
          }
          expect(lesson.blocks.last.type, 'checkpoint');
          expect(lesson.blocks.last.solution, isNotEmpty);
        }
      }
      expect(additions, 46);
      final rl = chapters.singleWhere((chapter) => chapter.number == 41);
      expect(rl.id, 'chapter_41');
      expect(rl.lessons.length, 17);
      expect(rl.quizzes.length, 20);
      expect(rl.exercises.length, 10);
      expect(rl.interviews.length, 10);
      final readingStepByLesson = {
        for (final chapter in chapters)
          for (final lesson in chapter.lessons) lesson.id: chapter.book.order,
      };
      for (final interview in rl.interviews) {
        for (final lessonId in interview.prerequisiteLessons) {
          expect(
            readingStepByLesson[lessonId],
            lessThanOrEqualTo(rl.book.order),
            reason: '${interview.title} requires a later reading step',
          );
        }
      }
      expect(
        chapters.fold<int>(0, (sum, chapter) => sum + chapter.lessons.length),
        890,
      );
    },
  );

  test('reseed preserves notes, answers, drafts and resume across all prior chapters', () async {
    final temp = await Directory.systemTemp.createTemp('ml_book_upgrade_');
    addTearDown(() => temp.delete(recursive: true));
    final path = '${temp.path}/learning.db';
    var repo = await LearningRepository.open(
      factory: databaseFactoryFfi,
      path: path,
    );
    final originals = (await repo.chapters())
        .where((ch) => ch.number <= 41)
        .toList();
    for (final chapter in originals) {
      final lesson = chapter.lessons.first;
      await repo.updateLesson(
        lesson.id,
        completed: true,
        bookmarked: true,
        note: 'নিজের note ${chapter.number}',
      );
      await repo.answer(chapter.quizzes.first.id, chapter.quizzes.first.answer);
      await repo.saveExercise(
        chapter.exercises.first.id,
        'original draft ${chapter.number}',
        true,
      );
      await repo.setSetting('last_lesson:${chapter.id}', lesson.id);
    }
    await repo.setSetting('selected_chapter', 'chapter_07');
    await repo.setSetting('theme', 'dark');
    await repo.db.delete(
      'chapters',
      where: 'id IN (?, ?)',
      whereArgs: ['chapter_42', 'chapter_43'],
    );
    await repo.close();
    // Opening installs revised curriculum content; it must never replace state.
    repo = await LearningRepository.open(
      factory: databaseFactoryFfi,
      path: path,
    );
    final c = LearningController(repo);
    addTearDown(c.dispose);
    addTearDown(repo.close);
    await c.load();
    expect(c.chapter.id, 'chapter_07');
    expect(
      c.chapters
          .where((chapter) => chapter.number >= 42)
          .map((chapter) => chapter.lessons.length),
      [9, 6, 9, 9, 9, 9, 8, 8, 8, 10],
    );
    for (final original in originals) {
      await c.selectChapter(original.id);
      final id = original.lessons.first.id;
      expect(c.note(id), 'নিজের note ${original.number}');
      expect(c.completed(id), isTrue);
      expect(c.bookmarked(id), isTrue);
      expect(c.lastLesson, id);
      expect(c.score, 1);
      expect(
        (await repo.exercise(original.exercises.first.id))!['draft'],
        'original draft ${original.number}',
      );
      for (final addition in c.chapter.lessons.where(
        (lesson) => lesson.id.contains('_book_'),
      )) {
        expect(c.completed(addition.id), isFalse);
      }
    }
  });

  test('Bellman synchronous values, terminal and input contracts', () {
    final model = BellmanModel();
    final first = model.sweep([0, 0, 0]);
    expect(first[0], 1);
    expect(first[1], closeTo(2.5, 1e-12));
    final second = model.sweep(first);
    expect(second[0], closeTo(2.25, 1e-12));
    expect(second[1], closeTo(2.77, 1e-12));
    expect(second[2], 0);
    expect(() => model.sweep([1, 2]), throwsArgumentError);
    expect(() => model.sweep([double.nan, 2, 0]), throwsArgumentError);
    expect(() => model.actionValues([0, 0, 0], 3), throwsRangeError);
    expect(() => BellmanModel(discount: 1), throwsArgumentError);
    expect(() => BellmanModel(discount: double.nan), throwsArgumentError);
    expect(() => BellmanModel(successProbability: -1), throwsArgumentError);
  });

  for (final gamma in [0.0, .5, .9, .99]) {
    for (final p in [0.0, .3, .7, 1.0]) {
      test(
        'Bellman converges to independent policy enumeration gamma=$gamma p=$p',
        () {
          final model = BellmanModel(discount: gamma, successProbability: p);
          final reward = 5 * p - 1;
          final retryMiddle = reward / (1 - (1 - p) * gamma * gamma);
          // Solve all four deterministic policies analytically, without max backups.
          final policies = [
            [1.0, 1.0],
            [1.0, reward + (1 - p) * gamma],
            [gamma, 1.0],
            [gamma * retryMiddle, retryMiddle],
          ];
          final optimum = [
            for (var state = 0; state < 2; state++)
              policies.map((values) => values[state]).reduce(math.max),
          ];
          var values = [0.0, 0.0, 0.0];
          for (var step = 0; step < 1000; step++) {
            final next = model.sweep(values);
            final bound = model.errorBound(model.change(values, next));
            for (var state = 0; state < 2; state++) {
              expect(
                (next[state] - optimum[state]).abs(),
                lessThanOrEqualTo(bound + 1e-10),
              );
            }
            values = next;
          }
          expect(values[0], closeTo(optimum[0], 1e-9));
          expect(values[1], closeTo(optimum[1], 1e-9));
          expect(values[2], 0);
        },
      );
    }
  }
}
