import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/data/learning_repository.dart';
import 'package:ml_path/main.dart';
import 'package:ml_path/state/learning_controller.dart';
import 'package:ml_path/features/generative/generative_labs.dart';
import 'package:ml_path/features/generative/generative_model.dart';
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
    await GenerativeAssets.load();
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
    testWidgets('Chapter 27 responsive overview and dark labs at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() => c.selectChapter('chapter_27'));
      await tester.pumpWidget(LearningApp(controller: c));
      await tester.pumpAndSettle();
      expect(
        find.text('Generative Models: VAE & GAN\nInfer. Sample. Diagnose.'),
        findsOneWidget,
      );
      if (size.width < 1000) {
        expect(find.text('08 · Generative Models: VAE & GAN'), findsOneWidget);
      }
      expect(
        find.text('0 of ${c.chapter.lessons.length} completed'),
        findsOneWidget,
      );
      await tester.tap(
        find.text(size.width < 1000 ? 'Lab' : 'Interactive lab').first,
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Encode uncertainty. Trace the objective.'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Toggle light / dark mode'));
      await settleStorage(tester, () => c.themeMode == ThemeMode.dark);
      await tester.scrollUntilVisible(
        find.text('Two players. Audit gradients and diversity.'),
        350,
        scrollable: find.byType(Scrollable).last,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('Chapter 27 mobile picker opens the first of eighteen lessons', (
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
      find.text('08 · Generative Models: VAE & GAN'),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    await Scrollable.ensureVisible(
      tester.element(find.text('08 · Generative Models: VAE & GAN').last),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('08 · Generative Models: VAE & GAN').last);
    await settleStorage(tester, () => c.chapter.id == 'chapter_27');
    expect(c.chapter.id, 'chapter_27');
    await tester.ensureVisible(find.text('Start learning'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start learning'));
    await tester.runAsync(() async => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pumpAndSettle();
    expect(find.text('LLMs & GenAI · Chapter 8 · Lesson 1 of 19'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  Future<void> tapControl(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('Controlled VAE epsilon changes and resets', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: const Scaffold(
          body: SingleChildScrollView(child: VaeObjectiveLab()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Epsilon control: 0.0'), findsOneWidget);
    await tapControl(tester, find.byType(DropdownButtonFormField<int>));
    await tester.tap(find.textContaining('Digit 1 · source row').last);
    await tester.pumpAndSettle();
    expect(find.text('Real source · digit 1'), findsOneWidget);
    await tapControl(tester, find.byKey(const Key('generative-epsilon')));
    expect(find.text('Epsilon control: 1.0'), findsOneWidget);
    await tapControl(tester, find.text('Reset VAE objective'));
    expect(find.text('Epsilon control: 0.0'), findsOneWidget);
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
  testWidgets('Latent decoder switches VAE to GAN and resets', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: const Scaffold(
          body: SingleChildScrollView(child: LatentSpaceLab()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Decoder: VAE'), findsOneWidget);
    await tapControl(tester, find.byKey(const Key('generative-decoder')));
    expect(find.text('Decoder: GAN'), findsOneWidget);
    await tapControl(tester, find.text('Reset latent space'));
    expect(find.text('Decoder: VAE'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('GAN saturation illustration changes and resets', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: const Scaffold(body: SingleChildScrollView(child: GanGameLab())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Illustration logit: 0.0'), findsOneWidget);
    await tapControl(tester, find.byKey(const Key('generative-logit')));
    expect(find.text('Illustration logit: -8.0'), findsOneWidget);
    await tapControl(tester, find.text('Reset adversarial game'));
    expect(find.text('Illustration logit: 0.0'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Chapter 27 all quiz questions show feedback and retry', (
    tester,
  ) async {
    await tester.runAsync(() => c.selectChapter('chapter_27'));
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
    'Chapter 27 saved coding scratchpad accepts the Gaussian KL numeric check',
    (tester) async {
      await tester.runAsync(() => c.selectChapter('chapter_27'));
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
      expect(saved?['draft'], contains('logvar'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Actual training trace expands and resets', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: const Scaffold(body: SingleChildScrollView(child: GanGameLab())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Trace: hidden'), findsOneWidget);
    await tapControl(tester, find.byKey(const Key('generative-history')));
    expect(find.text('Trace: visible'), findsOneWidget);
    await tapControl(tester, find.text('Reset adversarial game'));
    expect(find.text('Trace: hidden'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'all eighteen generative lessons render full derivations, code and labs',
    (tester) async {
      await tester.runAsync(() => c.selectChapter('chapter_27'));
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
