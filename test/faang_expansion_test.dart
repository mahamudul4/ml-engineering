import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/data/learning_repository.dart';
import 'package:ml_path/features/lessons/lesson_page.dart';
import 'package:ml_path/features/practice/practice_page.dart';
import 'package:ml_path/main.dart';
import 'package:ml_path/models/book_part.dart';
import 'package:ml_path/state/learning_controller.dart';
import 'package:ml_path/ui/theme.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUpAll(() async {
    for (final family in [
      'Manrope',
      'NotoSansBengali',
      'NotoSansMath',
      'NotoSans',
    ]) {
      await (FontLoader(
        family,
      )..addFont(rootBundle.load('assets/fonts/$family.ttf'))).load();
    }
  });

  late LearningController c;

  setUp(() async {
    final repo = await LearningRepository.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    c = LearningController(repo);
    await c.load();
  });

  tearDown(() async {
    await c.repository.close();
    c.dispose();
  });

  testWidgets(
    'All-Books Notebook aggregates notes across books, filters by scope and searches',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final ch1Lesson = c.chapters
          .firstWhere((ch) => ch.id == 'chapter_01')
          .lessons
          .first;
      final ch15Lesson = c.chapters
          .firstWhere((ch) => ch.id == 'chapter_15')
          .lessons
          .first;

      await tester.runAsync(() async {
        await c.saveNote(ch1Lesson.id, 'Foundations note: data leakage এড়াতে হবে।');
        await c.saveNote(ch15Lesson.id, 'Deep Learning note: Tensor stride ও Autograd।');
        await c.toggleBookmark(ch15Lesson.id);
      });

      await tester.pumpWidget(LearningApp(controller: c));
      await tester.pumpAndSettle();

      await tester.tap(find.text('My notebook'));
      await tester.pumpAndSettle();

      expect(find.text(ch1Lesson.title), findsOneWidget);
      expect(find.text(ch15Lesson.title), findsOneWidget);
      expect(
        find.text('Deep Learning note: Tensor stride ও Autograd।'),
        findsOneWidget,
      );

      // Switch scope to current chapter only (chapter_01)
      await tester.tap(find.byKey(const ValueKey('notes-scope-chapter')));
      await tester.pumpAndSettle();
      expect(find.text(ch1Lesson.title), findsOneWidget);
      expect(find.text(ch15Lesson.title), findsNothing);

      // Switch back to All Books and search
      await tester.tap(find.byKey(const ValueKey('notes-scope-all')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('notebook-search')),
        'Autograd',
      );
      await tester.pumpAndSettle();
      expect(find.text(ch1Lesson.title), findsNothing);
      expect(find.text(ch15Lesson.title), findsOneWidget);

      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'FAANG Revision Deck tracks missed quizzes and starred interviews across books',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final ch1 = c.chapters.firstWhere((ch) => ch.id == 'chapter_01');
      final q1 = ch1.quizzes.first;
      final wrongChoice = (q1.answer + 1) % q1.options.length;

      await tester.runAsync(() async {
        await c.answer(q1.id, wrongChoice);
        await c.toggleInterviewStar('chapter_15', 0);
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: Scaffold(
            body: SingleChildScrollView(child: PracticePage(controller: c)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Star chapter_01 interview 0 via UI
      await tester.tap(find.text('Interview practice'));
      await tester.pumpAndSettle();
      final starBtn = find.byKey(const ValueKey('star-interview-chapter_01-0'));
      await tester.ensureVisible(starBtn);
      await tester.pumpAndSettle();
      await tester.tap(starBtn);
      for (var i = 0; i < 50 && !c.isInterviewStarred('chapter_01', 0); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(c.isInterviewStarred('chapter_01', 0), isTrue);

      // Open Revision Deck tab
      final revTab = find.byKey(const ValueKey('practice-tab-3'));
      await tester.ensureVisible(revTab);
      await tester.pumpAndSettle();
      await tester.tap(revTab);
      await tester.pumpAndSettle();

      expect(find.byKey(ValueKey('revision-quiz-${q1.id}')), findsOneWidget);
      expect(find.text(ch1.interviews.first.title), findsOneWidget);
      final ch15 = c.chapters.firstWhere((ch) => ch.id == 'chapter_15');
      expect(find.text(ch15.interviews.first.title), findsOneWidget);

      // Answer the missed quiz question correctly inside Revision Deck
      final correctOpt = find.byKey(
        ValueKey('revision-option-${q1.id}-${q1.answer}'),
      );
      await tester.ensureVisible(correctOpt);
      await tester.pumpAndSettle();
      await tester.tap(correctOpt);
      for (var i = 0; i < 50 && c.recordedAnswer(q1.id) != q1.answer; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();

      // Resolved quiz leaves the mistake queue!
      expect(find.byKey(ValueKey('revision-quiz-${q1.id}')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'Backup JSON export and restore preserves progress, notes, quiz answers, exercises and starred interviews',
    () async {
      final ch1 = c.chapters.firstWhere((ch) => ch.id == 'chapter_01');
      final lessonId = ch1.lessons.first.id;
      final quizId = ch1.quizzes.first.id;
      final exId = ch1.exercises.first.id;

      await c.toggleComplete(lessonId);
      await c.toggleBookmark(lessonId);
      await c.saveNote(lessonId, 'FAANG backup verification note');
      await c.answer(quizId, ch1.quizzes.first.answer);
      await c.repository.saveExercise(exId, 'def solve(): return 11', true);
      await c.toggleInterviewStar('chapter_01', 0);

      final exported = await c.exportBackup();
      expect(exported, contains('ml_path_backup_v1'));
      expect(exported, contains('FAANG backup verification note'));

      // Restore into a brand-new database file
      final temp = await Directory.systemTemp.createTemp('ml_backup_restore_');
      addTearDown(() => temp.delete(recursive: true));
      final freshRepo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/restored.db',
      );
      final freshController = LearningController(freshRepo);
      addTearDown(freshRepo.close);
      addTearDown(freshController.dispose);
      await freshController.load();

      expect(freshController.completed(lessonId), isFalse);
      final summary = await freshController.importBackup(exported);
      expect(summary['progress'], 1);
      expect(summary['quiz_answers'], 1);
      expect(summary['exercises'], 1);

      expect(freshController.completed(lessonId), isTrue);
      expect(freshController.bookmarked(lessonId), isTrue);
      expect(freshController.note(lessonId), 'FAANG backup verification note');
      expect(
        freshController.recordedAnswer(quizId),
        ch1.quizzes.first.answer,
      );
      expect(freshController.isInterviewStarred('chapter_01', 0), isTrue);
      final restoredEx = await freshRepo.exercise(exId);
      expect(restoredEx?['solved'], 1);
      expect(restoredEx?['draft'], 'def solve(): return 11');
    },
  );

  testWidgets(
    'new FAANG chapters render cleanly when wired into the 50-chapter catalog',
    (tester) async {
      if (c.chapters.length < 50) return;
      final expectedBooks = {
        'chapter_44': BookPart.deepLearning,
        'chapter_45': BookPart.llm,
        'chapter_46': BookPart.llm,
        'chapter_47': BookPart.recommender,
        'chapter_48': BookPart.systems,
        'chapter_49': BookPart.systems,
        'chapter_50': BookPart.systems,
      };
      for (final entry in expectedBooks.entries) {
        final ch = c.chapters.firstWhere((item) => item.id == entry.key);
        expect(ch.bookVolume, entry.value, reason: entry.key);
        expect(ch.lessons.length, greaterThanOrEqualTo(8), reason: entry.key);
        expect(ch.quizzes.length, greaterThanOrEqualTo(10), reason: entry.key);
        expect(ch.exercises.length, greaterThanOrEqualTo(5), reason: entry.key);
        expect(
          ch.interviews.length,
          greaterThanOrEqualTo(6),
          reason: entry.key,
        );
        await tester.runAsync(() => c.selectChapter(ch.id));
        await tester.pumpWidget(
          MaterialApp(
            theme: appTheme(Brightness.light),
            home: LessonPage(controller: c, lesson: ch.lessons.first),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(ch.lessons.first.title), findsOneWidget);
        expect(tester.takeException(), isNull, reason: ch.id);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
}
