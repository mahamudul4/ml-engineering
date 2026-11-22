import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/data/learning_repository.dart';
import 'package:ml_path/features/book/book_page.dart';
import 'package:ml_path/features/lessons/lesson_page.dart';
import 'package:ml_path/features/practice/practice_page.dart';
import 'package:ml_path/features/reinforcement/bellman_lab.dart';
import 'package:ml_path/main.dart';
import 'package:ml_path/state/learning_controller.dart';
import 'package:ml_path/ui/rich_prose.dart';
import 'package:ml_path/ui/theme.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late LearningController c;
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
  setUp(() async {
    final repo = await LearningRepository.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    c = LearningController(repo);
    await c.load();
  });
  tearDown(() async {
    c.dispose();
    await c.repository.close();
  });

  testWidgets(
    'self-check keeps the reference solution hidden until requested',
    (tester) async {
      final lesson = c.chapter.lessons.firstWhere(
        (lesson) => lesson.id.contains('_book_'),
      );
      final answer = lesson.blocks.last.solution!;
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: LessonPage(controller: c, lesson: lesson),
        ),
      );
      await tester.pumpAndSettle();
      final answerFinder = find.byWidgetPredicate(
        (w) => w is RichProse && w.text == answer,
      );
      expect(answerFinder, findsNothing);
      await tester.ensureVisible(find.text('চেষ্টা শেষে উত্তর দেখুন'));
      await tester.tap(find.text('চেষ্টা শেষে উত্তর দেখুন'));
      await tester.pumpAndSettle();
      expect(answerFinder, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'interview prerequisite opens its source chapter and preserves the interview context',
    (tester) async {
      final originalResume = c.lastLesson;
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: Scaffold(
            body: SingleChildScrollView(child: PracticePage(controller: c)),
          ),
        ),
      );
      await tester.tap(find.text('Interview practice'));
      await tester.pumpAndSettle();
      final link = find.byKey(
        const ValueKey('interview-prerequisite-ch02_gradients'),
      );
      await tester.ensureVisible(link);
      await tester.pumpAndSettle();
      await tester.tap(link);
      for (
        var attempt = 0;
        attempt < 100 && find.byType(LessonPage).evaluate().isEmpty;
        attempt++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(
        find.text('Classical ML · Chapter 1 · Lesson 2 of 14'),
        findsOneWidget,
      );
      expect(c.chapter.number, 1);
      expect(c.lastLesson, originalResume);
      final saved = await tester.runAsync(
        () => c.repository.setting('last_lesson:chapter_02'),
      );
      expect(saved, 'ch02_gradients');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Derive Linear Regression gradients'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'lesson identity and next reading step stay stable during a chapter switch',
    (tester) async {
      final lesson = c.chapter.lessons.last;
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => LessonPage(controller: c, lesson: lesson),
                  ),
                ),
                child: const Text('Open final lesson'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open final lesson'));
      await tester.pumpAndSettle();
      await tester.runAsync(() => c.selectChapter('chapter_02'));
      await tester.pumpAndSettle();
      expect(
        find.text('ML Foundations · Chapter 1 · Lesson 8 of 8'),
        findsOneWidget,
      );
      final next = find.byKey(const ValueKey('next-reading-chapter'));
      await tester.ensureVisible(next);
      await tester.pumpAndSettle();
      await tester.tap(next);
      for (var i = 0; i < 100 && c.chapter.number != 6; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(c.chapter.number, 6);
      expect(find.byType(LessonPage), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [const Size(390, 844), const Size(1440, 900)]) {
    testWidgets('book path and dark theme render at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.dark),
          home: BookPage(controller: c),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('শুরু থেকে একটি ধারাবাহিক পথ · ৬টি স্বতন্ত্র বই'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('book-search')),
        'Kaplan',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('book-chapter_13')), findsOneWidget);
      expect(find.byKey(const ValueKey('book-chapter_01')), findsNothing);
      await tester.tap(
        find.text('Chapter 8 · Anomaly Detection & Time Series Foundations'),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Time-to-event targets: censoring ও Kaplan–Meier'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('LLM topic shows local serials and cross-part prerequisites', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: BookPage(controller: c)));
    await tester.tap(find.text('Topic Index'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Book 4 · LLMs & GenAI'));
    await tester.pumpAndSettle();
    expect(find.text('Chapter 1 · LLM Foundations'), findsOneWidget);
    expect(find.byKey(const ValueKey('book-chapter_01')), findsNothing);
    final capstone = find.byKey(const ValueKey('book-chapter_29'));
    await tester.scrollUntilVisible(
      capstone,
      260,
      scrollable: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    );
    await tester.tap(capstone);
    await tester.pumpAndSettle();
    expect(find.text('Chapter 10 · LLM/Generative AI Capstone'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'Chapter 5'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('global search opens the matching lesson across chapters', (
    tester,
  ) async {
    await tester.pumpWidget(LearningApp(controller: c));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('open-book')));
    await tester.tap(find.byKey(const ValueKey('open-book')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('book-search')), 'Kaplan');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('book-chapter_13')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.text('Time-to-event targets: censoring ও Kaplan–Meier'),
    );
    await tester.tap(
      find.text('Time-to-event targets: censoring ও Kaplan–Meier'),
    );
    for (var i = 0; i < 100 && c.chapter.number != 13; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(c.chapter.number, 13);
    expect(find.byType(LessonPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'RL controls update synchronous values and reset on environment change',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: BellmanLab()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Next Bellman sweep'));
      await tester.tap(find.text('Next Bellman sweep'));
      await tester.pumpAndSettle();
      expect(find.text('Start · V = 1.000000'), findsOneWidget);
      expect(find.text('Middle · V = 2.500000'), findsOneWidget);
      await tester.tap(find.text('Next Bellman sweep'));
      await tester.pumpAndSettle();
      expect(find.text('Start · V = 2.250000'), findsOneWidget);
      final slider = tester.widget<Slider>(
        find.byKey(const ValueKey('rl-probability')),
      );
      slider.onChanged!(0);
      await tester.pumpAndSettle();
      expect(find.text('Sweep 0'), findsOneWidget);
      expect(find.text('Terminal · V = 0.000000'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'BookPage search indexes lesson Interview Q&A blocks and LessonPage Quick Jump scrolls cleanly',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: BookPage(controller: c),
        ),
      );
      await tester.pumpAndSettle();
      // Search for a concept tag unique to our upgraded ch10_xgboost interview_qa block.
      await tester.enterText(
        find.byKey(const ValueKey('book-search')),
        'Exact vs Hist Split',
      );
      await tester.pumpAndSettle();
      final ch10Card = find.byKey(const ValueKey('book-chapter_10'));
      await tester.scrollUntilVisible(
        ch10Card,
        250,
        scrollable: find.byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        ),
      );
      expect(ch10Card, findsOneWidget);
      await tester.tap(ch10Card);
      await tester.pumpAndSettle();
      expect(find.textContaining('XGBoost'), findsWidgets);
      expect(tester.takeException(), isNull);

      // Open ch10_xgboost and tap the Quick Jump pill to Interview Q&A.
      final ch10 = c.chapters.firstWhere((ch) => ch.id == 'chapter_10');
      final xgb = ch10.lessons.firstWhere((l) => l.id == 'ch10_xgboost');
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: LessonPage(controller: c, lesson: xgb),
        ),
      );
      await tester.pumpAndSettle();
      final iqaChip = find.textContaining('Interview Q&A (');
      expect(iqaChip, findsOneWidget);
      await tester.tap(iqaChip);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Quick Navigator switches books/chapters/lessons in 2 taps and LessonPage switcher + prev/next work cleanly',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(LearningApp(controller: c));
      await tester.pumpAndSettle();
      // Open universal Quick Navigator from persistent sticky topbar breadcrumb
      await tester.tap(find.byKey(const ValueKey('topbar-quick-nav')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('quick-nav-search')), findsOneWidget);
      // Preview Book 4 (LLMs) and jump straight to chapter_22
      final llmBook = find.byKey(const ValueKey('qnav-book-llm'));
      await tester.ensureVisible(llmBook);
      await tester.tap(llmBook);
      await tester.pumpAndSettle();
      final openCh22 = find.byKey(const ValueKey('qnav-open-chapter_22'));
      await tester.ensureVisible(openCh22);
      await tester.tap(openCh22);
      for (var i = 0; i < 100 && c.chapter.id != 'chapter_22'; i++) {
        await tester.runAsync(
          () async => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(c.chapter.id, 'chapter_22');
      expect(tester.takeException(), isNull);

      // Open last lesson of chapter_22, verify Previous lesson button and AppBar lesson switcher sheet
      final lastLesson = c.chapter.lessons.last;
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: LessonPage(controller: c, lesson: lastLesson),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('prev-lesson-btn')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('lesson-switcher-trigger')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey('chapter-sheet-lesson-${c.chapter.lessons.first.id}')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(ValueKey('chapter-sheet-lesson-${c.chapter.lessons.first.id}')),
      );
      await tester.pumpAndSettle();
      expect(find.text(c.chapter.lessons.first.title), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final range in [(1, 14), (15, 29), (30, 50)]) {
    testWidgets(
      'expanded foundations and new book content render chapters ${range.$1}–${range.$2}',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        for (final chapter in c.chapters.where(
          (ch) => ch.number >= range.$1 && ch.number <= range.$2,
        )) {
          await tester.runAsync(() => c.selectChapter(chapter.id));
          for (final lesson in chapter.lessons.where(
            (l) =>
                chapter.number <= 5 ||
                l.id.contains('_book_') ||
                chapter.number >= 41 ||
                l.id.endsWith('_round') ||
                l.id == 'ch40_behavioral_mock' ||
                l.id == 'ch40_role_ready_mock',
          )) {
            await tester.pumpWidget(
              MaterialApp(
                theme: appTheme(Brightness.light),
                home: LessonPage(controller: c, lesson: lesson),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.text(lesson.title), findsOneWidget);
            expect(tester.takeException(), isNull, reason: lesson.id);
            await tester.pumpWidget(const SizedBox());
          }
        }
      },
    );
  }
}
