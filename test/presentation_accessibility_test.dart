import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/data/learning_repository.dart';
import 'package:ml_path/features/book/book_page.dart';
import 'package:ml_path/features/lessons/lesson_page.dart';
import 'package:ml_path/features/practice/practice_page.dart';
import 'package:ml_path/features/practice/quiz_page.dart';
import 'package:ml_path/features/reinforcement/bellman_lab.dart';
import 'package:ml_path/state/learning_controller.dart';
import 'package:ml_path/ui/shell.dart';
import 'package:ml_path/ui/theme.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  setUpAll(() async {
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final family in manifest) {
      final loader = FontLoader(family['family'] as String);
      for (final font in family['fonts'] as List) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }
    final monospace = File('C:/Windows/Fonts/consola.ttf');
    if (await monospace.exists()) {
      await (FontLoader('monospace')..addFont(
            Future.value(ByteData.sublistView(await monospace.readAsBytes())),
          ))
          .load();
    }
  });

  testWidgets(
    'reading, quizzes and practice remain usable at narrow widths and larger text',
    (tester) async {
      final repo = await tester.runAsync(
        () => LearningRepository.open(
          factory: databaseFactoryFfi,
          path: inMemoryDatabasePath,
        ),
      );
      final c = LearningController(repo!);
      await tester.runAsync(c.load);
      final findings = <Map<String, Object?>>[];
      final originalHandler = FlutterError.onError;
      final boundary = GlobalKey();
      addTearDown(() async {
        c.dispose();
        await repo.close();
      });
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      try {
        for (final width in [320.0, 390.0]) {
          for (final scale in [1.0, 1.6, 2.0]) {
            tester.view.physicalSize = Size(width, 844);
            tester.view.devicePixelRatio = 1;
            for (final page in [
              'home',
              'book',
              'lesson',
              'quiz',
              'summary',
              'exercise',
              'rl',
            ]) {
              final errors = <String>[];
              FlutterError.onError = (details) =>
                  errors.add(details.toString());
              await tester.runAsync(
                () => c.selectChapter(
                  page == 'lesson'
                      ? 'chapter_24'
                      : page == 'exercise'
                      ? 'chapter_23'
                      : 'chapter_41',
                ),
              );
              if (page == 'quiz' || page == 'summary') {
                await tester.runAsync(c.resetQuiz);
              }
              if (page == 'summary') {
                await tester.runAsync(() async {
                  for (final question in c.chapter.quizzes) {
                    await c.repository.answer(question.id, question.answer);
                  }
                  await c.refresh();
                });
              }
              final Widget content = switch (page) {
                'home' => LearningShell(controller: c),
                'book' => BookPage(controller: c),
                'lesson' => LessonPage(
                  controller: c,
                  lesson: c.chapter.lessons.first,
                ),
                'quiz' || 'summary' => QuizPage(controller: c),
                'exercise' => Scaffold(
                  body: SingleChildScrollView(
                    child: ExerciseCard(
                      controller: c,
                      exercise: c.chapter.exercises.first,
                    ),
                  ),
                ),
                _ => const Scaffold(
                  body: SingleChildScrollView(child: BellmanLab()),
                ),
              };
              await tester.pumpWidget(
                RepaintBoundary(
                  key: boundary,
                  child: MaterialApp(
                    debugShowCheckedModeBanner: false,
                    theme: appTheme(
                      scale == 1.6 ? Brightness.dark : Brightness.light,
                    ),
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(textScaler: TextScaler.linear(scale)),
                      child: child!,
                    ),
                    home: content,
                  ),
                ),
              );
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 80)),
              );
              await tester.pumpAndSettle();
              if (page == 'summary') {
                for (var index = 0; index < c.chapter.quizzes.length; index++) {
                  final button = find.text(
                    index == c.chapter.quizzes.length - 1
                        ? 'See results'
                        : 'Next question →',
                  );
                  await tester.ensureVisible(button);
                  await tester.pumpAndSettle();
                  await tester.tap(button);
                  await tester.pumpAndSettle();
                }
              }
              if (width == 390 && scale == 1.6) {
                final rendered =
                    boundary.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary;
                await tester.runAsync(() async {
                  final picture = await rendered.toImage(pixelRatio: 2);
                  final bytes = await picture.toByteData(
                    format: ui.ImageByteFormat.png,
                  );
                  final file = File(
                    'build/screenshots/editorial-$page-large-text.png',
                  );
                  await file.parent.create(recursive: true);
                  await file.writeAsBytes(bytes!.buffer.asUint8List());
                  picture.dispose();
                });
              }
              findings.add({
                'page': page,
                'width': width,
                'text_scale': scale,
                'theme': scale == 1.6 ? 'dark' : 'light',
                'errors': errors,
              });
              await tester.pumpWidget(const SizedBox());
            }
          }
        }
      } finally {
        FlutterError.onError = originalHandler;
      }
      await tester.runAsync(
        () => File(
          'build/editorial-layout-check.json',
        ).writeAsString(const JsonEncoder.withIndent('  ').convert(findings)),
      );
      final failures = findings
          .where((row) => (row['errors']! as List).isNotEmpty)
          .toList();
      expect(
        failures,
        isEmpty,
        reason: 'Inspect build/editorial-layout-check.json for actual layout errors.',
      );
    },
  );
}
