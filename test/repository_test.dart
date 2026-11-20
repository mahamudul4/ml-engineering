import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/data/learning_repository.dart';
import 'package:ml_path/state/learning_controller.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late LearningRepository repo;
  late Directory temp;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('ml_path_test_');
    repo = await LearningRepository.open(
      factory: databaseFactoryFfi,
      path: '${temp.path}/learning.db',
    );
  });
  tearDown(() async {
    await repo.close();
    await temp.delete(recursive: true);
  });
  test('catalog seeds the forty-three revised chapters', () async {
    final chapter = await repo.curriculum();
    expect((await repo.db.query('chapters')).length, 50);
    expect(chapter.id, 'chapter_01');
    expect(chapter.lessons.length, 8);
    expect(chapter.quizzes.length, 10);
    expect(chapter.interviews.length, 5);
    expect(chapter.exercises.length, 2);
    expect(chapter.lessons.map((l) => l.id).toSet().length, 8);
    for (final l in chapter.lessons) {
      expect(l.blocks.length, greaterThanOrEqualTo(5));
    }
    for (final q in chapter.quizzes) {
      expect(q.answer, inInclusiveRange(0, q.options.length - 1));
      expect(q.explanation, isNotEmpty);
    }
    final second = await repo.curriculum(id: 'chapter_02');
    expect(second.number, 2);
    expect(second.lessons.length, 14);
    expect(second.quizzes.length, 16);
    expect(second.interviews.length, 9);
    expect(second.exercises.length, 7);
    final third = await repo.curriculum(id: 'chapter_03');
    expect(third.number, 3);
    expect(third.lessons.length, 9);
    expect(third.quizzes.length, 12);
    expect(third.interviews.length, 5);
    expect(third.exercises.length, 3);
    final fourth = await repo.curriculum(id: 'chapter_04');
    expect(fourth.number, 4);
    expect(fourth.lessons.length, 13);
    expect(fourth.quizzes.length, 16);
    expect(fourth.interviews.length, 8);
    expect(fourth.exercises.length, 6);
    for (final l in fourth.lessons) {
      expect(l.blocks.length, greaterThanOrEqualTo(7));
    }
    for (final q in fourth.quizzes) {
      expect(q.answer, inInclusiveRange(0, q.options.length - 1));
      expect(q.explanation, isNotEmpty);
    }
    final chapters = await repo.chapters();
    final fifth = chapters[4];
    expect(fifth.id, 'chapter_05');
    expect(fifth.lessons.length, 15);
    expect(fifth.quizzes.length, 18);
    expect(fifth.interviews.length, 8);
    expect(fifth.exercises.length, 7);
    for (final lesson in fifth.lessons) {
      expect(lesson.blocks.length, greaterThanOrEqualTo(8));
    }
    for (final q in fifth.quizzes) {
      expect(q.answer, inInclusiveRange(0, q.options.length - 1));
      expect(q.explanation, isNotEmpty);
    }
    final eighth = chapters[7];
    expect(eighth.id, 'chapter_08');
    expect(eighth.lessons.length, 17);
    expect(eighth.quizzes.length, 20);
    expect(eighth.exercises.length, 8);
    expect(eighth.interviews.length, 8);
    for (final lesson in eighth.lessons) {
      expect(lesson.blocks.length, greaterThanOrEqualTo(8));
    }
    for (final q in eighth.quizzes) {
      expect(q.answer, inInclusiveRange(0, q.options.length - 1));
      expect(q.explanation, isNotEmpty);
    }
    final ninth = chapters[8];
    expect(ninth.id, 'chapter_09');
    expect(ninth.lessons.length, 17);
    expect(ninth.quizzes.length, 20);
    expect(ninth.exercises.length, 8);
    expect(ninth.interviews.length, 8);
    for (final lesson in ninth.lessons) {
      expect(lesson.blocks.length, greaterThanOrEqualTo(8));
    }
    for (final q in ninth.quizzes) {
      expect(q.answer, inInclusiveRange(0, q.options.length - 1));
      expect(q.explanation, isNotEmpty);
    }
    final tenth = chapters[9];
    expect(tenth.id, 'chapter_10');
    expect(tenth.lessons.length, 19);
    expect(tenth.quizzes.length, 24);
    expect(tenth.exercises.length, 10);
    expect(tenth.interviews.length, 10);
    for (final lesson in tenth.lessons) {
      expect(lesson.blocks.length, greaterThanOrEqualTo(8));
    }
    for (final q in tenth.quizzes) {
      expect(q.answer, inInclusiveRange(0, q.options.length - 1));
      expect(q.explanation, isNotEmpty);
    }
    final eleventh = chapters[10];
    expect(eleventh.id, 'chapter_11');
    expect(eleventh.lessons.length, 21);
    expect(eleventh.quizzes.length, 26);
    expect(eleventh.exercises.length, 10);
    expect(eleventh.interviews.length, 10);
    for (final l in eleventh.lessons) {
      expect(l.blocks.length, greaterThanOrEqualTo(8));
    }
    for (final q in eleventh.quizzes) {
      expect(q.answer, inInclusiveRange(0, q.options.length - 1));
      expect(q.explanation, isNotEmpty);
    }
    final twelfth = chapters[11];
    expect(twelfth.id, 'chapter_12');
    expect(twelfth.lessons.length, 20);
    expect(twelfth.quizzes.length, 26);
    expect(twelfth.exercises.length, 10);
    expect(twelfth.interviews.length, 10);
    for (final l in twelfth.lessons) {
      expect(l.blocks.length, greaterThanOrEqualTo(8));
    }
    for (final q in twelfth.quizzes) {
      expect(q.answer, inInclusiveRange(0, q.options.length - 1));
      expect(q.explanation, isNotEmpty);
    }
    final thirteenth = chapters[12];
    expect(thirteenth.id, 'chapter_13');
    expect(thirteenth.lessons.length, 22);
    expect(thirteenth.quizzes.length, 26);
    expect(thirteenth.exercises.length, 10);
    expect(thirteenth.interviews.length, 10);
    for (final l in thirteenth.lessons) {
      expect(l.blocks.length, greaterThanOrEqualTo(8));
    }
    for (final q in thirteenth.quizzes) {
      expect(q.answer, inInclusiveRange(0, q.options.length - 1));
      expect(q.explanation, isNotEmpty);
    }
    final fourteenth = chapters[13];
    expect(fourteenth.id, 'chapter_14');
    expect(fourteenth.lessons.length, 21);
    expect(fourteenth.quizzes.length, 26);
    expect(fourteenth.exercises.length, 10);
    expect(fourteenth.interviews.length, 10);
    for (final l in fourteenth.lessons) {
      expect(l.blocks.length, greaterThanOrEqualTo(8));
    }
    for (final q in fourteenth.quizzes) {
      expect(q.answer, inInclusiveRange(0, q.options.length - 1));
      expect(q.explanation, isNotEmpty);
    }
    final fifteenth = chapters[14];
    expect(fifteenth.id, 'chapter_15');
    expect(fifteenth.lessons.length, 21);
    expect(fifteenth.quizzes.length, 26);
    expect(fifteenth.exercises.length, 10);
    expect(fifteenth.interviews.length, 10);
    for (final l in fifteenth.lessons) {
      expect(l.blocks.length, greaterThanOrEqualTo(8));
    }
    for (final q in fifteenth.quizzes) {
      expect(q.answer, inInclusiveRange(0, q.options.length - 1));
      expect(q.explanation, isNotEmpty);
    }
    final sixteenth = chapters[15];
    expect(sixteenth.id, 'chapter_16');
    expect(sixteenth.lessons.length, 21);
    expect(sixteenth.quizzes.length, 26);
    expect(sixteenth.exercises.length, 10);
    expect(sixteenth.interviews.length, 10);
    for (final l in sixteenth.lessons) {
      expect(l.blocks.length, greaterThanOrEqualTo(8));
    }
    for (final q in sixteenth.quizzes) {
      expect(q.answer, inInclusiveRange(0, q.options.length - 1));
      expect(q.explanation, isNotEmpty);
    }
    final seventeenth = chapters[16];
    expect(seventeenth.id, 'chapter_17');
    expect(seventeenth.lessons.length, 22);
    expect(seventeenth.quizzes.length, 26);
    expect(seventeenth.exercises.length, 10);
    expect(seventeenth.interviews.length, 10);
    for (final l in seventeenth.lessons) {
      expect(l.blocks.length, greaterThanOrEqualTo(8));
    }
    for (final q in seventeenth.quizzes) {
      expect(q.answer, inInclusiveRange(0, q.options.length - 1));
      expect(q.explanation, isNotEmpty);
    }
    final eighteenth = chapters[17];
    expect(eighteenth.id, 'chapter_18');
    expect(eighteenth.lessons.length, 21);
    expect(eighteenth.quizzes.length, 26);
    expect(eighteenth.exercises.length, 10);
    expect(eighteenth.interviews.length, 10);
    for (final l in eighteenth.lessons) {
      expect(l.blocks.length, greaterThanOrEqualTo(8));
    }
    for (final q in eighteenth.quizzes) {
      expect(q.answer, inInclusiveRange(0, q.options.length - 1));
      expect(q.explanation, isNotEmpty);
    }
    final nineteenth = chapters[18];
    expect(nineteenth.id, 'chapter_19');
    expect(nineteenth.lessons.length, 21);
    expect(nineteenth.quizzes.length, 26);
    expect(nineteenth.exercises.length, 10);
    expect(nineteenth.interviews.length, 10);
    for (final l in nineteenth.lessons) {
      expect(l.blocks.length, greaterThanOrEqualTo(8));
    }
    for (final q in nineteenth.quizzes) {
      expect(q.answer, inInclusiveRange(0, q.options.length - 1));
      expect(q.explanation, isNotEmpty);
    }
    final twentieth = chapters[19];
    expect(twentieth.id, 'chapter_20');
    expect(twentieth.lessons.length, 21);
    expect(twentieth.quizzes.length, 26);
    expect(twentieth.exercises.length, 10);
    expect(twentieth.interviews.length, 10);
    for (final l in twentieth.lessons) {
      expect(l.blocks.length, greaterThanOrEqualTo(8));
    }
    for (final q in twentieth.quizzes) {
      expect(q.answer, inInclusiveRange(0, q.options.length - 1));
      expect(q.explanation, isNotEmpty);
    }
    final twentyFirst = chapters[20];
    expect(twentyFirst.id, 'chapter_21');
    expect(twentyFirst.lessons.length, 21);
    expect(twentyFirst.quizzes.length, 26);
    expect(twentyFirst.exercises.length, 10);
    expect(twentyFirst.interviews.length, 10);
    for (final l in twentyFirst.lessons) {
      expect(l.blocks.length, greaterThanOrEqualTo(8));
    }
    for (final q in twentyFirst.quizzes) {
      expect(q.answer, inInclusiveRange(0, q.options.length - 1));
      expect(q.explanation, isNotEmpty);
    }
    final twentySecond = chapters[21];
    expect(twentySecond.id, 'chapter_22');
    expect(twentySecond.lessons.length, 22);
    expect(twentySecond.quizzes.length, 26);
    expect(twentySecond.exercises.length, 10);
    expect(twentySecond.interviews.length, 10);
    for (final l in twentySecond.lessons) {
      expect(l.blocks.length, greaterThanOrEqualTo(8));
    }
    for (final q in twentySecond.quizzes) {
      expect(q.answer, inInclusiveRange(0, q.options.length - 1));
      expect(q.explanation, isNotEmpty);
    }
    final twentyThird = chapters[22];
    expect(twentyThird.id, 'chapter_23');
    expect(twentyThird.lessons.length, 21);
    expect(twentyThird.quizzes.length, 26);
    expect(twentyThird.exercises.length, 10);
    expect(twentyThird.interviews.length, 10);
    expect(
      twentyThird.lessons.fold<int>(0, (n, l) => n + l.blocks.length),
      greaterThanOrEqualTo(170),
    );
    for (final q in twentyThird.quizzes) {
      expect(q.answer, inInclusiveRange(0, q.options.length - 1));
      expect(q.explanation, isNotEmpty);
    }
    final twentyFourth = chapters[23];
    expect(twentyFourth.id, 'chapter_24');
    expect(twentyFourth.lessons.length, 21);
    expect(twentyFourth.quizzes.length, 26);
    expect(twentyFourth.exercises.length, 10);
    expect(twentyFourth.interviews.length, 10);
    expect(
      twentyFourth.lessons.fold<int>(0, (n, l) => n + l.blocks.length),
      greaterThanOrEqualTo(170),
    );
    final twentyFifth = chapters[24];
    expect(twentyFifth.id, 'chapter_25');
    expect(twentyFifth.lessons.length, 16);
    expect(twentyFifth.quizzes.length, 26);
    expect(twentyFifth.exercises.length, 10);
    expect(twentyFifth.interviews.length, 10);
    expect(
      twentyFifth.lessons.fold<int>(0, (n, l) => n + l.blocks.length),
      greaterThanOrEqualTo(128),
    );
    final twentySixth = chapters[25];
    expect(twentySixth.id, 'chapter_26');
    expect(twentySixth.lessons.length, 18);
    expect(twentySixth.quizzes.length, 26);
    expect(twentySixth.exercises.length, 10);
    expect(twentySixth.interviews.length, 10);
    expect(
      twentySixth.lessons.fold<int>(0, (n, l) => n + l.blocks.length),
      greaterThanOrEqualTo(136),
    );
    final twentySeventh = chapters[26];
    expect(twentySeventh.id, 'chapter_27');
    expect(twentySeventh.lessons.length, 19);
    expect(twentySeventh.quizzes.length, 26);
    expect(twentySeventh.exercises.length, 10);
    expect(twentySeventh.interviews.length, 10);
    expect(
      twentySeventh.lessons.fold<int>(0, (n, l) => n + l.blocks.length),
      greaterThanOrEqualTo(152),
    );
    final twentyEighth = chapters[27];
    expect(twentyEighth.id, 'chapter_28');
    expect(twentyEighth.lessons.length, 22);
    expect(twentyEighth.quizzes.length, 26);
    expect(twentyEighth.exercises.length, 10);
    expect(twentyEighth.interviews.length, 10);
    expect(
      twentyEighth.lessons.fold<int>(0, (n, l) => n + l.blocks.length),
      greaterThanOrEqualTo(168),
    );
    final twentyNinth = chapters[28];
    expect(twentyNinth.id, 'chapter_29');
    expect(twentyNinth.lessons.length, 21);
    expect(twentyNinth.quizzes.length, 26);
    expect(twentyNinth.exercises.length, 10);
    expect(twentyNinth.interviews.length, 10);
    expect(
      twentyNinth.lessons.fold<int>(0, (n, l) => n + l.blocks.length),
      greaterThanOrEqualTo(168),
    );
    final thirtieth = chapters[29];
    expect(thirtieth.id, 'chapter_30');
    expect(thirtieth.lessons.length, 21);
    expect(thirtieth.quizzes.length, 26);
    expect(thirtieth.exercises.length, 10);
    expect(thirtieth.interviews.length, 10);
    expect(
      thirtieth.lessons.fold<int>(0, (n, l) => n + l.blocks.length),
      greaterThanOrEqualTo(168),
    );
    final thirtyFirst = chapters[30];
    expect(thirtyFirst.id, 'chapter_31');
    expect(thirtyFirst.lessons.length, 21);
    expect(thirtyFirst.quizzes.length, 26);
    expect(thirtyFirst.exercises.length, 10);
    expect(thirtyFirst.interviews.length, 10);
    expect(
      thirtyFirst.lessons.fold<int>(0, (n, l) => n + l.blocks.length),
      greaterThanOrEqualTo(168),
    );
    final thirtySecond = chapters[31];
    expect(thirtySecond.id, 'chapter_32');
    expect(thirtySecond.lessons.length, 23);
    expect(thirtySecond.quizzes.length, 26);
    expect(thirtySecond.exercises.length, 10);
    expect(thirtySecond.interviews.length, 10);
    expect(
      thirtySecond.lessons.fold<int>(0, (n, l) => n + l.blocks.length),
      greaterThanOrEqualTo(176),
    );
    final thirtyThird = chapters[32];
    expect(thirtyThird.id, 'chapter_33');
    expect(thirtyThird.lessons.length, 21);
    expect(thirtyThird.quizzes.length, 26);
    expect(thirtyThird.exercises.length, 10);
    expect(thirtyThird.interviews.length, 10);
    expect(
      thirtyThird.lessons.fold<int>(0, (n, l) => n + l.blocks.length),
      greaterThanOrEqualTo(168),
    );
    final thirtyFourth = chapters[33];
    expect(thirtyFourth.id, 'chapter_34');
    expect(thirtyFourth.lessons.length, 21);
    expect(thirtyFourth.quizzes.length, 26);
    expect(thirtyFourth.exercises.length, 10);
    expect(thirtyFourth.interviews.length, 10);
    expect(
      thirtyFourth.lessons.fold<int>(0, (n, l) => n + l.blocks.length),
      greaterThanOrEqualTo(168),
    );
    final thirtyFifth = chapters[34];
    expect(thirtyFifth.id, 'chapter_35');
    expect(thirtyFifth.lessons.length, 21);
    expect(thirtyFifth.quizzes.length, 26);
    expect(thirtyFifth.exercises.length, 10);
    expect(thirtyFifth.interviews.length, 10);
    expect(
      thirtyFifth.lessons.fold<int>(0, (n, l) => n + l.blocks.length),
      greaterThanOrEqualTo(168),
    );
    final thirtySixth = chapters[35];
    expect(thirtySixth.id, 'chapter_36');
    expect(thirtySixth.lessons.length, 21);
    expect(thirtySixth.quizzes.length, 26);
    expect(thirtySixth.exercises.length, 10);
    expect(thirtySixth.interviews.length, 10);
    expect(
      thirtySixth.lessons.fold<int>(0, (n, l) => n + l.blocks.length),
      greaterThanOrEqualTo(168),
    );
    final thirtySeventh = chapters[36];
    expect(thirtySeventh.id, 'chapter_37');
    expect(thirtySeventh.lessons.length, 21);
    expect(thirtySeventh.quizzes.length, 26);
    expect(thirtySeventh.exercises.length, 10);
    expect(thirtySeventh.interviews.length, 10);
    expect(
      thirtySeventh.lessons.fold<int>(0, (n, l) => n + l.blocks.length),
      greaterThanOrEqualTo(168),
    );
    final thirtyEighth = chapters[37];
    expect(thirtyEighth.id, 'chapter_38');
    expect(thirtyEighth.lessons.length, 22);
    expect(thirtyEighth.quizzes.length, 26);
    expect(thirtyEighth.exercises.length, 10);
    expect(thirtyEighth.interviews.length, 10);
    expect(
      thirtyEighth.lessons.fold<int>(0, (n, l) => n + l.blocks.length),
      greaterThanOrEqualTo(168),
    );
    final thirtyNinth = chapters[38];
    expect(thirtyNinth.id, 'chapter_39');
    expect(thirtyNinth.lessons.length, 31);
    expect(thirtyNinth.quizzes.length, 34);
    expect(thirtyNinth.exercises.length, 17);
    expect(thirtyNinth.interviews.length, 14);
    expect(
      thirtyNinth.lessons.fold<int>(0, (n, l) => n + l.blocks.length),
      greaterThanOrEqualTo(208),
    );
    final fortieth = chapters[39];
    expect(fortieth.id, 'chapter_40');
    expect(fortieth.lessons.length, 28);
    expect(fortieth.quizzes.length, 34);
    expect(fortieth.exercises.length, 12);
    expect(fortieth.interviews.length, 14);
    expect(
      fortieth.lessons.fold<int>(0, (n, l) => n + l.blocks.length),
      greaterThanOrEqualTo(208),
    );
    final ids = [
      // Content and learner-state IDs are checked across the complete catalog.
      for (final c in chapters) ...[
        ...c.lessons.map((l) => l.id),
        ...c.quizzes.map((q) => q.id),
        ...c.exercises.map((e) => e.id),
      ],
    ];
    final sixth = chapters[5];
    expect(sixth.id, 'chapter_06');
    expect(sixth.lessons.length, 15);
    expect(sixth.quizzes.length, 18);
    expect(sixth.interviews.length, 8);
    expect(sixth.exercises.length, 8);
    final seventh = chapters[6];
    expect(seventh.id, 'chapter_07');
    expect(seventh.lessons.length, 18);
    expect(seventh.quizzes.length, 20);
    expect(seventh.interviews.length, 8);
    expect(seventh.exercises.length, 8);
    for (final lesson in seventh.lessons) {
      expect(lesson.blocks.length, greaterThanOrEqualTo(8));
    }
    for (final q in seventh.quizzes) {
      expect(q.answer, inInclusiveRange(0, q.options.length - 1));
      expect(q.explanation, isNotEmpty);
    }
    for (final lesson in sixth.lessons) {
      expect(lesson.blocks.length, greaterThanOrEqualTo(8));
    }
    for (final q in sixth.quizzes) {
      expect(q.answer, inInclusiveRange(0, q.options.length - 1));
      expect(q.explanation, isNotEmpty);
    }
    expect(
      ids.toSet().length,
      ids.length,
      reason: 'Learner state uses global stable IDs',
    );
    for (final lesson in second.lessons) {
      expect(lesson.blocks.length, greaterThanOrEqualTo(6));
    }
    for (final q in second.quizzes) {
      expect(q.answer, inInclusiveRange(0, q.options.length - 1));
    }
  });
  test(
    'Chapter 7 upgrade and quiz retry preserve all previous learner state',
    () async {
      await repo.db.delete(
        'chapters',
        where: 'id = ?',
        whereArgs: ['chapter_07'],
      );
      final previous = (await repo.chapters())
          .where((c) => c.number <= 6)
          .toList();
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
      await repo.setSetting('selected_chapter', 'chapter_06');
      await repo.setSetting('last_lesson:chapter_06', 'ch06_arrays');
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final c = LearningController(repo);
      await c.load();
      expect(c.chapters.length, 50);
      expect(c.chapter.id, 'chapter_06');
      expect(c.nextLesson.id, 'ch06_arrays');
      await c.selectChapter('chapter_07');
      expect(c.answers, isEmpty);
      expect(c.completedCount, 0);
      await c.answer('ch07_q1', 1);
      await c.saveNote('ch07_vectors', 'নতুন pipeline');
      await c.toggleBookmark('ch07_vectors');
      await c.toggleComplete('ch07_vectors');
      await c.visit('ch07_checking');
      await c.resetQuiz();
      expect(c.answers, isEmpty);
      for (final ch in previous) {
        await c.selectChapter(ch.id);
        expect(c.score, 1);
        expect(c.completedCount, 1);
        expect(c.note(ch.lessons.first.id), 'Saved chapter ${ch.number}');
        expect(c.bookmarked(ch.lessons.first.id), isTrue);
        expect(
          (await repo.exercise(ch.exercises.first.id))?['draft'],
          'Draft chapter ${ch.number}',
        );
      }
      await c.selectChapter('chapter_07');
      c.dispose();
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final reopened = LearningController(repo);
      await reopened.load();
      expect(reopened.chapter.id, 'chapter_07');
      expect(reopened.nextLesson.id, 'ch07_checking');
      expect(reopened.note('ch07_vectors'), 'নতুন pipeline');
      expect(reopened.completedCount, 1);
      reopened.dispose();
    },
  );
  test(
    'Chapter 8 upgrade and quiz retry preserve all previous learner state',
    () async {
      await repo.db.delete(
        'chapters',
        where: 'id = ?',
        whereArgs: ['chapter_08'],
      );
      final previous = (await repo.chapters())
          .where((c) => c.number <= 7)
          .toList();
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
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final c = LearningController(repo);
      await c.load();
      expect(c.chapters.length, 50);
      expect(c.chapter.id, 'chapter_07');
      expect(c.nextLesson.id, 'ch07_checking');
      await c.selectChapter('chapter_08');
      expect(c.answers, isEmpty);
      expect(c.completedCount, 0);
      await c.answer('ch08_q1', 1);
      await c.saveNote('ch08_estimands', 'নতুন pipeline');
      await c.toggleBookmark('ch08_estimands');
      await c.toggleComplete('ch08_estimands');
      await c.visit('ch08_intervals');
      await c.resetQuiz();
      expect(c.answers, isEmpty);
      for (final ch in previous) {
        await c.selectChapter(ch.id);
        expect(c.score, 1);
        expect(c.completedCount, 1);
        expect(c.note(ch.lessons.first.id), 'Saved chapter ${ch.number}');
        expect(c.bookmarked(ch.lessons.first.id), isTrue);
        expect(
          (await repo.exercise(ch.exercises.first.id))?['draft'],
          'Draft chapter ${ch.number}',
        );
      }
      await c.selectChapter('chapter_08');
      c.dispose();
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final reopened = LearningController(repo);
      await reopened.load();
      expect(reopened.chapter.id, 'chapter_08');
      expect(reopened.nextLesson.id, 'ch08_intervals');
      expect(reopened.note('ch08_estimands'), 'নতুন pipeline');
      expect(reopened.completedCount, 1);
      reopened.dispose();
    },
  );
  test(
    'Chapter 9 upgrade and quiz retry preserve all previous learner state',
    () async {
      await repo.db.delete(
        'chapters',
        where: 'id = ?',
        whereArgs: ['chapter_09'],
      );
      final previous = (await repo.chapters())
          .where((c) => c.number <= 8)
          .toList();
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
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final c = LearningController(repo);
      await c.load();
      expect(c.chapters.length, 50);
      expect(c.chapter.id, 'chapter_08');
      expect(c.nextLesson.id, 'ch08_intervals');
      await c.selectChapter('chapter_09');
      expect(c.answers, isEmpty);
      expect(c.completedCount, 0);
      await c.answer('ch09_q1', 1);
      await c.saveNote('ch09_rules', 'নতুন pipeline');
      await c.toggleBookmark('ch09_rules');
      await c.toggleComplete('ch09_rules');
      await c.visit('ch09_pruning');
      await c.resetQuiz();
      expect(c.answers, isEmpty);
      for (final ch in previous) {
        await c.selectChapter(ch.id);
        expect(c.score, 1);
        expect(c.completedCount, 1);
        expect(c.note(ch.lessons.first.id), 'Saved chapter ${ch.number}');
        expect(c.bookmarked(ch.lessons.first.id), isTrue);
        expect(
          (await repo.exercise(ch.exercises.first.id))?['draft'],
          'Draft chapter ${ch.number}',
        );
      }
      await c.selectChapter('chapter_09');
      c.dispose();
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final reopened = LearningController(repo);
      await reopened.load();
      expect(reopened.chapter.id, 'chapter_09');
      expect(reopened.nextLesson.id, 'ch09_pruning');
      expect(reopened.note('ch09_rules'), 'নতুন pipeline');
      expect(reopened.completedCount, 1);
      reopened.dispose();
    },
  );
  test(
    'Chapter 10 upgrade and quiz retry preserve all previous learner state',
    () async {
      await repo.db.delete(
        'chapters',
        where: 'id = ?',
        whereArgs: ['chapter_10'],
      );
      final previous = (await repo.chapters())
          .where((c) => c.number <= 9)
          .toList();
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
      await repo.setSetting('selected_chapter', 'chapter_09');
      await repo.setSetting('last_lesson:chapter_09', 'ch09_pruning');
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final c = LearningController(repo);
      await c.load();
      expect(c.chapters.length, 50);
      expect(c.chapter.id, 'chapter_09');
      expect(c.nextLesson.id, 'ch09_pruning');
      await c.selectChapter('chapter_10');
      expect(c.answers, isEmpty);
      expect(c.completedCount, 0);
      await c.answer('ch10_q1', 1);
      await c.saveNote('ch10_averaging', 'নতুন pipeline');
      await c.toggleBookmark('ch10_averaging');
      await c.toggleComplete('ch10_averaging');
      await c.visit('ch10_gradient');
      await c.resetQuiz();
      expect(c.answers, isEmpty);
      for (final ch in previous) {
        await c.selectChapter(ch.id);
        expect(c.score, 1);
        expect(c.completedCount, 1);
        expect(c.note(ch.lessons.first.id), 'Saved chapter ${ch.number}');
        expect(c.bookmarked(ch.lessons.first.id), isTrue);
        expect(
          (await repo.exercise(ch.exercises.first.id))?['draft'],
          'Draft chapter ${ch.number}',
        );
      }
      await c.selectChapter('chapter_10');
      c.dispose();
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final reopened = LearningController(repo);
      await reopened.load();
      expect(reopened.chapter.id, 'chapter_10');
      expect(reopened.nextLesson.id, 'ch10_gradient');
      expect(reopened.note('ch10_averaging'), 'নতুন pipeline');
      expect(reopened.completedCount, 1);
      reopened.dispose();
    },
  );
  test(
    'Chapter 11 upgrade and quiz retry preserve all previous learner state',
    () async {
      await repo.db.delete(
        'chapters',
        where: 'id = ?',
        whereArgs: ['chapter_11'],
      );
      final previous = (await repo.chapters())
          .where((c) => c.number <= 10)
          .toList();
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
      await repo.setSetting('selected_chapter', 'chapter_10');
      await repo.setSetting('last_lesson:chapter_10', 'ch10_gradient');
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final c = LearningController(repo);
      await c.load();
      expect(c.chapters.length, 50);
      expect(c.chapter.id, 'chapter_10');
      expect(c.nextLesson.id, 'ch10_gradient');
      await c.selectChapter('chapter_11');
      expect(c.answers, isEmpty);
      expect(c.completedCount, 0);
      await c.answer('ch11_q1', 1);
      await c.saveNote('ch11_families', 'নতুন pipeline');
      await c.toggleBookmark('ch11_families');
      await c.toggleComplete('ch11_families');
      await c.visit('ch11_gaussian');
      await c.resetQuiz();
      expect(c.answers, isEmpty);
      for (final ch in previous) {
        await c.selectChapter(ch.id);
        expect(c.score, 1);
        expect(c.completedCount, 1);
        expect(c.note(ch.lessons.first.id), 'Saved chapter ${ch.number}');
        expect(c.bookmarked(ch.lessons.first.id), isTrue);
        expect(
          (await repo.exercise(ch.exercises.first.id))?['draft'],
          'Draft chapter ${ch.number}',
        );
      }
      await c.selectChapter('chapter_11');
      c.dispose();
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final reopened = LearningController(repo);
      await reopened.load();
      expect(reopened.chapter.id, 'chapter_11');
      expect(reopened.nextLesson.id, 'ch11_gaussian');
      expect(reopened.note('ch11_families'), 'নতুন pipeline');
      expect(reopened.completedCount, 1);
      reopened.dispose();
    },
  );
  test(
    'Chapter 12 upgrade and quiz retry preserve all previous learner state',
    () async {
      await repo.db.delete(
        'chapters',
        where: 'id = ?',
        whereArgs: ['chapter_12'],
      );
      final previous = (await repo.chapters())
          .where((c) => c.number <= 11)
          .toList();
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
      await repo.setSetting('selected_chapter', 'chapter_11');
      await repo.setSetting('last_lesson:chapter_11', 'ch11_gaussian');
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final c = LearningController(repo);
      await c.load();
      expect(c.chapters.length, 50);
      expect(c.chapter.id, 'chapter_11');
      expect(c.nextLesson.id, 'ch11_gaussian');
      await c.selectChapter('chapter_12');
      expect(c.answers, isEmpty);
      expect(c.completedCount, 0);
      await c.answer('ch12_q1', 1);
      await c.saveNote('ch12_questions', 'নতুন pipeline');
      await c.toggleBookmark('ch12_questions');
      await c.toggleComplete('ch12_questions');
      await c.visit('ch12_pca');
      await c.resetQuiz();
      expect(c.answers, isEmpty);
      for (final ch in previous) {
        await c.selectChapter(ch.id);
        expect(c.score, 1);
        expect(c.completedCount, 1);
        expect(c.note(ch.lessons.first.id), 'Saved chapter ${ch.number}');
        expect(c.bookmarked(ch.lessons.first.id), isTrue);
        expect(
          (await repo.exercise(ch.exercises.first.id))?['draft'],
          'Draft chapter ${ch.number}',
        );
      }
      await c.selectChapter('chapter_12');
      c.dispose();
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final reopened = LearningController(repo);
      await reopened.load();
      expect(reopened.chapter.id, 'chapter_12');
      expect(reopened.nextLesson.id, 'ch12_pca');
      expect(reopened.note('ch12_questions'), 'নতুন pipeline');
      expect(reopened.completedCount, 1);
      reopened.dispose();
    },
  );
  test(
    'Chapter 13 upgrade and quiz retry preserve all previous learner state',
    () async {
      await repo.db.delete(
        'chapters',
        where: 'id = ?',
        whereArgs: ['chapter_13'],
      );
      final previous = (await repo.chapters())
          .where((c) => c.number <= 12)
          .toList();
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
      await repo.setSetting('selected_chapter', 'chapter_12');
      await repo.setSetting('last_lesson:chapter_12', 'ch12_pca');
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final c = LearningController(repo);
      await c.load();
      expect(c.chapters.length, 50);
      expect(c.chapter.id, 'chapter_12');
      expect(c.nextLesson.id, 'ch12_pca');
      await c.selectChapter('chapter_13');
      expect(c.answers, isEmpty);
      expect(c.completedCount, 0);
      await c.answer('ch13_q1', 1);
      await c.saveNote('ch13_questions', 'নতুন pipeline');
      await c.toggleBookmark('ch13_questions');
      await c.toggleComplete('ch13_questions');
      await c.visit('ch13_backtest');
      await c.resetQuiz();
      expect(c.answers, isEmpty);
      for (final ch in previous) {
        await c.selectChapter(ch.id);
        expect(c.score, 1);
        expect(c.completedCount, 1);
        expect(c.note(ch.lessons.first.id), 'Saved chapter ${ch.number}');
        expect(c.bookmarked(ch.lessons.first.id), isTrue);
        expect(
          (await repo.exercise(ch.exercises.first.id))?['draft'],
          'Draft chapter ${ch.number}',
        );
      }
      await c.selectChapter('chapter_13');
      c.dispose();
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final reopened = LearningController(repo);
      await reopened.load();
      expect(reopened.chapter.id, 'chapter_13');
      expect(reopened.nextLesson.id, 'ch13_backtest');
      expect(reopened.note('ch13_questions'), 'নতুন pipeline');
      expect(reopened.completedCount, 1);
      reopened.dispose();
    },
  );
  test(
    'Chapter 14 upgrade and quiz retry preserve all previous learner state',
    () async {
      await repo.db.delete(
        'chapters',
        where: 'id = ?',
        whereArgs: ['chapter_14'],
      );
      final previous = (await repo.chapters())
          .where((c) => c.number <= 13)
          .toList();
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
      await repo.setSetting('selected_chapter', 'chapter_13');
      await repo.setSetting('last_lesson:chapter_13', 'ch13_backtest');
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final c = LearningController(repo);
      await c.load();
      expect(c.chapters.length, 50);
      expect(c.chapter.id, 'chapter_13');
      expect(c.nextLesson.id, 'ch13_backtest');
      await c.selectChapter('chapter_14');
      expect(c.answers, isEmpty);
      expect(c.completedCount, 0);
      await c.answer('ch14_q1', 1);
      await c.saveNote('ch14_brief', 'নতুন pipeline');
      await c.toggleBookmark('ch14_brief');
      await c.toggleComplete('ch14_brief');
      await c.visit('ch14_trace');
      await c.resetQuiz();
      expect(c.answers, isEmpty);
      for (final ch in previous) {
        await c.selectChapter(ch.id);
        expect(c.score, 1);
        expect(c.completedCount, 1);
        expect(c.note(ch.lessons.first.id), 'Saved chapter ${ch.number}');
        expect(c.bookmarked(ch.lessons.first.id), isTrue);
        expect(
          (await repo.exercise(ch.exercises.first.id))?['draft'],
          'Draft chapter ${ch.number}',
        );
      }
      await c.selectChapter('chapter_14');
      c.dispose();
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final reopened = LearningController(repo);
      await reopened.load();
      expect(reopened.chapter.id, 'chapter_14');
      expect(reopened.nextLesson.id, 'ch14_trace');
      expect(reopened.note('ch14_brief'), 'নতুন pipeline');
      expect(reopened.completedCount, 1);
      reopened.dispose();
    },
  );
  test(
    'Chapter 15 upgrade and quiz retry preserve all previous learner state',
    () async {
      await repo.db.delete(
        'chapters',
        where: 'id = ?',
        whereArgs: ['chapter_15'],
      );
      final previous = (await repo.chapters())
          .where((c) => c.number <= 14)
          .toList();
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
      await repo.setSetting('selected_chapter', 'chapter_14');
      await repo.setSetting('last_lesson:chapter_14', 'ch14_trace');
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final c = LearningController(repo);
      await c.load();
      expect(c.chapters.length, 50);
      expect(c.chapter.id, 'chapter_14');
      expect(c.nextLesson.id, 'ch14_trace');
      await c.selectChapter('chapter_15');
      expect(c.answers, isEmpty);
      expect(c.completedCount, 0);
      await c.answer('ch15_q1', 1);
      await c.saveNote('ch15_contract', 'নতুন pipeline');
      await c.toggleBookmark('ch15_contract');
      await c.toggleComplete('ch15_contract');
      await c.visit('ch15_microscope');
      await c.resetQuiz();
      expect(c.answers, isEmpty);
      for (final ch in previous) {
        await c.selectChapter(ch.id);
        expect(c.score, 1);
        expect(c.completedCount, 1);
        expect(c.note(ch.lessons.first.id), 'Saved chapter ${ch.number}');
        expect(c.bookmarked(ch.lessons.first.id), isTrue);
        expect(
          (await repo.exercise(ch.exercises.first.id))?['draft'],
          'Draft chapter ${ch.number}',
        );
      }
      await c.selectChapter('chapter_15');
      c.dispose();
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final reopened = LearningController(repo);
      await reopened.load();
      expect(reopened.chapter.id, 'chapter_15');
      expect(reopened.nextLesson.id, 'ch15_microscope');
      expect(reopened.note('ch15_contract'), 'নতুন pipeline');
      expect(reopened.completedCount, 1);
      reopened.dispose();
    },
  );
  test(
    'Chapter 16 upgrade and quiz retry preserve all previous learner state',
    () async {
      await repo.db.delete(
        'chapters',
        where: 'id = ?',
        whereArgs: ['chapter_16'],
      );
      final previous = (await repo.chapters())
          .where((c) => c.number <= 15)
          .toList();
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
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final c = LearningController(repo);
      await c.load();
      expect(c.chapters.length, 50);
      expect(c.chapter.id, 'chapter_15');
      expect(c.nextLesson.id, 'ch15_microscope');
      await c.selectChapter('chapter_16');
      expect(c.answers, isEmpty);
      expect(c.completedCount, 0);
      await c.answer('ch16_q1', 1);
      await c.saveNote('ch16_contract', 'নতুন pipeline');
      await c.toggleBookmark('ch16_contract');
      await c.toggleComplete('ch16_contract');
      await c.visit('ch16_diagnostics');
      await c.resetQuiz();
      expect(c.answers, isEmpty);
      for (final ch in previous) {
        await c.selectChapter(ch.id);
        expect(c.score, 1);
        expect(c.completedCount, 1);
        expect(c.note(ch.lessons.first.id), 'Saved chapter ${ch.number}');
        expect(c.bookmarked(ch.lessons.first.id), isTrue);
        expect(
          (await repo.exercise(ch.exercises.first.id))?['draft'],
          'Draft chapter ${ch.number}',
        );
      }
      await c.selectChapter('chapter_16');
      c.dispose();
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final reopened = LearningController(repo);
      await reopened.load();
      expect(reopened.chapter.id, 'chapter_16');
      expect(reopened.nextLesson.id, 'ch16_diagnostics');
      expect(reopened.note('ch16_contract'), 'নতুন pipeline');
      expect(reopened.completedCount, 1);
      reopened.dispose();
    },
  );
  test(
    'Chapter 17 upgrade and quiz retry preserve all previous learner state',
    () async {
      await repo.db.delete(
        'chapters',
        where: 'id = ?',
        whereArgs: ['chapter_17'],
      );
      final previous = (await repo.chapters())
          .where((c) => c.number <= 16)
          .toList();
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
      await repo.setSetting('selected_chapter', 'chapter_16');
      await repo.setSetting('last_lesson:chapter_16', 'ch16_diagnostics');
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final c = LearningController(repo);
      await c.load();
      expect(c.chapters.length, 50);
      expect(c.chapter.id, 'chapter_16');
      expect(c.nextLesson.id, 'ch16_diagnostics');
      await c.selectChapter('chapter_17');
      expect(c.answers, isEmpty);
      expect(c.completedCount, 0);
      await c.answer('ch17_q1', 1);
      await c.saveNote('ch17_contract', 'নতুন pipeline');
      await c.toggleBookmark('ch17_contract');
      await c.toggleComplete('ch17_contract');
      await c.visit('ch17_resume');
      await c.resetQuiz();
      expect(c.answers, isEmpty);
      for (final ch in previous) {
        await c.selectChapter(ch.id);
        expect(c.score, 1);
        expect(c.completedCount, 1);
        expect(c.note(ch.lessons.first.id), 'Saved chapter ${ch.number}');
        expect(c.bookmarked(ch.lessons.first.id), isTrue);
        expect(
          (await repo.exercise(ch.exercises.first.id))?['draft'],
          'Draft chapter ${ch.number}',
        );
      }
      await c.selectChapter('chapter_17');
      c.dispose();
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final reopened = LearningController(repo);
      await reopened.load();
      expect(reopened.chapter.id, 'chapter_17');
      expect(reopened.nextLesson.id, 'ch17_resume');
      expect(reopened.note('ch17_contract'), 'নতুন pipeline');
      expect(reopened.completedCount, 1);
      reopened.dispose();
    },
  );
  test(
    'Chapter 18 upgrade and quiz retry preserve all previous learner state',
    () async {
      await repo.db.delete(
        'chapters',
        where: 'id = ?',
        whereArgs: ['chapter_18'],
      );
      final previous = (await repo.chapters())
          .where((c) => c.number <= 17)
          .toList();
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
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final c = LearningController(repo);
      await c.load();
      expect(c.chapters.length, 50);
      expect(c.chapter.id, 'chapter_17');
      expect(c.nextLesson.id, 'ch17_resume');
      await c.selectChapter('chapter_18');
      expect(c.answers, isEmpty);
      expect(c.completedCount, 0);
      await c.answer('ch18_q1', 1);
      await c.saveNote('ch18_contract', 'নতুন pipeline');
      await c.toggleBookmark('ch18_contract');
      await c.toggleComplete('ch18_contract');
      await c.visit('ch18_transfer');
      await c.resetQuiz();
      expect(c.answers, isEmpty);
      for (final ch in previous) {
        await c.selectChapter(ch.id);
        expect(c.score, 1);
        expect(c.completedCount, 1);
        expect(c.note(ch.lessons.first.id), 'Saved chapter ${ch.number}');
        expect(c.bookmarked(ch.lessons.first.id), isTrue);
        expect(
          (await repo.exercise(ch.exercises.first.id))?['draft'],
          'Draft chapter ${ch.number}',
        );
      }
      await c.selectChapter('chapter_18');
      c.dispose();
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final reopened = LearningController(repo);
      await reopened.load();
      expect(reopened.chapter.id, 'chapter_18');
      expect(reopened.nextLesson.id, 'ch18_transfer');
      expect(reopened.note('ch18_contract'), 'নতুন pipeline');
      expect(reopened.completedCount, 1);
      reopened.dispose();
    },
  );
  test(
    'Chapter 19 upgrade and quiz retry preserve all previous learner state',
    () async {
      await repo.db.delete(
        'chapters',
        where: 'id = ?',
        whereArgs: ['chapter_19'],
      );
      final previous = (await repo.chapters())
          .where((c) => c.number <= 18)
          .toList();
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
      await repo.setSetting('selected_chapter', 'chapter_18');
      await repo.setSetting('last_lesson:chapter_18', 'ch18_transfer');
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final c = LearningController(repo);
      await c.load();
      expect(c.chapters.length, 50);
      expect(c.chapter.id, 'chapter_18');
      expect(c.nextLesson.id, 'ch18_transfer');
      await c.selectChapter('chapter_19');
      expect(c.answers, isEmpty);
      expect(c.completedCount, 0);
      await c.answer('ch19_q1', 1);
      await c.saveNote('ch19_contract', 'নতুন pipeline');
      await c.toggleBookmark('ch19_contract');
      await c.toggleComplete('ch19_contract');
      await c.visit('ch19_evaluation');
      await c.resetQuiz();
      expect(c.answers, isEmpty);
      for (final ch in previous) {
        await c.selectChapter(ch.id);
        expect(c.score, 1);
        expect(c.completedCount, 1);
        expect(c.note(ch.lessons.first.id), 'Saved chapter ${ch.number}');
        expect(c.bookmarked(ch.lessons.first.id), isTrue);
        expect(
          (await repo.exercise(ch.exercises.first.id))?['draft'],
          'Draft chapter ${ch.number}',
        );
      }
      await c.selectChapter('chapter_19');
      c.dispose();
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final reopened = LearningController(repo);
      await reopened.load();
      expect(reopened.chapter.id, 'chapter_19');
      expect(reopened.nextLesson.id, 'ch19_evaluation');
      expect(reopened.note('ch19_contract'), 'নতুন pipeline');
      expect(reopened.completedCount, 1);
      reopened.dispose();
    },
  );
  test(
    'Chapter 20 upgrade and quiz retry preserve all previous learner state',
    () async {
      await repo.db.delete(
        'chapters',
        where: 'id = ?',
        whereArgs: ['chapter_20'],
      );
      final previous = (await repo.chapters())
          .where((c) => c.number <= 19)
          .toList();
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
      await repo.setSetting('selected_chapter', 'chapter_19');
      await repo.setSetting('last_lesson:chapter_19', 'ch19_evaluation');
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final c = LearningController(repo);
      await c.load();
      expect(c.chapters.length, 50);
      expect(c.chapter.id, 'chapter_19');
      expect(c.nextLesson.id, 'ch19_evaluation');
      await c.selectChapter('chapter_20');
      expect(c.answers, isEmpty);
      expect(c.completedCount, 0);
      await c.answer('ch20_q1', 1);
      await c.saveNote('ch20_contract', 'নতুন pipeline');
      await c.toggleBookmark('ch20_contract');
      await c.toggleComplete('ch20_contract');
      await c.visit('ch20_evaluation');
      await c.resetQuiz();
      expect(c.answers, isEmpty);
      for (final ch in previous) {
        await c.selectChapter(ch.id);
        expect(c.score, 1);
        expect(c.completedCount, 1);
        expect(c.note(ch.lessons.first.id), 'Saved chapter ${ch.number}');
        expect(c.bookmarked(ch.lessons.first.id), isTrue);
        expect(
          (await repo.exercise(ch.exercises.first.id))?['draft'],
          'Draft chapter ${ch.number}',
        );
      }
      await c.selectChapter('chapter_20');
      c.dispose();
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final reopened = LearningController(repo);
      await reopened.load();
      expect(reopened.chapter.id, 'chapter_20');
      expect(reopened.nextLesson.id, 'ch20_evaluation');
      expect(reopened.note('ch20_contract'), 'নতুন pipeline');
      expect(reopened.completedCount, 1);
      reopened.dispose();
    },
  );
  test(
    'Chapter 21 upgrade and quiz retry preserve all previous learner state',
    () async {
      await repo.db.delete(
        'chapters',
        where: 'id = ?',
        whereArgs: ['chapter_21'],
      );
      final previous = (await repo.chapters())
          .where((c) => c.number <= 20)
          .toList();
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
      await repo.setSetting('selected_chapter', 'chapter_20');
      await repo.setSetting('last_lesson:chapter_20', 'ch20_evaluation');
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final c = LearningController(repo);
      await c.load();
      expect(c.chapters.length, 50);
      expect(c.chapter.id, 'chapter_20');
      expect(c.nextLesson.id, 'ch20_evaluation');
      await c.selectChapter('chapter_21');
      expect(c.answers, isEmpty);
      expect(c.completedCount, 0);
      await c.answer('ch21_q1', 1);
      await c.saveNote('ch21_contract', 'নতুন pipeline');
      await c.toggleBookmark('ch21_contract');
      await c.toggleComplete('ch21_contract');
      await c.visit('ch21_report');
      await c.resetQuiz();
      expect(c.answers, isEmpty);
      for (final ch in previous) {
        await c.selectChapter(ch.id);
        expect(c.score, 1);
        expect(c.completedCount, 1);
        expect(c.note(ch.lessons.first.id), 'Saved chapter ${ch.number}');
        expect(c.bookmarked(ch.lessons.first.id), isTrue);
        expect(
          (await repo.exercise(ch.exercises.first.id))?['draft'],
          'Draft chapter ${ch.number}',
        );
      }
      await c.selectChapter('chapter_21');
      c.dispose();
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final reopened = LearningController(repo);
      await reopened.load();
      expect(reopened.chapter.id, 'chapter_21');
      expect(reopened.nextLesson.id, 'ch21_report');
      expect(reopened.note('ch21_contract'), 'নতুন pipeline');
      expect(reopened.completedCount, 1);
      reopened.dispose();
    },
  );
  test(
    'Chapter 22 upgrade and quiz retry preserve all previous learner state',
    () async {
      await repo.db.delete(
        'chapters',
        where: 'id = ?',
        whereArgs: ['chapter_22'],
      );
      final previous = (await repo.chapters())
          .where((c) => c.number <= 21)
          .toList();
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
      await repo.setSetting('selected_chapter', 'chapter_21');
      await repo.setSetting('last_lesson:chapter_21', 'ch21_report');
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final c = LearningController(repo);
      await c.load();
      expect(c.chapters.length, 50);
      expect(c.chapter.id, 'chapter_21');
      expect(c.nextLesson.id, 'ch21_report');
      await c.selectChapter('chapter_22');
      expect(c.answers, isEmpty);
      expect(c.completedCount, 0);
      await c.answer('ch22_q1', 1);
      await c.saveNote('ch22_contract', 'নতুন pipeline');
      await c.toggleBookmark('ch22_contract');
      await c.toggleComplete('ch22_contract');
      await c.visit('ch22_evaluation');
      await c.resetQuiz();
      expect(c.answers, isEmpty);
      for (final ch in previous) {
        await c.selectChapter(ch.id);
        expect(c.score, 1);
        expect(c.completedCount, 1);
        expect(c.note(ch.lessons.first.id), 'Saved chapter ${ch.number}');
        expect(c.bookmarked(ch.lessons.first.id), isTrue);
        expect(
          (await repo.exercise(ch.exercises.first.id))?['draft'],
          'Draft chapter ${ch.number}',
        );
      }
      await c.selectChapter('chapter_22');
      c.dispose();
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final reopened = LearningController(repo);
      await reopened.load();
      expect(reopened.chapter.id, 'chapter_22');
      expect(reopened.nextLesson.id, 'ch22_evaluation');
      expect(reopened.note('ch22_contract'), 'নতুন pipeline');
      expect(reopened.completedCount, 1);
      reopened.dispose();
    },
  );
  test(
    'Chapter 23 upgrade and quiz retry preserve all previous learner state',
    () async {
      await repo.db.delete(
        'chapters',
        where: 'id = ?',
        whereArgs: ['chapter_23'],
      );
      final previous = (await repo.chapters())
          .where((c) => c.number <= 22)
          .toList();
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
      await repo.setSetting('selected_chapter', 'chapter_22');
      await repo.setSetting('last_lesson:chapter_22', 'ch22_evaluation');
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final c = LearningController(repo);
      await c.load();
      expect(c.chapters.length, 50);
      expect(c.chapter.id, 'chapter_22');
      expect(c.nextLesson.id, 'ch22_evaluation');
      await c.selectChapter('chapter_23');
      expect(c.answers, isEmpty);
      expect(c.completedCount, 0);
      await c.answer('ch23_q1', 1);
      await c.saveNote('ch23_contract', 'নতুন pipeline');
      await c.toggleBookmark('ch23_contract');
      await c.toggleComplete('ch23_contract');
      await c.visit('ch23_evaluation');
      await c.resetQuiz();
      expect(c.answers, isEmpty);
      for (final ch in previous) {
        await c.selectChapter(ch.id);
        expect(c.score, 1);
        expect(c.completedCount, 1);
        expect(c.note(ch.lessons.first.id), 'Saved chapter ${ch.number}');
        expect(c.bookmarked(ch.lessons.first.id), isTrue);
        expect(
          (await repo.exercise(ch.exercises.first.id))?['draft'],
          'Draft chapter ${ch.number}',
        );
      }
      await c.selectChapter('chapter_23');
      c.dispose();
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final reopened = LearningController(repo);
      await reopened.load();
      expect(reopened.chapter.id, 'chapter_23');
      expect(reopened.nextLesson.id, 'ch23_evaluation');
      expect(reopened.note('ch23_contract'), 'নতুন pipeline');
      expect(reopened.completedCount, 1);
      reopened.dispose();
    },
  );
  test(
    'Chapter 24 upgrade and quiz retry preserve all previous learner state',
    () async {
      await repo.db.delete(
        'chapters',
        where: 'id = ?',
        whereArgs: ['chapter_24'],
      );
      final previous = (await repo.chapters())
          .where((c) => c.number <= 23)
          .toList();
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
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final c = LearningController(repo);
      await c.load();
      expect(c.chapters.length, 50);
      expect(c.chapter.id, 'chapter_23');
      expect(c.nextLesson.id, 'ch23_evaluation');
      await c.selectChapter('chapter_24');
      expect(c.answers, isEmpty);
      expect(c.completedCount, 0);
      await c.answer('ch24_q1', 1);
      await c.saveNote('ch24_contract', 'নতুন pipeline');
      await c.toggleBookmark('ch24_contract');
      await c.toggleComplete('ch24_contract');
      await c.visit('ch24_evaluation');
      await c.resetQuiz();
      expect(c.answers, isEmpty);
      for (final ch in previous) {
        await c.selectChapter(ch.id);
        expect(c.score, 1);
        expect(c.completedCount, 1);
        expect(c.note(ch.lessons.first.id), 'Saved chapter ${ch.number}');
        expect(c.bookmarked(ch.lessons.first.id), isTrue);
        expect(
          (await repo.exercise(ch.exercises.first.id))?['draft'],
          'Draft chapter ${ch.number}',
        );
      }
      await c.selectChapter('chapter_24');
      c.dispose();
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final reopened = LearningController(repo);
      await reopened.load();
      expect(reopened.chapter.id, 'chapter_24');
      expect(reopened.nextLesson.id, 'ch24_evaluation');
      expect(reopened.note('ch24_contract'), 'নতুন pipeline');
      expect(reopened.completedCount, 1);
      reopened.dispose();
    },
  );
  test(
    'Chapter 25 upgrade and quiz retry preserve all previous learner state',
    () async {
      await repo.db.delete(
        'chapters',
        where: 'id = ?',
        whereArgs: ['chapter_25'],
      );
      final previous = (await repo.chapters())
          .where((c) => c.number <= 24)
          .toList();
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
      await repo.setSetting('selected_chapter', 'chapter_24');
      await repo.setSetting('last_lesson:chapter_24', 'ch24_evaluation');
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final c = LearningController(repo);
      await c.load();
      expect(c.chapters.length, 50);
      expect(c.chapter.id, 'chapter_24');
      expect(c.nextLesson.id, 'ch24_evaluation');
      await c.selectChapter('chapter_25');
      expect(c.answers, isEmpty);
      expect(c.completedCount, 0);
      await c.answer('ch25_q1', 1);
      await c.saveNote('ch25_contract', 'নতুন pipeline');
      await c.toggleBookmark('ch25_contract');
      await c.toggleComplete('ch25_contract');
      await c.visit('ch25_evaluation');
      await c.resetQuiz();
      expect(c.answers, isEmpty);
      for (final ch in previous) {
        await c.selectChapter(ch.id);
        expect(c.score, 1);
        expect(c.completedCount, 1);
        expect(c.note(ch.lessons.first.id), 'Saved chapter ${ch.number}');
        expect(c.bookmarked(ch.lessons.first.id), isTrue);
        expect(
          (await repo.exercise(ch.exercises.first.id))?['draft'],
          'Draft chapter ${ch.number}',
        );
      }
      await c.selectChapter('chapter_25');
      c.dispose();
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final reopened = LearningController(repo);
      await reopened.load();
      expect(reopened.chapter.id, 'chapter_25');
      expect(reopened.nextLesson.id, 'ch25_evaluation');
      expect(reopened.note('ch25_contract'), 'নতুন pipeline');
      expect(reopened.completedCount, 1);
      reopened.dispose();
    },
  );
  test(
    'Chapter 26 upgrade and quiz retry preserve all previous learner state',
    () async {
      await repo.db.delete(
        'chapters',
        where: 'id = ?',
        whereArgs: ['chapter_26'],
      );
      final previous = (await repo.chapters())
          .where((c) => c.number <= 25)
          .toList();
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
      await repo.setSetting('selected_chapter', 'chapter_25');
      await repo.setSetting('last_lesson:chapter_25', 'ch25_evaluation');
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final c = LearningController(repo);
      await c.load();
      expect(c.chapters.length, 50);
      expect(c.chapter.id, 'chapter_25');
      expect(c.nextLesson.id, 'ch25_evaluation');
      await c.selectChapter('chapter_26');
      expect(c.answers, isEmpty);
      expect(c.completedCount, 0);
      await c.answer('ch26_q1', 1);
      await c.saveNote('ch26_contract', 'নতুন pipeline');
      await c.toggleBookmark('ch26_contract');
      await c.toggleComplete('ch26_contract');
      await c.visit('ch26_statistics');
      await c.resetQuiz();
      expect(c.answers, isEmpty);
      for (final ch in previous) {
        await c.selectChapter(ch.id);
        expect(c.score, 1);
        expect(c.completedCount, 1);
        expect(c.note(ch.lessons.first.id), 'Saved chapter ${ch.number}');
        expect(c.bookmarked(ch.lessons.first.id), isTrue);
        expect(
          (await repo.exercise(ch.exercises.first.id))?['draft'],
          'Draft chapter ${ch.number}',
        );
      }
      await c.selectChapter('chapter_26');
      c.dispose();
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final reopened = LearningController(repo);
      await reopened.load();
      expect(reopened.chapter.id, 'chapter_26');
      expect(reopened.nextLesson.id, 'ch26_statistics');
      expect(reopened.note('ch26_contract'), 'নতুন pipeline');
      expect(reopened.completedCount, 1);
      reopened.dispose();
    },
  );
  test(
    'Chapter 27 upgrade and quiz retry preserve all previous learner state',
    () async {
      await repo.db.delete(
        'chapters',
        where: 'id = ?',
        whereArgs: ['chapter_27'],
      );
      final previous = (await repo.chapters())
          .where((c) => c.number <= 26)
          .toList();
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
      await repo.setSetting('selected_chapter', 'chapter_26');
      await repo.setSetting('last_lesson:chapter_26', 'ch26_statistics');
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final c = LearningController(repo);
      await c.load();
      expect(c.chapters.length, 50);
      expect(c.chapter.id, 'chapter_26');
      expect(c.nextLesson.id, 'ch26_statistics');
      await c.selectChapter('chapter_27');
      expect(c.answers, isEmpty);
      expect(c.completedCount, 0);
      await c.answer('ch27_q1', 1);
      await c.saveNote('ch27_contract', 'নতুন pipeline');
      await c.toggleBookmark('ch27_contract');
      await c.toggleComplete('ch27_contract');
      await c.visit('ch27_evaluation');
      await c.resetQuiz();
      expect(c.answers, isEmpty);
      for (final ch in previous) {
        await c.selectChapter(ch.id);
        expect(c.score, 1);
        expect(c.completedCount, 1);
        expect(c.note(ch.lessons.first.id), 'Saved chapter ${ch.number}');
        expect(c.bookmarked(ch.lessons.first.id), isTrue);
        expect(
          (await repo.exercise(ch.exercises.first.id))?['draft'],
          'Draft chapter ${ch.number}',
        );
      }
      await c.selectChapter('chapter_27');
      c.dispose();
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final reopened = LearningController(repo);
      await reopened.load();
      expect(reopened.chapter.id, 'chapter_27');
      expect(reopened.nextLesson.id, 'ch27_evaluation');
      expect(reopened.note('ch27_contract'), 'নতুন pipeline');
      expect(reopened.completedCount, 1);
      reopened.dispose();
    },
  );
  test(
    'Chapter 28 upgrade and quiz retry preserve all previous learner state',
    () async {
      await repo.db.delete(
        'chapters',
        where: 'id = ?',
        whereArgs: ['chapter_28'],
      );
      final previous = (await repo.chapters())
          .where((c) => c.number <= 27)
          .toList();
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
      await repo.setSetting('selected_chapter', 'chapter_27');
      await repo.setSetting('last_lesson:chapter_27', 'ch27_evaluation');
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final c = LearningController(repo);
      await c.load();
      expect(c.chapters.length, 50);
      expect(c.chapter.id, 'chapter_27');
      expect(c.nextLesson.id, 'ch27_evaluation');
      await c.selectChapter('chapter_28');
      expect(c.answers, isEmpty);
      expect(c.completedCount, 0);
      await c.answer('ch28_q1', 1);
      await c.saveNote('ch28_contract', 'নতুন pipeline');
      await c.toggleBookmark('ch28_contract');
      await c.toggleComplete('ch28_contract');
      await c.visit('ch28_evaluation');
      await c.resetQuiz();
      expect(c.answers, isEmpty);
      for (final ch in previous) {
        await c.selectChapter(ch.id);
        expect(c.score, 1);
        expect(c.completedCount, 1);
        expect(c.note(ch.lessons.first.id), 'Saved chapter ${ch.number}');
        expect(c.bookmarked(ch.lessons.first.id), isTrue);
        expect(
          (await repo.exercise(ch.exercises.first.id))?['draft'],
          'Draft chapter ${ch.number}',
        );
      }
      await c.selectChapter('chapter_28');
      c.dispose();
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final reopened = LearningController(repo);
      await reopened.load();
      expect(reopened.chapter.id, 'chapter_28');
      expect(reopened.nextLesson.id, 'ch28_evaluation');
      expect(reopened.note('ch28_contract'), 'নতুন pipeline');
      expect(reopened.completedCount, 1);
      reopened.dispose();
    },
  );
  test(
    'Chapter 29 upgrade and quiz retry preserve all previous learner state',
    () async {
      await repo.db.delete(
        'chapters',
        where: 'id = ?',
        whereArgs: ['chapter_29'],
      );
      final previous = (await repo.chapters())
          .where((c) => c.number <= 28)
          .toList();
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
      await repo.setSetting('selected_chapter', 'chapter_28');
      await repo.setSetting('last_lesson:chapter_28', 'ch28_evaluation');
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final c = LearningController(repo);
      await c.load();
      expect(c.chapters.length, 50);
      expect(c.chapter.id, 'chapter_28');
      expect(c.nextLesson.id, 'ch28_evaluation');
      await c.selectChapter('chapter_29');
      expect(c.answers, isEmpty);
      expect(c.completedCount, 0);
      await c.answer('ch29_q1', 1);
      await c.saveNote('ch29_contract', 'নতুন pipeline');
      await c.toggleBookmark('ch29_contract');
      await c.toggleComplete('ch29_contract');
      await c.visit('ch29_evaluation');
      await c.resetQuiz();
      expect(c.answers, isEmpty);
      for (final ch in previous) {
        await c.selectChapter(ch.id);
        expect(c.score, 1);
        expect(c.completedCount, 1);
        expect(c.note(ch.lessons.first.id), 'Saved chapter ${ch.number}');
        expect(c.bookmarked(ch.lessons.first.id), isTrue);
        expect(
          (await repo.exercise(ch.exercises.first.id))?['draft'],
          'Draft chapter ${ch.number}',
        );
      }
      await c.selectChapter('chapter_29');
      c.dispose();
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final reopened = LearningController(repo);
      await reopened.load();
      expect(reopened.chapter.id, 'chapter_29');
      expect(reopened.nextLesson.id, 'ch29_evaluation');
      expect(reopened.note('ch29_contract'), 'নতুন pipeline');
      expect(reopened.completedCount, 1);
      reopened.dispose();
    },
  );
  test(
    'Chapter 30 upgrade and quiz retry preserve all previous learner state',
    () async {
      await repo.db.delete(
        'chapters',
        where: 'id = ?',
        whereArgs: ['chapter_30'],
      );
      final previous = (await repo.chapters())
          .where((c) => c.number <= 29)
          .toList();
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
      await repo.setSetting('selected_chapter', 'chapter_29');
      await repo.setSetting('last_lesson:chapter_29', 'ch29_evaluation');
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final c = LearningController(repo);
      await c.load();
      expect(c.chapters.length, 50);
      expect(c.chapter.id, 'chapter_29');
      expect(c.nextLesson.id, 'ch29_evaluation');
      await c.selectChapter('chapter_30');
      expect(c.answers, isEmpty);
      expect(c.completedCount, 0);
      await c.answer('ch30_q1', 1);
      await c.saveNote('ch30_contract', 'নতুন pipeline');
      await c.toggleBookmark('ch30_contract');
      await c.toggleComplete('ch30_contract');
      await c.visit('ch30_evaluation');
      await c.resetQuiz();
      expect(c.answers, isEmpty);
      for (final ch in previous) {
        await c.selectChapter(ch.id);
        expect(c.score, 1);
        expect(c.completedCount, 1);
        expect(c.note(ch.lessons.first.id), 'Saved chapter ${ch.number}');
        expect(c.bookmarked(ch.lessons.first.id), isTrue);
        expect(
          (await repo.exercise(ch.exercises.first.id))?['draft'],
          'Draft chapter ${ch.number}',
        );
      }
      await c.selectChapter('chapter_30');
      c.dispose();
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final reopened = LearningController(repo);
      await reopened.load();
      expect(reopened.chapter.id, 'chapter_30');
      expect(reopened.nextLesson.id, 'ch30_evaluation');
      expect(reopened.note('ch30_contract'), 'নতুন pipeline');
      expect(reopened.completedCount, 1);
      reopened.dispose();
    },
  );
  test(
    'Chapter 31 upgrade and quiz retry preserve all previous learner state',
    () async {
      await repo.db.delete(
        'chapters',
        where: 'id = ?',
        whereArgs: ['chapter_31'],
      );
      final previous = (await repo.chapters())
          .where((c) => c.number <= 30)
          .toList();
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
      await repo.setSetting('selected_chapter', 'chapter_30');
      await repo.setSetting('last_lesson:chapter_30', 'ch30_evaluation');
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final c = LearningController(repo);
      await c.load();
      expect(c.chapters.length, 50);
      expect(c.chapter.id, 'chapter_30');
      expect(c.nextLesson.id, 'ch30_evaluation');
      await c.selectChapter('chapter_31');
      expect(c.answers, isEmpty);
      expect(c.completedCount, 0);
      await c.answer('ch31_q1', 1);
      await c.saveNote('ch31_contract', 'নতুন pipeline');
      await c.toggleBookmark('ch31_contract');
      await c.toggleComplete('ch31_contract');
      await c.visit('ch31_evaluation');
      await c.resetQuiz();
      expect(c.answers, isEmpty);
      for (final ch in previous) {
        await c.selectChapter(ch.id);
        expect(c.score, 1);
        expect(c.completedCount, 1);
        expect(c.note(ch.lessons.first.id), 'Saved chapter ${ch.number}');
        expect(c.bookmarked(ch.lessons.first.id), isTrue);
        expect(
          (await repo.exercise(ch.exercises.first.id))?['draft'],
          'Draft chapter ${ch.number}',
        );
      }
      await c.selectChapter('chapter_31');
      c.dispose();
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final reopened = LearningController(repo);
      await reopened.load();
      expect(reopened.chapter.id, 'chapter_31');
      expect(reopened.nextLesson.id, 'ch31_evaluation');
      expect(reopened.note('ch31_contract'), 'নতুন pipeline');
      expect(reopened.completedCount, 1);
      reopened.dispose();
    },
  );
  test(
    'Chapter 32 upgrade and quiz retry preserve all previous learner state',
    () async {
      await repo.db.delete(
        'chapters',
        where: 'id = ?',
        whereArgs: ['chapter_32'],
      );
      final previous = (await repo.chapters())
          .where((c) => c.number <= 31)
          .toList();
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
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final c = LearningController(repo);
      await c.load();
      expect(c.chapters.length, 50);
      expect(c.chapter.id, 'chapter_31');
      expect(c.nextLesson.id, 'ch31_evaluation');
      await c.selectChapter('chapter_32');
      expect(c.answers, isEmpty);
      expect(c.completedCount, 0);
      await c.answer('ch32_q1', 1);
      await c.saveNote('ch32_contract', 'নতুন pipeline');
      await c.toggleBookmark('ch32_contract');
      await c.toggleComplete('ch32_contract');
      await c.visit('ch32_evaluation');
      await c.resetQuiz();
      expect(c.answers, isEmpty);
      for (final ch in previous) {
        await c.selectChapter(ch.id);
        expect(c.score, 1);
        expect(c.completedCount, 1);
        expect(c.note(ch.lessons.first.id), 'Saved chapter ${ch.number}');
        expect(c.bookmarked(ch.lessons.first.id), isTrue);
        expect(
          (await repo.exercise(ch.exercises.first.id))?['draft'],
          'Draft chapter ${ch.number}',
        );
      }
      await c.selectChapter('chapter_32');
      c.dispose();
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final reopened = LearningController(repo);
      await reopened.load();
      expect(reopened.chapter.id, 'chapter_32');
      expect(reopened.nextLesson.id, 'ch32_evaluation');
      expect(reopened.note('ch32_contract'), 'নতুন pipeline');
      expect(reopened.completedCount, 1);
      reopened.dispose();
    },
  );
  test(
    'Chapter 33 upgrade and quiz retry preserve all previous learner state',
    () async {
      await repo.db.delete(
        'chapters',
        where: 'id = ?',
        whereArgs: ['chapter_33'],
      );
      final previous = (await repo.chapters())
          .where((c) => c.number <= 32)
          .toList();
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
      await repo.setSetting('selected_chapter', 'chapter_32');
      await repo.setSetting('last_lesson:chapter_32', 'ch32_evaluation');
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final c = LearningController(repo);
      await c.load();
      expect(c.chapters.length, 50);
      expect(c.chapter.id, 'chapter_32');
      expect(c.nextLesson.id, 'ch32_evaluation');
      await c.selectChapter('chapter_33');
      expect(c.answers, isEmpty);
      expect(c.completedCount, 0);
      await c.answer('ch33_q1', 1);
      await c.saveNote('ch33_contract', 'নতুন pipeline');
      await c.toggleBookmark('ch33_contract');
      await c.toggleComplete('ch33_contract');
      await c.visit('ch33_evaluation');
      await c.resetQuiz();
      expect(c.answers, isEmpty);
      for (final ch in previous) {
        await c.selectChapter(ch.id);
        expect(c.score, 1);
        expect(c.completedCount, 1);
        expect(c.note(ch.lessons.first.id), 'Saved chapter ${ch.number}');
        expect(c.bookmarked(ch.lessons.first.id), isTrue);
        expect(
          (await repo.exercise(ch.exercises.first.id))?['draft'],
          'Draft chapter ${ch.number}',
        );
      }
      await c.selectChapter('chapter_33');
      c.dispose();
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final reopened = LearningController(repo);
      await reopened.load();
      expect(reopened.chapter.id, 'chapter_33');
      expect(reopened.nextLesson.id, 'ch33_evaluation');
      expect(reopened.note('ch33_contract'), 'নতুন pipeline');
      expect(reopened.completedCount, 1);
      reopened.dispose();
    },
  );
  test(
    'Chapter 34 upgrade and quiz retry preserve all previous learner state',
    () async {
      await repo.db.delete(
        'chapters',
        where: 'id = ?',
        whereArgs: ['chapter_34'],
      );
      final previous = (await repo.chapters())
          .where((c) => c.number <= 33)
          .toList();
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
      await repo.setSetting('selected_chapter', 'chapter_33');
      await repo.setSetting('last_lesson:chapter_33', 'ch33_evaluation');
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final c = LearningController(repo);
      await c.load();
      expect(c.chapters.length, 50);
      expect(c.chapter.id, 'chapter_33');
      expect(c.nextLesson.id, 'ch33_evaluation');
      await c.selectChapter('chapter_34');
      expect(c.answers, isEmpty);
      expect(c.completedCount, 0);
      await c.answer('ch34_q1', 1);
      await c.saveNote('ch34_contract', 'নতুন pipeline');
      await c.toggleBookmark('ch34_contract');
      await c.toggleComplete('ch34_contract');
      await c.visit('ch34_evaluation');
      await c.resetQuiz();
      expect(c.answers, isEmpty);
      for (final ch in previous) {
        await c.selectChapter(ch.id);
        expect(c.score, 1);
        expect(c.completedCount, 1);
        expect(c.note(ch.lessons.first.id), 'Saved chapter ${ch.number}');
        expect(c.bookmarked(ch.lessons.first.id), isTrue);
        expect(
          (await repo.exercise(ch.exercises.first.id))?['draft'],
          'Draft chapter ${ch.number}',
        );
      }
      await c.selectChapter('chapter_34');
      c.dispose();
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final reopened = LearningController(repo);
      await reopened.load();
      expect(reopened.chapter.id, 'chapter_34');
      expect(reopened.nextLesson.id, 'ch34_evaluation');
      expect(reopened.note('ch34_contract'), 'নতুন pipeline');
      expect(reopened.completedCount, 1);
      reopened.dispose();
    },
  );
  test(
    'Chapter 35 upgrade and quiz retry preserve all previous learner state',
    () async {
      await repo.db.delete(
        'chapters',
        where: 'id = ?',
        whereArgs: ['chapter_35'],
      );
      final previous = (await repo.chapters())
          .where((c) => c.number <= 34)
          .toList();
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
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final c = LearningController(repo);
      await c.load();
      expect(c.chapters.length, 50);
      expect(c.chapter.id, 'chapter_34');
      expect(c.nextLesson.id, 'ch34_evaluation');
      await c.selectChapter('chapter_35');
      expect(c.answers, isEmpty);
      expect(c.completedCount, 0);
      await c.answer('ch35_q1', 1);
      await c.saveNote('ch35_contract', 'নতুন pipeline');
      await c.toggleBookmark('ch35_contract');
      await c.toggleComplete('ch35_contract');
      await c.visit('ch35_evaluation');
      await c.resetQuiz();
      expect(c.answers, isEmpty);
      for (final ch in previous) {
        await c.selectChapter(ch.id);
        expect(c.score, 1);
        expect(c.completedCount, 1);
        expect(c.note(ch.lessons.first.id), 'Saved chapter ${ch.number}');
        expect(c.bookmarked(ch.lessons.first.id), isTrue);
        expect(
          (await repo.exercise(ch.exercises.first.id))?['draft'],
          'Draft chapter ${ch.number}',
        );
      }
      await c.selectChapter('chapter_35');
      c.dispose();
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final reopened = LearningController(repo);
      await reopened.load();
      expect(reopened.chapter.id, 'chapter_35');
      expect(reopened.nextLesson.id, 'ch35_evaluation');
      expect(reopened.note('ch35_contract'), 'নতুন pipeline');
      expect(reopened.completedCount, 1);
      reopened.dispose();
    },
  );
  test(
    'Chapter 36 upgrade and quiz retry preserve all previous learner state',
    () async {
      await repo.db.delete(
        'chapters',
        where: 'id = ?',
        whereArgs: ['chapter_36'],
      );
      final previous = (await repo.chapters())
          .where((c) => c.number <= 35)
          .toList();
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
      await repo.setSetting('selected_chapter', 'chapter_35');
      await repo.setSetting('last_lesson:chapter_35', 'ch35_evaluation');
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final c = LearningController(repo);
      await c.load();
      expect(c.chapters.length, 50);
      expect(c.chapter.id, 'chapter_35');
      expect(c.nextLesson.id, 'ch35_evaluation');
      await c.selectChapter('chapter_36');
      expect(c.answers, isEmpty);
      expect(c.completedCount, 0);
      await c.answer('ch36_q1', 1);
      await c.saveNote('ch36_contract', 'নতুন pipeline');
      await c.toggleBookmark('ch36_contract');
      await c.toggleComplete('ch36_contract');
      await c.visit('ch36_evaluation');
      await c.resetQuiz();
      expect(c.answers, isEmpty);
      for (final ch in previous) {
        await c.selectChapter(ch.id);
        expect(c.score, 1);
        expect(c.completedCount, 1);
        expect(c.note(ch.lessons.first.id), 'Saved chapter ${ch.number}');
        expect(c.bookmarked(ch.lessons.first.id), isTrue);
        expect(
          (await repo.exercise(ch.exercises.first.id))?['draft'],
          'Draft chapter ${ch.number}',
        );
      }
      await c.selectChapter('chapter_36');
      c.dispose();
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final reopened = LearningController(repo);
      await reopened.load();
      expect(reopened.chapter.id, 'chapter_36');
      expect(reopened.nextLesson.id, 'ch36_evaluation');
      expect(reopened.note('ch36_contract'), 'নতুন pipeline');
      expect(reopened.completedCount, 1);
      reopened.dispose();
    },
  );
  test(
    'Chapter 37 upgrade and quiz retry preserve all previous learner state',
    () async {
      await repo.db.delete(
        'chapters',
        where: 'id = ?',
        whereArgs: ['chapter_37'],
      );
      final previous = (await repo.chapters())
          .where((c) => c.number <= 36)
          .toList();
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
      await repo.setSetting('selected_chapter', 'chapter_36');
      await repo.setSetting('last_lesson:chapter_36', 'ch36_evaluation');
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final c = LearningController(repo);
      await c.load();
      expect(c.chapters.length, 50);
      expect(c.chapter.id, 'chapter_36');
      expect(c.nextLesson.id, 'ch36_evaluation');
      await c.selectChapter('chapter_37');
      expect(c.answers, isEmpty);
      expect(c.completedCount, 0);
      await c.answer('ch37_q1', 1);
      await c.saveNote('ch37_contract', 'নতুন pipeline');
      await c.toggleBookmark('ch37_contract');
      await c.toggleComplete('ch37_contract');
      await c.visit('ch37_evaluation');
      await c.resetQuiz();
      expect(c.answers, isEmpty);
      for (final ch in previous) {
        await c.selectChapter(ch.id);
        expect(c.score, 1);
        expect(c.completedCount, 1);
        expect(c.note(ch.lessons.first.id), 'Saved chapter ${ch.number}');
        expect(c.bookmarked(ch.lessons.first.id), isTrue);
        expect(
          (await repo.exercise(ch.exercises.first.id))?['draft'],
          'Draft chapter ${ch.number}',
        );
      }
      await c.selectChapter('chapter_37');
      c.dispose();
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final reopened = LearningController(repo);
      await reopened.load();
      expect(reopened.chapter.id, 'chapter_37');
      expect(reopened.nextLesson.id, 'ch37_evaluation');
      expect(reopened.note('ch37_contract'), 'নতুন pipeline');
      expect(reopened.completedCount, 1);
      reopened.dispose();
    },
  );
  test(
    'Chapter 38 upgrade and quiz retry preserve all previous learner state',
    () async {
      await repo.db.delete(
        'chapters',
        where: 'id = ?',
        whereArgs: ['chapter_38'],
      );
      final previous = (await repo.chapters())
          .where((c) => c.number <= 37)
          .toList();
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
      await repo.setSetting('selected_chapter', 'chapter_37');
      await repo.setSetting('last_lesson:chapter_37', 'ch37_evaluation');
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final c = LearningController(repo);
      await c.load();
      expect(c.chapters.length, 50);
      expect(c.chapter.id, 'chapter_37');
      expect(c.nextLesson.id, 'ch37_evaluation');
      await c.selectChapter('chapter_38');
      expect(c.answers, isEmpty);
      expect(c.completedCount, 0);
      await c.answer('ch38_q1', 1);
      await c.saveNote('ch38_contract', 'নতুন pipeline');
      await c.toggleBookmark('ch38_contract');
      await c.toggleComplete('ch38_contract');
      await c.visit('ch38_evaluation');
      await c.resetQuiz();
      expect(c.answers, isEmpty);
      for (final ch in previous) {
        await c.selectChapter(ch.id);
        expect(c.score, 1);
        expect(c.completedCount, 1);
        expect(c.note(ch.lessons.first.id), 'Saved chapter ${ch.number}');
        expect(c.bookmarked(ch.lessons.first.id), isTrue);
        expect(
          (await repo.exercise(ch.exercises.first.id))?['draft'],
          'Draft chapter ${ch.number}',
        );
      }
      await c.selectChapter('chapter_38');
      c.dispose();
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final reopened = LearningController(repo);
      await reopened.load();
      expect(reopened.chapter.id, 'chapter_38');
      expect(reopened.nextLesson.id, 'ch38_evaluation');
      expect(reopened.note('ch38_contract'), 'নতুন pipeline');
      expect(reopened.completedCount, 1);
      reopened.dispose();
    },
  );
  test(
    'Chapter 39 upgrade and quiz retry preserve all previous learner state',
    () async {
      await repo.db.delete(
        'chapters',
        where: 'id = ?',
        whereArgs: ['chapter_39'],
      );
      final previous = (await repo.chapters())
          .where((c) => c.number <= 38)
          .toList();
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
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final c = LearningController(repo);
      await c.load();
      expect(c.chapters.length, 50);
      expect(c.chapter.id, 'chapter_38');
      expect(c.nextLesson.id, 'ch38_evaluation');
      await c.selectChapter('chapter_39');
      expect(c.answers, isEmpty);
      expect(c.completedCount, 0);
      await c.answer('ch39_q1', 1);
      await c.saveNote('ch39_contract', 'নতুন pipeline');
      await c.toggleBookmark('ch39_contract');
      await c.toggleComplete('ch39_contract');
      await c.visit('ch39_communication');
      await c.resetQuiz();
      expect(c.answers, isEmpty);
      for (final ch in previous) {
        await c.selectChapter(ch.id);
        expect(c.score, 1);
        expect(c.completedCount, 1);
        expect(c.note(ch.lessons.first.id), 'Saved chapter ${ch.number}');
        expect(c.bookmarked(ch.lessons.first.id), isTrue);
        expect(
          (await repo.exercise(ch.exercises.first.id))?['draft'],
          'Draft chapter ${ch.number}',
        );
      }
      await c.selectChapter('chapter_39');
      c.dispose();
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final reopened = LearningController(repo);
      await reopened.load();
      expect(reopened.chapter.id, 'chapter_39');
      expect(reopened.nextLesson.id, 'ch39_communication');
      expect(reopened.note('ch39_contract'), 'নতুন pipeline');
      expect(reopened.completedCount, 1);
      reopened.dispose();
    },
  );
  test(
    'Chapter 40 upgrade and quiz retry preserve all previous learner state',
    () async {
      await repo.db.delete(
        'chapters',
        where: 'id = ?',
        whereArgs: ['chapter_40'],
      );
      final previous = (await repo.chapters())
          .where((c) => c.number <= 39)
          .toList();
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
      await repo.setSetting('selected_chapter', 'chapter_39');
      await repo.setSetting('last_lesson:chapter_39', 'ch39_communication');
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final c = LearningController(repo);
      await c.load();
      expect(c.chapters.length, 50);
      expect(c.chapter.id, 'chapter_39');
      expect(c.nextLesson.id, 'ch39_communication');
      await c.selectChapter('chapter_40');
      expect(c.answers, isEmpty);
      expect(c.completedCount, 0);
      await c.answer('ch40_q1', 1);
      await c.saveNote('ch40_contract', 'নতুন pipeline');
      await c.toggleBookmark('ch40_contract');
      await c.toggleComplete('ch40_contract');
      await c.visit('ch40_defense');
      await c.resetQuiz();
      expect(c.answers, isEmpty);
      for (final ch in previous) {
        await c.selectChapter(ch.id);
        expect(c.score, 1);
        expect(c.completedCount, 1);
        expect(c.note(ch.lessons.first.id), 'Saved chapter ${ch.number}');
        expect(c.bookmarked(ch.lessons.first.id), isTrue);
        expect(
          (await repo.exercise(ch.exercises.first.id))?['draft'],
          'Draft chapter ${ch.number}',
        );
      }
      await c.selectChapter('chapter_40');
      c.dispose();
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final reopened = LearningController(repo);
      await reopened.load();
      expect(reopened.chapter.id, 'chapter_40');
      expect(reopened.nextLesson.id, 'ch40_defense');
      expect(reopened.note('ch40_contract'), 'নতুন pipeline');
      expect(reopened.completedCount, 1);
      reopened.dispose();
    },
  );
  test(
    'all learner state survives close, reopen, and content seeding',
    () async {
      await repo.updateLesson('ml_basics', completed: true);
      await repo.updateLesson('ml_basics', bookmarked: true);
      await repo.updateLesson('ml_basics', note: 'আমার প্রথম ML note');
      await repo.answer('q1', 1);
      await repo.setSetting('theme', 'dark');
      await repo.setSetting('last_lesson', 'features_labels');
      await repo.saveExercise('ex_prediction', 'return w*x+b', true);
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final c = LearningController(repo);
      await c.load();
      expect(c.completedCount, 1);
      expect(c.bookmarked('ml_basics'), isTrue);
      expect(c.note('ml_basics'), 'আমার প্রথম ML note');
      expect(c.score, 1);
      expect(c.themeMode.name, 'dark');
      expect(c.nextLesson.id, 'features_labels');
      expect((await repo.exercise('ex_prediction'))?['solved'], 1);
      c.dispose();
    },
  );
  test('lesson updates preserve other fields and quiz score resets', () async {
    final c = LearningController(repo);
    await c.load();
    await c.saveNote('ml_basics', 'Keep this');
    await c.toggleBookmark('ml_basics');
    await c.toggleComplete('ml_basics');
    await c.toggleComplete('ml_basics');
    expect(c.note('ml_basics'), 'Keep this');
    expect(c.bookmarked('ml_basics'), isTrue);
    expect(c.completedCount, 0);
    for (final q in c.chapter.quizzes) {
      await c.answer(q.id, q.answer);
    }
    expect(c.score, 10);
    await c.resetQuiz();
    expect(c.answers, isEmpty);
    expect(c.score, 0);
    expect(c.note('ml_basics'), 'Keep this');
    c.dispose();
  });
  test(
    'switching, scoped quiz retry, notes and resume persist independently',
    () async {
      final c = LearningController(repo);
      await c.load();
      await c.answer('q1', 1);
      await c.visit('features_labels');
      await c.saveNote('ml_basics', 'Chapter one note');
      await c.toggleComplete('ml_basics');
      await c.selectChapter('chapter_02');
      expect(c.answers, isEmpty);
      expect(c.completedCount, 0);
      await c.answer('ch02_q1', 2);
      await c.visit('ch02_gradients');
      await c.saveNote('ch02_geometry', 'দ্বিতীয় chapter');
      await c.toggleBookmark('ch02_geometry');
      await c.toggleComplete('ch02_geometry');
      await c.resetQuiz();
      expect(c.answers, isEmpty);
      await c.selectChapter('chapter_01');
      expect(c.score, 1);
      expect(c.answers.length, 1);
      expect(c.completedCount, 1);
      expect(c.nextLesson.id, 'features_labels');
      expect(c.note('ml_basics'), 'Chapter one note');
      await c.selectChapter('chapter_02');
      expect(c.nextLesson.id, 'ch02_gradients');
      expect(c.completedCount, 1);
      c.dispose();
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final reopened = LearningController(repo);
      await reopened.load();
      expect(reopened.chapter.id, 'chapter_02');
      expect(reopened.nextLesson.id, 'ch02_gradients');
      expect(reopened.note('ch02_geometry'), 'দ্বিতীয় chapter');
      expect(reopened.bookmarked('ch02_geometry'), isTrue);
      await reopened.selectChapter('chapter_01');
      expect(reopened.score, 1);
      reopened.dispose();
    },
  );
  test(
    'upgrading a Chapter 1 database preserves every legacy record',
    () async {
      await repo.db.delete(
        'chapters',
        where: 'id = ?',
        whereArgs: ['chapter_02'],
      );
      await repo.updateLesson(
        'ml_basics',
        completed: true,
        bookmarked: true,
        note: 'Legacy note',
      );
      await repo.answer('q1', 1);
      await repo.saveExercise('ex_prediction', 'legacy draft', true);
      await repo.setSetting('last_lesson', 'features_labels');
      await repo.setSetting('theme', 'dark');
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final c = LearningController(repo);
      await c.load();
      expect(c.chapters.length, 50);
      expect(c.chapter.id, 'chapter_01');
      expect(c.completedCount, 1);
      expect(c.bookmarked('ml_basics'), isTrue);
      expect(c.note('ml_basics'), 'Legacy note');
      expect(c.nextLesson.id, 'features_labels');
      expect(c.score, 1);
      expect((await repo.exercise('ex_prediction'))?['draft'], 'legacy draft');
      expect(c.themeMode.name, 'dark');
      c.dispose();
    },
  );
  test(
    'Chapter 3 upgrade preserves two prior chapters and scopes new quiz reset',
    () async {
      await repo.db.delete(
        'chapters',
        where: 'id = ?',
        whereArgs: ['chapter_03'],
      );
      await repo.updateLesson('ml_basics', completed: true, note: 'First');
      await repo.updateLesson(
        'ch02_workflow',
        completed: true,
        bookmarked: true,
        note: 'Second',
      );
      for (var i = 1; i <= 10; i++) {
        final second = await repo.curriculum(id: 'chapter_02');
        final q = second.quizzes[i - 1];
        await repo.answer(q.id, q.answer);
      }
      await repo.saveExercise('ch02_ex_metrics', 'old draft', true);
      await repo.setSetting('selected_chapter', 'chapter_02');
      await repo.setSetting('last_lesson:chapter_02', 'ch02_scaling');
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final c = LearningController(repo);
      await c.load();
      expect(c.chapter.id, 'chapter_02');
      expect(c.answers.length, 10);
      expect(c.chapter.quizzes.length, 16);
      expect(c.nextLesson.id, 'ch02_scaling');
      expect(c.note('ch02_workflow'), 'Second');
      expect(c.bookmarked('ch02_workflow'), isTrue);
      expect((await repo.exercise('ch02_ex_metrics'))?['draft'], 'old draft');
      await c.selectChapter('chapter_03');
      expect(c.score, 0);
      await c.answer('ch03_q1', 1);
      await c.visit('ch03_logistic');
      await c.saveNote('ch03_problem', 'তৃতীয় chapter');
      await c.toggleComplete('ch03_problem');
      await c.resetQuiz();
      expect(c.answers, isEmpty);
      await c.selectChapter('chapter_02');
      expect(c.answers.length, 10);
      await c.selectChapter('chapter_01');
      expect(c.completedCount, 1);
      expect(c.note('ml_basics'), 'First');
      await c.selectChapter('chapter_03');
      expect(c.nextLesson.id, 'ch03_logistic');
      expect(c.completedCount, 1);
      c.dispose();
      await repo.close();
      repo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/learning.db',
      );
      final reopened = LearningController(repo);
      await reopened.load();
      expect(reopened.chapter.id, 'chapter_03');
      expect(reopened.note('ch03_problem'), 'তৃতীয় chapter');
      expect(reopened.nextLesson.id, 'ch03_logistic');
      reopened.dispose();
    },
  );
}
