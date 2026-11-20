import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/ui/rich_prose.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('every published equation parses instead of rendering an error fallback', () async {
    final catalog = jsonDecode(
      await rootBundle.loadString('assets/content/catalog.json'),
    );
    final failures = <Map<String, Object?>>[];
    var checked = 0;

    void checkFormula(String formula, Map<String, Object?> meta) {
      final equation = Math.tex(formula);
      checked++;
      if (equation.parseError != null) {
        failures.add({
          ...meta,
          'formula': formula,
          'error': equation.parseError.toString(),
        });
      }
    }

    void checkProse(String? raw, Map<String, Object?> meta) {
      if (raw == null || raw.isEmpty) return;
      for (final expr in RichProse.extractLatexExpressions(raw)) {
        checkFormula(expr, meta);
      }
    }

    for (final asset in catalog['chapters']) {
      final chapter = jsonDecode(await rootBundle.loadString(asset as String));
      for (final lesson in chapter['lessons']) {
        final blocks = lesson['blocks'] as List;
        for (var index = 0; index < blocks.length; index++) {
          final block = blocks[index];
          final btype = (block['type'] as String?) ?? 'text';
          if (btype == 'math') {
            checkFormula(block['body'] as String, {
              'lesson': lesson['id'],
              'block': index,
            });
          } else if (btype == 'text' ||
              btype == 'callout' ||
              btype == 'checkpoint') {
            checkProse(block['body'] as String?, {
              'lesson': lesson['id'],
              'block': index,
              'field': 'body',
            });
            if (btype == 'checkpoint') {
              checkProse(block['solution'] as String?, {
                'lesson': lesson['id'],
                'block': index,
                'field': 'solution',
              });
            }
          }
        }
      }
      final interviews = (chapter['interviews'] as List?) ?? const [];
      for (var i = 0; i < interviews.length; i++) {
        final iv = interviews[i] as Map<String, dynamic>;
        checkProse(iv['prompt'] as String?, {
          'chapter': chapter['id'],
          'interview': i,
          'field': 'prompt',
        });
        checkProse(iv['answer'] as String?, {
          'chapter': chapter['id'],
          'interview': i,
          'field': 'answer',
        });
      }
    }
    final codingCatalog = jsonDecode(
      await rootBundle.loadString('assets/coding/catalog.json'),
    );
    for (final packAsset in (codingCatalog['packs'] as List? ?? const [])) {
      final pack = jsonDecode(await rootBundle.loadString(packAsset as String));
      for (final problem in (pack['problems'] as List? ?? const [])) {
        final formula = (problem['mathFormula'] as String?) ?? '';
        if (formula.isNotEmpty) {
          checkFormula(formula, {'problem': problem['id']});
        }
        checkProse(problem['problemStatement'] as String?, {
          'problem': problem['id'],
          'field': 'problemStatement',
        });
        checkProse(problem['walkthrough'] as String?, {
          'problem': problem['id'],
          'field': 'walkthrough',
        });
      }
    }
    final vivaCatalog = jsonDecode(
      await rootBundle.loadString('assets/viva/catalog.json'),
    );
    for (final packAsset in (vivaCatalog['packs'] as List? ?? const [])) {
      final pack = jsonDecode(await rootBundle.loadString(packAsset as String));
      for (final q in (pack['questions'] as List? ?? const [])) {
        final formula = (q['mathFormula'] as String?) ?? '';
        if (formula.isNotEmpty) {
          checkFormula(formula, {'viva': q['id']});
        }
        for (final field in const [
          'elevatorAnswer',
          'coreBreakdown',
          'concreteExample',
          'comparisonTable',
          'followUpQuestion',
          'followUpAnswer',
        ]) {
          checkProse(q[field] as String?, {'viva': q['id'], 'field': field});
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
