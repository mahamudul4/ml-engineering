import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/data/learning_repository.dart';
import 'package:ml_path/main.dart';
import 'package:ml_path/state/learning_controller.dart';
import 'package:ml_path/features/diffusion/diffusion_labs.dart';
import 'package:ml_path/features/diffusion/diffusion_model.dart';
import 'package:ml_path/features/lessons/lesson_page.dart';
import 'package:ml_path/features/practice/quiz_page.dart';
import 'package:ml_path/features/practice/practice_page.dart';
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
    await DiffusionAssets.load();
  });
  tearDown(() async {
    c.dispose();
    await c.repository.close();
  });
  Future<void> settleStorage(WidgetTester tester, bool Function() ready) async {
    for (var i = 0; i < 100 && !ready(); i++) {
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  for (final size in [const Size(390, 844), const Size(1440, 768)]) {
    testWidgets('Chapter 28 responsive overview and dark labs at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() => c.selectChapter('chapter_28'));
      await tester.pumpWidget(LearningApp(controller: c));
      await tester.pumpAndSettle();
      expect(
        find.text('Diffusion & Multimodal Systems\nDenoise. Align. Verify.'),
        findsOneWidget,
      );
      if (size.width < 1000) {
        expect(
          find.text('09 · Diffusion & Multimodal Systems'),
          findsOneWidget,
        );
      }
      expect(
        find.text('0 of ${c.chapter.lessons.length} completed'),
        findsOneWidget,
      );
      await tester.tap(
        find.text(size.width < 1000 ? 'Lab' : 'Interactive lab').first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Add noise. Track the signal.'), findsOneWidget);
      await tester.tap(find.byTooltip('Toggle light / dark mode'));
      await settleStorage(tester, () => c.themeMode == ThemeMode.dark);
      await tester.scrollUntilVisible(
        find.text('Align representations. Audit the shortcut.'),
        350,
        scrollable: find.byType(Scrollable).last,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('Chapter 28 mobile picker opens the first of twenty lessons', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(LearningApp(controller: c));
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const ValueKey('book-chip-llm'))),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('book-chip-llm')));
    for (var i = 0; i < 100 && c.currentBook.id != 'llm'; i++) {
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('09 · Diffusion & Multimodal Systems'),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    await Scrollable.ensureVisible(
      tester.element(find.text('09 · Diffusion & Multimodal Systems').last),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('09 · Diffusion & Multimodal Systems').last);
    await settleStorage(tester, () => c.chapter.id == 'chapter_28');
    expect(c.chapter.id, 'chapter_28');
    await tester.ensureVisible(find.text('Start learning'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start learning'));
    await tester.runAsync(() async => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pumpAndSettle();
    expect(find.text('LLMs & GenAI · Chapter 9 · Lesson 1 of 22'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  Future<void> tapControl(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('Forward noise and real image selection reset together', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: const Scaffold(
          body: SingleChildScrollView(child: ForwardNoiseLab()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Timestep: 8 / 32'), findsOneWidget);
    await tapControl(tester, find.byType(DropdownButtonFormField<int>));
    await tester.tap(find.textContaining('Digit 1 · source row').last);
    await tester.pumpAndSettle();
    expect(find.text('Real source · digit 1'), findsOneWidget);
    await tapControl(tester, find.byKey(const Key('diffusion-noise')));
    expect(find.text('Timestep: 32 / 32'), findsOneWidget);
    expect(find.textContaining('e-6 · SNR:'), findsOneWidget);
    expect(find.textContaining('Alpha bar: 0.0000'), findsNothing);
    await tapControl(tester, find.text('Reset forward noise'));
    expect(find.text('Timestep: 8 / 32'), findsOneWidget);
    expect(find.text('Real source · digit 0'), findsOneWidget);
    expect(
      tester
          .state<FormFieldState<int>>(find.byType(DropdownButtonFormField<int>))
          .value,
      0,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('CFG strength changes and resets', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: const Scaffold(
          body: SingleChildScrollView(child: ReverseSamplingLab()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Guidance: 1.0'), findsOneWidget);
    await tapControl(tester, find.byKey(const Key('diffusion-guidance')));
    expect(find.text('Guidance: 2.0'), findsOneWidget);
    await tapControl(tester, find.byKey(const Key('diffusion-steps')));
    expect(find.text('Steps: 32'), findsOneWidget);
    await tapControl(tester, find.text('Reset reverse sampling'));
    expect(find.text('Guidance: 1.0'), findsOneWidget);
    expect(find.text('Steps: 8'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Alignment temperature changes and resets', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: const Scaffold(
          body: SingleChildScrollView(child: MultimodalAlignmentLab()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Temperature: 0.10'), findsOneWidget);
    await tapControl(tester, find.byKey(const Key('diffusion-temperature')));
    expect(find.text('Temperature: 0.50'), findsOneWidget);
    await tapControl(tester, find.text('Reset alignment audit'));
    expect(find.text('Temperature: 0.10'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Chapter 28 all quiz questions show feedback and retry', (
    tester,
  ) async {
    await tester.runAsync(() => c.selectChapter('chapter_28'));
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: QuizPage(controller: c),
      ),
    );
    await tester.pumpAndSettle();
    for (final q in c.chapter.quizzes) {
      final option = find.text(q.options[q.answer]);
      await tester.ensureVisible(option);
      await tester.pumpAndSettle();
      await tester.tap(option);
      await settleStorage(tester, () => c.answers.containsKey(q.id));
      expect(find.text(q.explanation), findsOneWidget);
      final next = find.text(
        q.id == c.chapter.quizzes.last.id ? 'See results' : 'Next question →',
      );
      await tester.ensureVisible(next);
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pumpAndSettle();
    }
    final quizCount = c.chapter.quizzes.length;
    expect(find.text('$quizCount / $quizCount'), findsOneWidget);
    await tester.ensureVisible(find.text('Try again'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Try again'));
    await settleStorage(tester, () => c.answers.isEmpty);
    expect(c.answers, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'Chapter 28 saved coding scratchpad accepts the forward noise numeric check',
    (tester) async {
      await tester.runAsync(() => c.selectChapter('chapter_28'));
      final exercise = c.chapter.exercises.first;
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ExerciseCard(controller: c, exercise: exercise),
            ),
          ),
        ),
      );
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, exercise.solution);
      await tester.enterText(find.byType(TextField).last, .5.toString());
      await tester.ensureVisible(find.text('Check answer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Check answer'));
      await settleStorage(
        tester,
        () => find.text('ফল মিলেছে').evaluate().isNotEmpty,
      );
      expect(find.text('ফল মিলেছে'), findsOneWidget);
      final saved = await tester.runAsync(
        () => c.repository.exercise(exercise.id),
      );
      expect(saved?['solved'], 1);
      expect(saved?['draft'], contains('alpha_bar'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Alignment scope audit expands and resets', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: const Scaffold(
          body: SingleChildScrollView(child: MultimodalAlignmentLab()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Scope audit: hidden'), findsOneWidget);
    await tapControl(tester, find.byKey(const Key('diffusion-audit')));
    expect(find.text('Scope audit: visible'), findsOneWidget);
    await tapControl(tester, find.text('Reset alignment audit'));
    expect(find.text('Scope audit: hidden'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'all eighteen diffusion lessons render full derivations, code and labs',
    (tester) async {
      await tester.runAsync(() => c.selectChapter('chapter_28'));
      for (final lesson in c.chapter.lessons) {
        await tester.pumpWidget(
          MaterialApp(
            theme: appTheme(Brightness.light),
            home: LessonPage(
              key: ValueKey(lesson.id),
              controller: c,
              lesson: lesson,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(lesson.title), findsOneWidget);
        expect(tester.takeException(), isNull, reason: lesson.id);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
}
