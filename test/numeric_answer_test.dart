import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/models/curriculum.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Exercise fixture(double expected, {double? absolute, double? relative}) =>
      Exercise.fromJson({
        'id': 'test',
        'title': 'test',
        'prompt': '',
        'starter': '',
        'solution': '',
        'explanation': '',
        'expected': expected,
        'absoluteTolerance': ?absolute,
        'relativeTolerance': ?relative,
      });

  test('all published exercise reference values pass their declared numeric contract', () async {
    final catalog = jsonDecode(
      await rootBundle.loadString('assets/content/catalog.json'),
    );
    var count = 0;
    final tinyIds = <String>[];
    for (final asset in catalog['chapters']) {
      final chapter = Curriculum.fromJson(
        jsonDecode(await rootBundle.loadString(asset)),
      );
      for (final exercise in chapter.exercises) {
        expect(
          exercise.acceptsResult(exercise.expected),
          isTrue,
          reason: exercise.id,
        );
        expect(exercise.acceptsResult(double.nan), isFalse);
        expect(exercise.acceptsResult(double.infinity), isFalse);
        if (exercise.expected != 0 && exercise.expected.abs() < .001) {
          expect(exercise.acceptsResult(0), isFalse, reason: exercise.id);
          tinyIds.add(exercise.id);
        }
        count++;
      }
    }
    expect(count, 435);
    expect(tinyIds.toSet(), {
      'ch19_ex_bptt',
      'ch23_ex_contrastive',
      'ch31_ex_bpr',
      'ch31_ex_derivative',
    });
  });

  test(
    'rounded answers promised by Chapter 2-4 prompts are accepted',
    () async {
      for (final (number, id, rounded, wrong) in [
        (2, 'ch02_ex_metrics', .667, .666),
        (3, 'ch03_ex_softmax', .333, .334),
        (4, 'ch04_ex_cyclic', .2611, .2610),
      ]) {
        final content = jsonDecode(
          await rootBundle.loadString(
            'assets/content/chapter_${number.toString().padLeft(2, '0')}.json',
          ),
        );
        final exercise = Exercise.fromJson(
          (content['exercises'] as List).firstWhere(
            (value) => value['id'] == id,
          ),
        );
        expect(exercise.acceptsResult(rounded), isTrue, reason: id);
        expect(exercise.acceptsResult(wrong), isFalse, reason: id);
        expect(exercise.acceptsResult(0), isFalse, reason: id);
      }
    },
  );

  test('absolute and relative tolerances scale, support negatives and exact counts', () {
    final small = fixture(-0.00012565978135868237);
    expect(small.acceptsResult(0), isFalse);
    expect(small.acceptsResult(small.expected + small.tolerance / 2), isTrue);
    expect(small.acceptsResult(small.expected + small.tolerance * 3), isFalse);
    expect(fixture(1e6).acceptsResult(1e6 + .5), isTrue);
    expect(fixture(1e6).acceptsResult(1e6 + 2), isFalse);
    expect(fixture(0).acceptsResult(5e-10), isTrue);
    expect(fixture(0).acceptsResult(.0001), isFalse);
    final count = fixture(10, absolute: 0, relative: 0);
    expect(count.acceptsResult(10), isTrue);
    expect(count.acceptsResult(10.00000001), isFalse);
  });

  test('invalid or overflowing grading contracts fail rather than accept everything', () {
    expect(() => fixture(double.nan), throwsFormatException);
    expect(() => fixture(1, absolute: -1), throwsFormatException);
    expect(() => fixture(1, relative: double.infinity), throwsFormatException);
    expect(() => fixture(1e308, relative: 1e308), throwsFormatException);
  });
}
