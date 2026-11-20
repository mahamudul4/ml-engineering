import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ml_path/data/learning_repository.dart';
import 'package:ml_path/features/lessons/horizontal_reading_view.dart';
import 'package:ml_path/features/lessons/lesson_page.dart';
import 'package:ml_path/features/practice/practice_page.dart';
import 'package:ml_path/features/practice/quiz_page.dart';
import 'package:ml_path/state/learning_controller.dart';
import 'package:ml_path/ui/theme.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native large-text equation, quiz and numeric-check presentation',
    (tester) async {
      Future<void> settle(bool Function() ready) async {
        for (var i = 0; i < 100 && !ready(); i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(ready(), isTrue);
        await tester.pumpAndSettle();
      }

      Future<void> tap(Finder finder) async {
        FocusManager.instance.primaryFocus?.unfocus();
        await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
        await tester.pump(const Duration(milliseconds: 500));
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
        'ml_editorial_presentation_qa.db',
      );
      await deleteDatabase(path);
      final repo = await LearningRepository.open(path: path);
      final c = LearningController(repo);
      await c.load();
      await c.selectChapter('chapter_13');
      final lesson = c.chapter.lessons.firstWhere(
        (lesson) => lesson.id == 'ch13_thresholds',
      );
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: LessonPage(controller: c, lesson: lesson),
        ),
      );
      await tester.pumpAndSettle();
      final scale =
          MediaQuery.textScalerOf(tester.element(find.byType(LessonPage)))
              .scale(10) /
          10;
      expect(
        scale,
        greaterThanOrEqualTo(1.5),
        reason: 'Run on the QA emulator with system font_scale=1.6',
      );
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      final equationView = find.byType(HorizontalReadingView).first;
      await Scrollable.ensureVisible(
        tester.element(equationView),
        alignment: .4,
      );
      await tester.pumpAndSettle();
      expect(tester.widget<Math>(find.byType(Math).first).parseError, isNull);
      expect(find.text('পুরো সমীকরণ দেখতে ডানে-বাঁয়ে সরান।'), findsOneWidget);
      final equationScroll = find.descendant(
        of: equationView,
        matching: find.byType(SingleChildScrollView),
      );
      await tester.drag(equationScroll, const Offset(-140, 0));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SingleChildScrollView>(equationScroll).controller!.offset,
        greaterThan(0),
      );
      await binding.takeScreenshot('240-editorial-equation-large');

      await c.selectChapter('chapter_41');
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.dark),
          home: QuizPage(controller: c),
        ),
      );
      await tester.pumpAndSettle();
      await binding.takeScreenshot('241-editorial-quiz-large');
      await tap(find.text(c.chapter.quizzes.first.options.first));
      await settle(() => c.score == 1);

      await c.selectChapter('chapter_23');
      final exercise = c.chapter.exercises.firstWhere(
        (exercise) => exercise.id == 'ch23_ex_contrastive',
      );
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ExerciseCard(controller: c, exercise: exercise),
            ),
          ),
        ),
      );
      await settle(() => find.byType(TextField).evaluate().length == 2);
      await Scrollable.ensureVisible(
        tester.element(
          find.text(
            'এখানে Python code চালানো হয় না। নিচের পরীক্ষায় শুধু সংখ্যার ফল মেলানো হয়।',
          ),
        ),
        alignment: .3,
      );
      await tester.pumpAndSettle();
      await binding.takeScreenshot('242-editorial-code-scope-large');
      await tester.enterText(find.byType(TextField).last, '0');
      await tap(find.text('Check answer'));
      await settle(
        () => find.textContaining('ফল মেলেনি।').evaluate().isNotEmpty,
      );
      expect(find.text('ফল মিলেছে'), findsNothing);
      await tap(find.byType(TextField).last);
      await tester.enterText(
        find.byType(TextField).last,
        exercise.expected.toString(),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        exercise.expected.toString(),
      );
      await tap(find.text('Check answer'));
      await binding.takeScreenshot('243-editorial-numeric-check-pending');
      await settle(() => find.text('ফল মিলেছে').evaluate().isNotEmpty);
      await binding.takeScreenshot('243-editorial-numeric-result-large');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      await repo.close();
      await deleteDatabase(path);
    },
  );
}
