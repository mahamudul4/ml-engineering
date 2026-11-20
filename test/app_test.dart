import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/main.dart';
import 'package:ml_path/data/learning_repository.dart';
import 'package:ml_path/state/learning_controller.dart';
import 'package:ml_path/features/practice/quiz_page.dart';
import 'package:ml_path/features/practice/practice_page.dart';
import 'package:ml_path/features/regression/advanced_regression_labs.dart';
import 'package:ml_path/features/regression/polynomial_lab.dart';
import 'package:ml_path/features/classification/classification_labs.dart';
import 'package:ml_path/features/preparation/preparation_labs.dart';
import 'package:ml_path/features/preparation/preparation_model.dart';
import 'package:ml_path/features/evaluation/evaluation_labs.dart';
import 'package:ml_path/features/evaluation/evaluation_model.dart';
import 'package:ml_path/features/python/python_labs.dart';
import 'package:ml_path/features/lessons/lesson_page.dart';
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
    final r = await LearningRepository.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    c = LearningController(r);
    await c.load();
  });
  tearDown(() async {
    await c.repository.close();
    c.dispose();
  });

  for (final size in [
    const Size(390, 844),
    const Size(820, 1180),
    const Size(1440, 1000),
  ]) {
    testWidgets('responsive home and theme at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(LearningApp(controller: c));
      await tester.pumpAndSettle();
      expect(find.text('Machine Learning\nFundamentals'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Toggle light / dark mode'));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(c.themeMode, ThemeMode.dark);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('quiz persists selection, shows feedback and advances', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: QuizPage(controller: c),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(c.chapter.quizzes.first.options[1]));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(c.answers['q1'], 1);
    expect(find.text('Exactly. You’ve got it!'), findsOneWidget);
    await tester.ensureVisible(find.text('Next question →'));
    await tester.tap(find.text('Next question →'));
    await tester.pumpAndSettle();
    expect(find.text('QUESTION 2 OF 10'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('lesson notes and completion save through actual controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: LessonPage(controller: c, lesson: c.chapter.lessons.first),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Write a note'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('note-field')),
      'আমি data থেকে pattern শিখি।',
    );
    await tester.tap(find.text('Save note'));
    for (var i = 0; i < 100 && c.note('ml_basics').isEmpty; i++) {
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(c.note('ml_basics'), 'আমি data থেকে pattern শিখি।');
    await tester.ensureVisible(find.text('Mark lesson complete'));
    await tester.tap(find.text('Mark lesson complete'));
    for (var i = 0; i < 100 && c.completedCount == 0; i++) {
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(c.completedCount, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('all quiz questions lead to a score and can be retried', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: QuizPage(controller: c),
      ),
    );
    await tester.pumpAndSettle();
    for (final q in c.chapter.quizzes) {
      expect(
        find.text(q.options[q.answer]),
        findsOneWidget,
        reason: 'Current question should be ${q.id}',
      );
      await tester.ensureVisible(find.text(q.options[q.answer]));
      await tester.pumpAndSettle();
      final option = find.ancestor(
        of: find.text(q.options[q.answer]),
        matching: find.byType(OutlinedButton),
      );
      expect(
        tester.widget<OutlinedButton>(option).onPressed,
        isNotNull,
        reason: '${q.id} must accept an answer',
      );
      await tester.tap(option);
      for (
        var attempt = 0;
        attempt < 100 && !c.answers.containsKey(q.id);
        attempt++
      ) {
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        });
        await tester.pump();
      }
      expect(c.answers[q.id], q.answer, reason: '${q.id} should finish saving');
      await tester.pumpAndSettle();
      final next = find.text(q.id == 'q10' ? 'See results' : 'Next question →');
      await tester.ensureVisible(next);
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pumpAndSettle();
    }
    expect(find.text('10 / 10'), findsOneWidget);
    await tester.ensureVisible(find.text('Try again'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Try again'));
    for (var attempt = 0; attempt < 100 && c.answers.isNotEmpty; attempt++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      });
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(c.answers, isEmpty);
    expect(find.text('QUESTION 1 OF 10'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('coding exercise checks output and saves the actual draft', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ExerciseCard(
              controller: c,
              exercise: c.chapter.exercises.first,
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).first,
      'def predict(x, w, b):\n    return w * x + b',
    );
    await tester.enterText(find.byType(TextField).last, '11');
    await tester.ensureVisible(find.text('Check answer'));
    await tester.tap(find.text('Check answer'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(find.text('ফল মিলেছে'), findsOneWidget);
    final saved = await tester.runAsync(
      () => c.repository.exercise('ex_prediction'),
    );
    expect(saved?['solved'], 1);
    expect(saved?['draft'], contains('return w * x + b'));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('regression lesson renders equations and interactive lab', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: LessonPage(controller: c, lesson: c.chapter.lessons[5]),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Best fit'));
    await tester.tap(find.text('Best fit'));
    await tester.pumpAndSettle();
    expect(find.text('MSE  0.133'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  for (final size in [const Size(390, 844), const Size(1440, 1000)]) {
    testWidgets('Chapter 2 responsive overview at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() => c.selectChapter('chapter_02'));
      await tester.pumpWidget(LearningApp(controller: c));
      await tester.pumpAndSettle();
      expect(find.text('Linear Regression\nin Depth'), findsOneWidget);
      expect(
        find.text('0 of ${c.chapter.lessons.length} completed'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('mobile chapter picker opens Chapter 2 and its first lesson', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(LearningApp(controller: c));
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const ValueKey('book-chip-classical'))),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('book-chip-classical')));
    for (var i = 0; i < 100 && c.currentBook.id != 'classical'; i++) {
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('01 · Linear Regression in Depth').last);
    for (var i = 0; i < 100 && c.chapter.id != 'chapter_02'; i++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      });
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(c.chapter.id, 'chapter_02');
    await tester.ensureVisible(find.text('Start learning'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start learning'));
    await tester.runAsync(() async => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pumpAndSettle();
    expect(find.text('Classical ML · Chapter 1 · Lesson 1 of 14'), findsOneWidget);
    expect(find.text('From a line to a learning problem'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'new optimizer trains, resets on scale change and stops unstable runs',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: OptimizationLab()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Step ×25'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Step ×25'));
      await tester.pumpAndSettle();
      expect(find.text('25 updates'), findsOneWidget);
      await tester.ensureVisible(find.text('Standardize training features'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Standardize training features'));
      await tester.pumpAndSettle();
      expect(find.text('0 updates'), findsOneWidget);
      await tester.ensureVisible(find.text('Step ×25'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Step ×25'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Run stopped:'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('every Chapter 2 lesson renders its math, code and lab blocks', (
    tester,
  ) async {
    await tester.runAsync(() => c.selectChapter('chapter_02'));
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
  });
  for (final size in [const Size(390, 844), const Size(1440, 768)]) {
    testWidgets('Chapter 3 overview and scrollable library at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() => c.selectChapter('chapter_03'));
      await tester.pumpWidget(LearningApp(controller: c));
      await tester.pumpAndSettle();
      expect(find.text('Classification\nFundamentals'), findsOneWidget);
      expect(
        find.text('0 of ${c.chapter.lessons.length} completed'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('Chapter 3 mobile selection opens the correct lesson', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(LearningApp(controller: c));
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const ValueKey('book-chip-classical'))),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('book-chip-classical')));
    for (var i = 0; i < 100 && c.currentBook.id != 'classical'; i++) {
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('02 · Classification Fundamentals').last);
    for (var i = 0; i < 100 && c.chapter.id != 'chapter_03'; i++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      });
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(c.chapter.id, 'chapter_03');
    await tester.ensureVisible(find.text('Start learning'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start learning'));
    await tester.runAsync(() async => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pumpAndSettle();
    expect(find.text('Classical ML · Chapter 2 · Lesson 1 of 9'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'threshold slider changes actual decisions and undefined precision',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: ThresholdLab()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('TP: 3'), findsOneWidget);
      final slider = find.byKey(const Key('threshold-slider'));
      final rect = tester.getRect(slider);
      await tester.tapAt(Offset(rect.right - 2, rect.center.dy));
      await tester.pumpAndSettle();
      expect(find.text('Predicted positive: 0/10'), findsOneWidget);
      expect(find.text('Precision  N/A'), findsOneWidget);
      await tester.ensureVisible(find.text('Reset threshold'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset threshold'));
      await tester.pumpAndSettle();
      expect(find.text('TP: 3'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('polynomial playground matches the known generating curve', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: const Scaffold(
          body: SingleChildScrollView(child: PolynomialLab()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Match toy curve'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Match toy curve'));
    await tester.pumpAndSettle();
    expect(find.text('Training MSE  0.000'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  for (final size in [const Size(390, 844), const Size(1440, 768)]) {
    testWidgets('Chapter 4 responsive overview at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() => c.selectChapter('chapter_04'));
      await tester.pumpWidget(LearningApp(controller: c));
      await tester.pumpAndSettle();
      expect(
        find.text('Data Preparation\n& Feature Engineering'),
        findsOneWidget,
      );
      expect(
        find.text('0 of ${c.chapter.lessons.length} completed'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('Chapter 4 picker opens the first of twelve lessons', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(LearningApp(controller: c));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('05 · Data Preparation & Feature Engineering').last,
    );
    for (var i = 0; i < 100 && c.chapter.id != 'chapter_04'; i++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      });
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(c.chapter.id, 'chapter_04');
    await tester.ensureVisible(find.text('Start learning'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start learning'));
    await tester.runAsync(() async => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pumpAndSettle();
    expect(find.text('ML Foundations · Chapter 5 · Lesson 1 of 13'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'preprocessing lab separates frozen fitting from intentional leakage',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: PreprocessingLab()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Fill  20.000'), findsOneWidget);
      final rect = tester.getRect(find.byKey(const Key('holdout-slider')));
      await tester.tapAt(Offset(rect.right - 2, rect.center.dy));
      await tester.pumpAndSettle();
      expect(find.text('Fill  20.000'), findsOneWidget);
      expect(find.text('Mean  35.000'), findsOneWidget);
      await tester.tap(find.byKey(const Key('leakage-switch')));
      await tester.pumpAndSettle();
      expect(find.text('Leaked recipe · 5 fit rows'), findsOneWidget);
      expect(find.text('Fill  55.000'), findsOneWidget);
      await tester.ensureVisible(find.text('Reset recipe'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset recipe'));
      await tester.pumpAndSettle();
      expect(find.text('Train-only recipe · 4 fit rows'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'encoding lab changes rare grouping while preserving fitted columns',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: EncodingLab()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Encoded vector: [0, 0, 0, 0]'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<UnknownPolicy>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use infrequent bucket if fitted').last);
      await tester.pumpAndSettle();
      expect(find.text('Encoded vector: [0, 1]'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final size in [const Size(390, 844), const Size(1440, 768)]) {
    testWidgets('Chapter 5 home and dark labs fit at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() => c.selectChapter('chapter_05'));
      await tester.pumpWidget(LearningApp(controller: c));
      await tester.pumpAndSettle();
      expect(
        find.text('Model Evaluation\n& Experiment Design'),
        findsOneWidget,
      );
      await tester.tap(
        find.text(size.width < 1000 ? 'Lab' : 'Interactive lab').first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Who gets to see the future?'), findsOneWidget);
      await tester.tap(find.byTooltip('Toggle light / dark mode'));
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('A gain is an estimate.'),
        350,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Mean gain A − B: 0.075'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('Chapter 5 mobile picker opens lesson one', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(LearningApp(controller: c));
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const ValueKey('book-chip-classical'))),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('book-chip-classical')));
    for (var i = 0; i < 100 && c.currentBook.id != 'classical'; i++) {
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('03 · Model Evaluation & Experiment Design').last,
    );
    for (var i = 0; i < 100 && c.chapter.id != 'chapter_05'; i++) {
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(c.chapter.id, 'chapter_05');
    await tester.ensureVisible(find.text('Start learning'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start learning'));
    await tester.runAsync(() async => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pumpAndSettle();
    expect(find.text('Classical ML · Chapter 3 · Lesson 1 of 15'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('fold controls expose different group and time constraints', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: const Scaffold(body: SingleChildScrollView(child: FoldLab())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Shared groups: 4'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<FoldPolicy>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Group-disjoint folds').last);
    await tester.pumpAndSettle();
    expect(find.text('Shared groups: 0'), findsOneWidget);
    expect(find.text('Future in training: yes'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<FoldPolicy>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forward time windows').last);
    await tester.pumpAndSettle();
    expect(find.text('Future in training: no'), findsOneWidget);
    expect(find.text('Shared groups: 1'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('eval-gap')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('eval-gap')));
    await tester.pumpAndSettle();
    expect(find.text('Train 2 · validation 3'), findsOneWidget);
    await tester.ensureVisible(find.text('Reset split'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset split'));
    await tester.pumpAndSettle();
    expect(find.text('Shared groups: 4'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('bootstrap controls preserve point estimate and reset settings', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: const Scaffold(
          body: SingleChildScrollView(child: BootstrapLab()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Percentile interval: 95%'), findsOneWidget);
    final rect = tester.getRect(find.byKey(const Key('eval-confidence')));
    await tester.tapAt(Offset(rect.left + 1, rect.center.dy));
    await tester.pumpAndSettle();
    expect(find.text('Percentile interval: 80%'), findsOneWidget);
    expect(find.text('Mean gain A − B: 0.075'), findsOneWidget);
    await tester.ensureVisible(find.text('Reset bootstrap'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset bootstrap'));
    await tester.pumpAndSettle();
    expect(find.text('Percentile interval: 95%'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Chapter 5 full quiz feedback, results and retry', (
    tester,
  ) async {
    await tester.runAsync(() => c.selectChapter('chapter_05'));
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
      for (
        var attempt = 0;
        attempt < 100 && !c.answers.containsKey(q.id);
        attempt++
      ) {
        await tester.runAsync(
          () async => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.text(q.explanation), findsOneWidget);
      final next = find.text(
        q == c.chapter.quizzes.last ? 'See results' : 'Next question →',
      );
      await tester.ensureVisible(next);
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pumpAndSettle();
    }
    final total = c.chapter.quizzes.length;
    expect(find.text('$total / $total'), findsOneWidget);
    await tester.ensureVisible(find.text('Try again'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Try again'));
    for (var attempt = 0; attempt < 100 && c.answers.isNotEmpty; attempt++) {
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(c.answers, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('every Chapter 5 lesson renders full code, equations and labs', (
    tester,
  ) async {
    await tester.runAsync(() => c.selectChapter('chapter_05'));
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
  });
  for (final size in [const Size(390, 844), const Size(1440, 768)]) {
    testWidgets('Chapter 6 responsive home and dark labs at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() => c.selectChapter('chapter_06'));
      await tester.pumpWidget(LearningApp(controller: c));
      await tester.pumpAndSettle();
      expect(
        find.text('Python Engineering\nfor Machine Learning'),
        findsOneWidget,
      );
      expect(
        find.text('0 of ${c.chapter.lessons.length} completed'),
        findsOneWidget,
      );
      await tester.tap(
        find.text(size.width < 1000 ? 'Lab' : 'Interactive lab').first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Output shape: (3, 3)'), findsOneWidget);
      await tester.tap(find.byTooltip('Toggle light / dark mode'));
      for (var i = 0; i < 100 && c.themeMode != ThemeMode.dark; i++) {
        await tester.runAsync(
          () async => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('One source. One pass.'),
        350,
        scrollable: find.byType(Scrollable).last,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('Chapter 6 phone picker opens lesson one of fourteen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(LearningApp(controller: c));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('02 · Python Engineering for ML').last);
    for (var i = 0; i < 100 && c.chapter.id != 'chapter_06'; i++) {
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(c.chapter.id, 'chapter_06');
    await tester.ensureVisible(find.text('Start learning'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start learning'));
    await tester.runAsync(() async => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pumpAndSettle();
    expect(find.text('ML Foundations · Chapter 2 · Lesson 1 of 15'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'broadcast controls show pairwise, aligned and incompatible shapes',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: BroadcastingLab()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Output shape: (3, 3)'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('py-align')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('py-align')));
      await tester.pumpAndSettle();
      expect(find.text('Output shape: (3, 1)'), findsOneWidget);
      expect(find.text('Row-major flat output: [11, 22, 33]'), findsOneWidget);
      await tester.ensureVisible(
        find.byType(DropdownButtonFormField<String>).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('(2,)').last);
      await tester.pumpAndSettle();
      // (3,1)+(2,) still broadcasts; force incompatible trailing 3 and 2.
      await tester.ensureVisible(
        find.byType(DropdownButtonFormField<String>).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('(3,)').last);
      await tester.pumpAndSettle();
      expect(find.text('Incompatible trailing dimensions'), findsOneWidget);
      await tester.ensureVisible(find.text('Reset shapes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset shapes'));
      await tester.pumpAndSettle();
      expect(find.text('Output shape: (3, 3)'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'iterator UI retains partial batch and explicitly drops on a fresh pass',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: IteratorLab()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var i = 0; i < 4; i++) {
        await tester.ensureVisible(find.byKey(const Key('py-next-batch')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('py-next-batch')));
        await tester.pumpAndSettle();
      }
      expect(find.text('Batch 4: [10]'), findsOneWidget);
      expect(find.text('Emitted: 10'), findsOneWidget);
      expect(find.text('Iterator exhausted'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('py-drop-last')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('py-drop-last')));
      await tester.pumpAndSettle();
      expect(find.text('No batch emitted yet.'), findsOneWidget);
      for (var i = 0; i < 4; i++) {
        await tester.ensureVisible(find.byKey(const Key('py-next-batch')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('py-next-batch')));
        await tester.pumpAndSettle();
      }
      expect(find.text('Emitted: 9'), findsOneWidget);
      expect(find.text('Dropped: 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Chapter 6 eighteen-question quiz shows feedback and retries', (
    tester,
  ) async {
    await tester.runAsync(() => c.selectChapter('chapter_06'));
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
      for (var i = 0; i < 100 && !c.answers.containsKey(q.id); i++) {
        await tester.runAsync(
          () async => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.text(q.explanation), findsOneWidget);
      final next = find.text(
        q.id == c.chapter.quizzes.last.id ? 'See results' : 'Next question →',
      );
      await tester.ensureVisible(next);
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pumpAndSettle();
    }
    expect(find.text('18 / 18'), findsOneWidget);
    await tester.ensureVisible(find.text('Try again'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Try again'));
    for (var i = 0; i < 100 && c.answers.isNotEmpty; i++) {
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(c.answers, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'Chapter 6 numeric checker saves the shape regression exercise draft',
    (tester) async {
      await tester.runAsync(() => c.selectChapter('chapter_06'));
      final exercise = c.chapter.exercises.last;
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
      await tester.enterText(
        find.byType(TextField).first,
        'with assertRaises(ValueError): checked_mse(p, y)',
      );
      await tester.enterText(find.byType(TextField).last, '1');
      await tester.ensureVisible(find.text('Check answer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Check answer'));
      for (
        var i = 0;
        i < 100 && find.text('ফল মিলেছে').evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () async => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.text('ফল মিলেছে'), findsOneWidget);
      final saved = await tester.runAsync(
        () => c.repository.exercise(exercise.id),
      );
      expect(saved?['draft'], contains('assertRaises'));
      expect(saved?['solved'], 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'all fourteen Chapter 6 lessons render code, equations and labs',
    (tester) async {
      await tester.runAsync(() => c.selectChapter('chapter_06'));
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
  testWidgets('every Chapter 4 lesson renders full code, equations and labs', (
    tester,
  ) async {
    await tester.runAsync(() => c.selectChapter('chapter_04'));
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
  });
  testWidgets(
    'every Chapter 3 lesson renders its math and interactive blocks',
    (tester) async {
      await tester.runAsync(() => c.selectChapter('chapter_03'));
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
