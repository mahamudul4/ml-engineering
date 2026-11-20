import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ml_path/features/preparation/preparation_model.dart';
import 'package:ml_path/features/evaluation/evaluation_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ml_path/data/learning_repository.dart';
import 'package:ml_path/main.dart';
import 'package:ml_path/state/learning_controller.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android offline curriculum, notes, quiz, lab, and restart', (
    tester,
  ) async {
    final location = p.join(await getDatabasesPath(), 'ml_path_integration.db');
    await deleteDatabase(location);
    var repo = await LearningRepository.open(path: location);
    var c = LearningController(repo);
    await c.load();
    await tester.pumpWidget(LearningApp(controller: c));
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await binding.takeScreenshot('01-home-mobile');
    await tester.ensureVisible(find.text('Start learning'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start learning'));
    await tester.pumpAndSettle();
    expect(find.text('What is Machine Learning?'), findsOneWidget);
    await tester.tap(find.byTooltip('Write a note'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('note-field')),
      'আমি উদাহরণ থেকে pattern শিখি।',
    );
    await tester.tap(find.text('Save note'));
    await tester.pumpAndSettle();
    expect(c.note('ml_basics'), contains('pattern'));
    await tester.tap(find.byTooltip('Bookmark lesson'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Mark lesson complete'),
      450,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Mark lesson complete'));
    await tester.pumpAndSettle();
    expect(c.completedCount, 1);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lab'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Best fit'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Best fit'));
    await tester.pumpAndSettle();
    expect(find.textContaining('MSE  0.133'), findsOneWidget);
    await binding.takeScreenshot('02-regression-lab');
    await tester.tap(find.text('Practice'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Start knowledge check'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Start knowledge check'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(c.chapter.quizzes.first.options[1]));
    await tester.pumpAndSettle();
    expect(find.text('Exactly. You’ve got it!'), findsOneWidget);
    await binding.takeScreenshot('03-quiz-feedback');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Toggle light / dark mode'));
    await tester.pumpAndSettle();
    expect(c.themeMode, ThemeMode.dark);
    await tester.pumpWidget(const SizedBox());
    await repo.close();
    c.dispose();
    repo = await LearningRepository.open(path: location);
    c = LearningController(repo);
    await c.load();
    expect(c.completedCount, 1);
    expect(c.note('ml_basics'), contains('pattern'));
    expect(c.bookmarked('ml_basics'), isTrue);
    expect(c.score, 1);
    expect(c.themeMode, ThemeMode.dark);
    await tester.pumpWidget(LearningApp(controller: c));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('04-dark-home');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('02 · Linear Regression in Depth').last);
    await tester.pumpAndSettle();
    expect(c.chapter.id, 'chapter_02');
    expect(c.score, 0);
    expect(c.completedCount, 0);
    await binding.takeScreenshot('06-chapter-02-home');
    await tester.ensureVisible(find.text('Start learning'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start learning'));
    await tester.pumpAndSettle();
    expect(find.text('Chapter 2 · Lesson 1 of 14'), findsOneWidget);
    await tester.tap(find.byTooltip('Write a note'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('note-field')),
      'Gradient-এর বিপরীতে ছোট step।',
    );
    await tester.tap(find.text('Save note'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Mark lesson complete'),
      450,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Mark lesson complete'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lab'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Step ×25'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Step ×25'));
    await tester.pumpAndSettle();
    expect(find.text('25 updates'), findsOneWidget);
    await binding.takeScreenshot('07-chapter-02-optimization');
    await tester.tap(find.text('Practice'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Start knowledge check'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Start knowledge check'));
    await tester.pumpAndSettle();
    for (final question in c.chapter.quizzes) {
      await tester.ensureVisible(find.text(question.options[question.answer]));
      await tester.pumpAndSettle();
      await tester.tap(find.text(question.options[question.answer]));
      await tester.pumpAndSettle();
      final next = find.text(
        question.id == c.chapter.quizzes.last.id
            ? 'See results'
            : 'Next question →',
      );
      await tester.ensureVisible(next);
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pumpAndSettle();
    }
    expect(find.text('14 / 14'), findsOneWidget);
    await binding.takeScreenshot('08-chapter-02-quiz-results');
    await tester.ensureVisible(find.text('Try again'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(c.answers, isEmpty);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await repo.close();
    c.dispose();
    repo = await LearningRepository.open(path: location);
    c = LearningController(repo);
    await c.load();
    expect(c.chapter.id, 'chapter_02');
    expect(c.completedCount, 1);
    expect(c.note('ch02_geometry'), contains('Gradient'));
    await c.selectChapter('chapter_01');
    expect(c.score, 1);
    expect(c.completedCount, 1);
    expect(c.note('ml_basics'), contains('pattern'));
    // Keep a Chapter 2 answer while exercising Chapter 3's independent retry.
    await c.selectChapter('chapter_02');
    await c.answer('ch02_q11', 1);
    await tester.pumpWidget(LearningApp(controller: c));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('03 · Classification Fundamentals').last);
    await tester.pumpAndSettle();
    expect(c.chapter.id, 'chapter_03');
    expect(c.answers, isEmpty);
    await binding.takeScreenshot('09-chapter-03-home');
    await tester.ensureVisible(find.text('Start learning'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start learning'));
    await tester.pumpAndSettle();
    expect(find.text('Chapter 3 · Lesson 1 of 9'), findsOneWidget);
    await tester.tap(find.byTooltip('Write a note'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('note-field')),
      'Probability আর decision আলাদা।',
    );
    await tester.tap(find.text('Save note'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Bookmark lesson'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Mark lesson complete'),
      450,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Mark lesson complete'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lab'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('P(class 1) = 0.500'));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('10-chapter-03-boundary');
    await tester.scrollUntilVisible(
      find.byKey(const Key('threshold-slider')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final sliderRect = tester.getRect(
      find.byKey(const Key('threshold-slider')),
    );
    await tester.tapAt(Offset(sliderRect.right - 2, sliderRect.center.dy));
    await tester.pumpAndSettle();
    expect(find.text('Predicted positive: 0/10'), findsOneWidget);
    expect(find.text('Precision  N/A'), findsOneWidget);
    await tester.ensureVisible(
      find.text('Confusion matrix · actual rows, predicted columns'),
    );
    await tester.pumpAndSettle();
    await binding.takeScreenshot('11-chapter-03-threshold');
    await tester.tap(find.text('Practice'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Start knowledge check'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Start knowledge check'));
    await tester.pumpAndSettle();
    for (final question in c.chapter.quizzes) {
      await tester.ensureVisible(find.text(question.options[question.answer]));
      await tester.pumpAndSettle();
      await tester.tap(find.text(question.options[question.answer]));
      await tester.pumpAndSettle();
      final next = find.text(
        question.id == c.chapter.quizzes.last.id
            ? 'See results'
            : 'Next question →',
      );
      await tester.ensureVisible(next);
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pumpAndSettle();
    }
    expect(find.text('10 / 10'), findsOneWidget);
    await binding.takeScreenshot('12-chapter-03-quiz-results');
    await tester.ensureVisible(find.text('Try again'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(c.answers, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await repo.close();
    c.dispose();
    repo = await LearningRepository.open(path: location);
    c = LearningController(repo);
    await c.load();
    expect(c.chapter.id, 'chapter_03');
    expect(c.completedCount, 1);
    expect(c.note('ch03_problem'), contains('decision'));
    expect(c.bookmarked('ch03_problem'), isTrue);
    await c.selectChapter('chapter_02');
    expect(c.score, 1);
    expect(c.completedCount, 1);
    await c.selectChapter('chapter_01');
    expect(c.score, 1);
    expect(c.completedCount, 1);
    // Chapter 4: real bundle availability, saved work, both labs and 16 questions.
    await c.selectChapter('chapter_03');
    await c.answer('ch03_q1', 1);
    await tester.pumpWidget(LearningApp(controller: c));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('04 · Data Preparation & Feature Engineering').last,
    );
    await tester.pumpAndSettle();
    expect(c.chapter.id, 'chapter_04');
    expect(c.answers, isEmpty);
    expect(
      (await rootBundle.load('assets/datasets/adult/adult.data')).lengthInBytes,
      3974305,
    );
    await binding.takeScreenshot('13-chapter-04-home');
    await tester.ensureVisible(find.text('Start learning'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start learning'));
    await tester.pumpAndSettle();
    expect(find.text('Chapter 4 · Lesson 1 of 13'), findsOneWidget);
    await tester.tap(find.byTooltip('Write a note'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('note-field')),
      'Fit শুধু training partition-এ।',
    );
    await tester.tap(find.text('Save note'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Bookmark lesson'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Mark lesson complete'),
      450,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Mark lesson complete'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lab'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('holdout-slider')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    final holdoutRect = tester.getRect(find.byKey(const Key('holdout-slider')));
    await tester.tapAt(Offset(holdoutRect.right - 2, holdoutRect.center.dy));
    await tester.pumpAndSettle();
    expect(find.text('Fill  20.000'), findsOneWidget);
    expect(find.text('Mean  35.000'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('leakage-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('leakage-switch')));
    await tester.pumpAndSettle();
    expect(find.text('Fill  55.000'), findsOneWidget);
    await binding.takeScreenshot('14-chapter-04-preprocessing');
    await tester.scrollUntilVisible(
      find.byType(DropdownButtonFormField<int>),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byType(DropdownButtonFormField<UnknownPolicy>),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<UnknownPolicy>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use infrequent bucket if fitted').last);
    await tester.pumpAndSettle();
    expect(find.text('Encoded vector: [0, 1]'), findsOneWidget);
    await binding.takeScreenshot('16-chapter-04-encoding');
    await tester.tap(find.text('Practice'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Start knowledge check'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Start knowledge check'));
    await tester.pumpAndSettle();
    for (final question in c.chapter.quizzes) {
      await tester.ensureVisible(find.text(question.options[question.answer]));
      await tester.pumpAndSettle();
      await tester.tap(find.text(question.options[question.answer]));
      await tester.pumpAndSettle();
      final next = find.text(
        question.id == c.chapter.quizzes.last.id
            ? 'See results'
            : 'Next question →',
      );
      await tester.ensureVisible(next);
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pumpAndSettle();
    }
    expect(find.text('16 / 16'), findsOneWidget);
    await binding.takeScreenshot('15-chapter-04-quiz-results');
    await tester.ensureVisible(find.text('Try again'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(c.answers, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await repo.close();
    c.dispose();
    repo = await LearningRepository.open(path: location);
    c = LearningController(repo);
    await c.load();
    expect(c.chapter.id, 'chapter_04');
    expect(c.completedCount, 1);
    expect(c.note('ch04_contract'), contains('training'));
    expect(c.bookmarked('ch04_contract'), isTrue);
    for (final id in ['chapter_01', 'chapter_02', 'chapter_03']) {
      await c.selectChapter(id);
      expect(c.score, 1);
      expect(c.completedCount, 1);
    }
    // Chapter 5: constraints, conditional uncertainty, practice and persistence.
    await c.selectChapter('chapter_04');
    await c.answer('ch04_q1', 1);
    await tester.pumpWidget(LearningApp(controller: c));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('05 · Model Evaluation & Experiment Design').last,
    );
    await tester.pumpAndSettle();
    expect(c.chapter.id, 'chapter_05');
    expect(c.answers, isEmpty);
    expect(
      (await rootBundle.load('assets/datasets/adult/evaluation_workflow.py'))
          .lengthInBytes,
      greaterThan(5000),
    );
    await binding.takeScreenshot('17-chapter-05-home');
    await tester.ensureVisible(find.text('Start learning'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start learning'));
    await tester.pumpAndSettle();
    expect(find.text('Chapter 5 · Lesson 1 of 15'), findsOneWidget);
    await tester.tap(find.byTooltip('Write a note'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('note-field')),
      'Selection ও evaluation আলাদা রাখব।',
    );
    await tester.tap(find.text('Save note'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Bookmark lesson'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Mark lesson complete'),
      450,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Mark lesson complete'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lab'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byType(DropdownButtonFormField<FoldPolicy>),
      200,
      scrollable: find.byType(Scrollable).first,
    );
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
    await tester.ensureVisible(find.byKey(const Key('eval-gap')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('eval-gap')));
    await tester.pumpAndSettle();
    expect(find.text('Train 2 · validation 3'), findsOneWidget);
    expect(find.text('Future in training: no'), findsOneWidget);
    await tester.ensureVisible(find.text('Train 2 · validation 3'));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('18-chapter-05-folds');
    await tester.scrollUntilVisible(
      find.byKey(const Key('eval-confidence')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final confidenceRect = tester.getRect(
      find.byKey(const Key('eval-confidence')),
    );
    await tester.tapAt(
      Offset(confidenceRect.left + 1, confidenceRect.center.dy),
    );
    await tester.pumpAndSettle();
    expect(find.text('Percentile interval: 80%'), findsOneWidget);
    expect(find.text('Mean gain A − B: 0.075'), findsOneWidget);
    await tester.ensureVisible(
      find.text('Distribution of resampled mean differences'),
    );
    await tester.pumpAndSettle();
    await binding.takeScreenshot('19-chapter-05-bootstrap');
    await tester.tap(find.text('Practice'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Start knowledge check'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Start knowledge check'));
    await tester.pumpAndSettle();
    for (final question in c.chapter.quizzes) {
      await tester.ensureVisible(find.text(question.options[question.answer]));
      await tester.pumpAndSettle();
      await tester.tap(find.text(question.options[question.answer]));
      await tester.pumpAndSettle();
      final next = find.text(
        question.id == c.chapter.quizzes.last.id
            ? 'See results'
            : 'Next question →',
      );
      await tester.ensureVisible(next);
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pumpAndSettle();
    }
    expect(find.text('16 / 16'), findsOneWidget);
    await binding.takeScreenshot('20-chapter-05-quiz-results');
    await tester.ensureVisible(find.text('Try again'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(c.answers, isEmpty);
    await repo.saveExercise('ch05_ex_paired', 'return mean(a - b)', true);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    await repo.close();
    repo = await LearningRepository.open(path: location);
    c = LearningController(repo);
    await c.load();
    expect(c.chapter.id, 'chapter_05');
    expect(c.completedCount, 1);
    expect(c.note('ch05_contract'), contains('evaluation'));
    expect(c.bookmarked('ch05_contract'), isTrue);
    expect(
      (await repo.exercise('ch05_ex_paired'))?['draft'],
      'return mean(a - b)',
    );
    for (final id in ['chapter_01', 'chapter_02', 'chapter_03', 'chapter_04']) {
      await c.selectChapter(id);
      expect(c.score, 1);
      expect(c.completedCount, 1);
    }
    // Chapter 6: shapes, one-pass iteration, eighteen questions and a saved draft.
    await c.selectChapter('chapter_05');
    await c.answer('ch05_q1', 1);
    await tester.pumpWidget(LearningApp(controller: c));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('06 · Python Engineering for ML').last);
    await tester.pumpAndSettle();
    expect(c.chapter.id, 'chapter_06');
    expect(c.answers, isEmpty);
    expect(
      (await rootBundle.load('assets/datasets/adult/python_workflow.py'))
          .lengthInBytes,
      greaterThan(5000),
    );
    await binding.takeScreenshot('21-chapter-06-home');
    await tester.ensureVisible(find.text('Start learning'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start learning'));
    await tester.pumpAndSettle();
    expect(find.text('Chapter 6 · Lesson 1 of 15'), findsOneWidget);
    await tester.tap(find.byTooltip('Write a note'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('note-field')),
      'Shape ও row alignment আগে পরীক্ষা করব।',
    );
    await tester.tap(find.text('Save note'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Bookmark lesson'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Mark lesson complete'),
      450,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Mark lesson complete'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lab'));
    await tester.pumpAndSettle();
    expect(find.text('Output shape: (3, 3)'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('py-align')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('py-align')));
    await tester.pumpAndSettle();
    expect(find.text('Output shape: (3, 1)'), findsOneWidget);
    expect(find.text('Row-major flat output: [11, 22, 33]'), findsOneWidget);
    await tester.ensureVisible(find.text('Output shape: (3, 1)'));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('22-chapter-06-broadcasting');
    await tester.scrollUntilVisible(
      find.byKey(const Key('py-next-batch')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    for (var i = 0; i < 4; i++) {
      await tester.ensureVisible(find.byKey(const Key('py-next-batch')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('py-next-batch')));
      await tester.pumpAndSettle();
    }
    expect(find.text('Batch 4: [10]'), findsOneWidget);
    expect(find.text('Emitted: 10'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('py-drop-last')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('py-drop-last')));
    await tester.pumpAndSettle();
    for (var i = 0; i < 4; i++) {
      await tester.ensureVisible(find.byKey(const Key('py-next-batch')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('py-next-batch')));
      await tester.pumpAndSettle();
    }
    expect(find.text('Emitted: 9'), findsOneWidget);
    expect(find.text('Dropped: 1'), findsOneWidget);
    await tester.ensureVisible(find.text('Dropped: 1'));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('23-chapter-06-iterator');
    await tester.tap(find.text('Practice'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Start knowledge check'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Start knowledge check'));
    await tester.pumpAndSettle();
    for (final question in c.chapter.quizzes) {
      await tester.ensureVisible(find.text(question.options[question.answer]));
      await tester.pumpAndSettle();
      await tester.tap(find.text(question.options[question.answer]));
      await tester.pumpAndSettle();
      final next = find.text(
        question.id == c.chapter.quizzes.last.id
            ? 'See results'
            : 'Next question →',
      );
      await tester.ensureVisible(next);
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pumpAndSettle();
    }
    expect(find.text('18 / 18'), findsOneWidget);
    await binding.takeScreenshot('24-chapter-06-quiz-results');
    await tester.ensureVisible(find.text('Try again'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(c.answers, isEmpty);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Coding exercises'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coding exercises'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(TextField).first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).first,
      c.chapter.exercises.first.solution,
    );
    await tester.ensureVisible(find.byType(TextField).at(1));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), '2');
    await tester.ensureVisible(find.text('Check answer').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check answer').first);
    await tester.pumpAndSettle();
    expect(find.text('ফল মিলেছে'), findsOneWidget);
    await binding.takeScreenshot('25-chapter-06-coding');
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    await repo.close();
    repo = await LearningRepository.open(path: location);
    c = LearningController(repo);
    await c.load();
    expect(c.chapter.id, 'chapter_06');
    expect(c.completedCount, 1);
    expect(c.note('ch06_runtime'), contains('alignment'));
    expect(c.bookmarked('ch06_runtime'), isTrue);
    expect(
      (await repo.exercise('ch06_ex_mean'))?['draft'],
      contains('finite_mean'),
    );
    expect((await repo.exercise('ch06_ex_mean'))?['solved'], 1);
    for (final id in [
      'chapter_01',
      'chapter_02',
      'chapter_03',
      'chapter_04',
      'chapter_05',
    ]) {
      await c.selectChapter(id);
      expect(c.score, 1);
      expect(c.completedCount, 1);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    await repo.close();
    await deleteDatabase(location);
  });
}
