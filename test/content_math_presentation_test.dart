import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('every published equation parses instead of rendering an error fallback', () async {
    final catalog = jsonDecode(
      await rootBundle.loadString('assets/content/catalog.json'),
    );
    final failures = <Map<String, Object?>>[];
    var checked = 0;
    for (final asset in catalog['chapters']) {
      final chapter = jsonDecode(await rootBundle.loadString(asset as String));
      for (final lesson in chapter['lessons']) {
        final blocks = lesson['blocks'] as List;
        for (var index = 0; index < blocks.length; index++) {
          final block = blocks[index];
          if (block['type'] != 'math') continue;
          final equation = Math.tex(block['body'] as String);
          checked++;
          if (equation.parseError != null) {
            failures.add({
              'lesson': lesson['id'],
              'block': index,
              'formula': block['body'],
              'error': equation.parseError.toString(),
            });
          }
        }
      }
    }
    final codingCatalog = jsonDecode(
      await rootBundle.loadString('assets/coding/catalog.json'),
    );
    for (final packAsset in (codingCatalog['packs'] as List? ?? const [])) {
      final pack = jsonDecode(await rootBundle.loadString(packAsset as String));
      for (final problem in (pack['problems'] as List? ?? const [])) {
        final formula = (problem['mathFormula'] as String?) ?? '';
        if (formula.isEmpty) continue;
        final equation = Math.tex(formula);
        checked++;
        if (equation.parseError != null) {
          failures.add({
            'problem': problem['id'],
            'formula': formula,
            'error': equation.parseError.toString(),
          });
        }
      }
    }
    final vivaCatalog = jsonDecode(
      await rootBundle.loadString('assets/viva/catalog.json'),
    );
    for (final packAsset in (vivaCatalog['packs'] as List? ?? const [])) {
      final pack = jsonDecode(await rootBundle.loadString(packAsset as String));
      for (final q in (pack['questions'] as List? ?? const [])) {
        final formula = (q['mathFormula'] as String?) ?? '';
        if (formula.isEmpty) continue;
        final equation = Math.tex(formula);
        checked++;
        if (equation.parseError != null) {
          failures.add({
            'viva': q['id'],
            'formula': formula,
            'error': equation.parseError.toString(),
          });
        }
      }
    }
    await File('build/editorial-math-check.json').writeAsString(
      const JsonEncoder.withIndent('  ')
          .convert({'checked': checked, 'failures': failures}),
    );
    expect(
      failures,
      isEmpty,
      reason:
          'Math.tex can display an error without throwing a widget exception.',
    );
  });
}
