import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ml_path/data/learning_repository.dart';
import 'package:ml_path/features/lessons/lesson_page.dart';
import 'package:ml_path/features/practice/practice_page.dart';
import 'package:ml_path/state/learning_controller.dart';
import 'package:ml_path/ui/theme.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('expanded book content and numeric answers work on Android', (
    tester,
  ) async {
    Future<void> ready(bool Function() condition) async {
      for (var attempt = 0; attempt < 100 && !condition(); attempt++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(condition(), isTrue);
      await tester.pumpAndSettle();
    }

    Future<void> reveal(Finder finder) async {
      await Scrollable.ensureVisible(
        tester.element(finder.first),
        alignment: .4,
      );
      await tester.pumpAndSettle();
    }

    Future<void> tap(Finder finder) async {
      FocusManager.instance.primaryFocus?.unfocus();
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      await tester.pump(const Duration(milliseconds: 500));
      await reveal(finder);
      await tester.tap(finder.first);
      await tester.pumpAndSettle();
    }

    Future<void> enterResult(String value) async {
      await tap(find.byType(TextField).last);
      await tester.enterText(find.byType(TextField).last, value);
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        value,
      );
      await tap(find.text('Check answer'));
    }

    final path = p.join(await getDatabasesPath(), 'ml_foundation_qa.db');
    await deleteDatabase(path);
    var repository = await LearningRepository.open(path: path);
    final controller = LearningController(repository);
    try {
      await controller.load();
      await controller.selectChapter('chapter_02');
      final glm = controller.chapter.lessons.firstWhere(
        (value) => value.id == 'ch02_book_glm',
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: LessonPage(
            key: ValueKey(glm.id),
            controller: controller,
            lesson: glm,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final scaler = MediaQuery.textScalerOf(
        tester.element(find.byType(LessonPage)),
      );
      expect(scaler.scale(10) / 10, greaterThanOrEqualTo(1.5));
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await reveal(find.text('Count আর rate-এর unit মিলিয়ে নিই'));
      for (final equation in tester.widgetList<Math>(find.byType(Math))) {
        expect(equation.parseError, isNull);
      }
      await binding.takeScreenshot('250-foundation-poisson');

      await controller.selectChapter('chapter_03');
      final logistic = controller.chapter.lessons.firstWhere(
        (value) => value.id == 'ch03_loss',
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.dark),
          home: LessonPage(
            key: ValueKey(logistic.id),
            controller: controller,
            lesson: logistic,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await reveal(find.text('p−y gradient কোথা থেকে এল'));
      await binding.takeScreenshot('251-foundation-chain-rule');
      final solution = logistic.blocks.last.solution!;
      expect(find.text(solution), findsNothing);
      await tap(find.text('চেষ্টা শেষে উত্তর দেখুন').last);
      expect(find.text(solution), findsOneWidget);

      await controller.selectChapter('chapter_01');
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: Scaffold(
            body: SingleChildScrollView(
              child: PracticePage(controller: controller),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tap(find.text('Interview practice'));
      await tap(
        find.byKey(const ValueKey('interview-prerequisite-ch07_chain')),
      );
      await ready(() => find.byType(LessonPage).evaluate().isNotEmpty);
      expect(find.textContaining('Chapter 7 · Lesson'), findsOneWidget);
      expect(controller.chapter.number, 1);
      await binding.takeScreenshot('253-foundation-prerequisite');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Derive Linear Regression gradients'), findsOneWidget);

      await controller.selectChapter('chapter_41');
      final policyGradient = controller.chapter.lessons.firstWhere(
        (value) => value.id == 'ch41_policy_gradient',
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.dark),
          home: LessonPage(
            key: ValueKey(policyGradient.id),
            controller: controller,
            lesson: policyGradient,
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final equation in tester.widgetList<Math>(find.byType(Math))) {
        expect(equation.parseError, isNull);
      }
      await reveal(find.text('দুই-step objective-এ বাইরের discount দেখা যায়'));
      await binding.takeScreenshot('254-release-discounted-policy-gradient');

      final cases = [
        ('chapter_02', 'ch02_ex_metrics', '0.666', '0.667'),
        ('chapter_03', 'ch03_ex_softmax', '0.334', '0.333'),
        ('chapter_04', 'ch04_ex_cyclic', '0.2610', '0.2611'),
        ('chapter_41', 'ch41_e_discounted_gradient_revision', '0.5', '0.375'),
      ];
      for (final (chapter, id, wrong, rounded) in cases) {
        await controller.selectChapter(chapter);
        final exercise = controller.chapter.exercises.firstWhere(
          (value) => value.id == id,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: appTheme(Brightness.light),
            home: Scaffold(
              body: SingleChildScrollView(
                child: ExerciseCard(
                  key: ValueKey(id),
                  controller: controller,
                  exercise: exercise,
                ),
              ),
            ),
          ),
        );
        await ready(() => find.byType(TextField).evaluate().length == 2);
        await enterResult(wrong);
        await ready(
          () => find.textContaining('ফল মেলেনি।').evaluate().isNotEmpty,
        );
        expect(find.text('ফল মিলেছে'), findsNothing);
        await enterResult(rounded);
        await ready(() => find.text('ফল মিলেছে').evaluate().isNotEmpty);
        final record = await repository.exercise(id);
        expect(record!['solved'], 1);
        await reveal(find.textContaining('সংখ্যার ফল মিলেছে।'));
        await binding.takeScreenshot('252-foundation-$id');
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
      await repository.close();
      repository = await LearningRepository.open(path: path);
      for (final (_, id, _, _) in cases) {
        expect((await repository.exercise(id))!['solved'], 1);
      }
    } finally {
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      await repository.close();
      await deleteDatabase(path);
    }
  });
}
