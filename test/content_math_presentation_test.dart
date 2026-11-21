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
        checkProse(lesson['subtitle'] as String?, {
          'lesson': lesson['id'],
          'field': 'subtitle',
        });
        final blocks = lesson['blocks'] as List;
        for (var index = 0; index < blocks.length; index++) {
          final block = blocks[index];
          final btype = (block['type'] as String?) ?? 'text';
          if (btype == 'math') {
            checkFormula(block['body'] as String, {
              'lesson': lesson['id'],
              'block': index,
            });
            checkProse(block['lead'] as String?, {
              'lesson': lesson['id'],
              'block': index,
              'field': 'lead',
            });
            checkProse(block['note'] as String?, {
              'lesson': lesson['id'],
              'block': index,
              'field': 'note',
            });
            for (final s in (block['symbols'] as List? ?? const [])) {
              final m = s as Map<String, dynamic>;
              checkProse(m['symbol'] as String?, {
                'lesson': lesson['id'],
                'block': index,
                'field': 'symbol',
              });
              checkProse(m['meaning'] as String?, {
                'lesson': lesson['id'],
                'block': index,
                'field': 'meaning',
              });
              checkProse(m['example'] as String?, {
                'lesson': lesson['id'],
                'block': index,
                'field': 'example',
              });
            }
          } else if (btype == 'lesson_header') {
            checkProse(block['goal'] as String?, {
              'lesson': lesson['id'],
              'block': index,
              'field': 'goal',
            });
            for (final o in (block['outcomes'] as List? ?? const [])) {
              checkProse(o as String?, {
                'lesson': lesson['id'],
                'block': index,
                'field': 'outcome',
              });
            }
          } else if (btype == 'flow_diagram') {
            checkProse(block['caption'] as String?, {
              'lesson': lesson['id'],
              'block': index,
              'field': 'caption',
            });
            for (final s in (block['steps'] as List? ?? const [])) {
              final m = s as Map<String, dynamic>;
              checkProse(m['label'] as String?, {
                'lesson': lesson['id'],
                'block': index,
                'field': 'step.label',
              });
              checkProse(m['detail'] as String?, {
                'lesson': lesson['id'],
                'block': index,
                'field': 'step.detail',
              });
            }
          } else if (btype == 'concept_check') {
            checkProse(block['question'] as String?, {
              'lesson': lesson['id'],
              'block': index,
              'field': 'question',
            });
            for (final o in (block['options'] as List? ?? const [])) {
              checkProse(o as String?, {
                'lesson': lesson['id'],
                'block': index,
                'field': 'option',
              });
            }
            checkProse(block['explanation'] as String?, {
              'lesson': lesson['id'],
              'block': index,
              'field': 'explanation',
            });
          } else if (btype == 'interview_qa') {
            checkProse(block['intro'] as String?, {
              'lesson': lesson['id'],
              'block': index,
              'field': 'intro',
            });
            for (final item in (block['items'] as List? ?? const [])) {
              final m = item as Map<String, dynamic>;
              checkProse(m['question'] as String?, {
                'lesson': lesson['id'],
                'block': index,
                'field': 'interview_qa.question',
              });
              checkProse(m['answer'] as String?, {
                'lesson': lesson['id'],
                'block': index,
                'field': 'interview_qa.answer',
              });
              checkProse(m['followUp'] as String?, {
                'lesson': lesson['id'],
                'block': index,
                'field': 'interview_qa.followUp',
              });
            }
          } else if (btype != 'code') {
            checkProse(block['title'] as String?, {
              'lesson': lesson['id'],
              'block': index,
              'field': 'title',
            });
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
      final quizzes = (chapter['quizzes'] as List?) ?? const [];
      for (var i = 0; i < quizzes.length; i++) {
        final q = quizzes[i] as Map<String, dynamic>;
        checkProse(q['question'] as String?, {
          'chapter': chapter['id'],
          'quiz': q['id'],
          'field': 'question',
        });
      }
      final exercises = (chapter['exercises'] as List?) ?? const [];
      for (var i = 0; i < exercises.length; i++) {
        final ex = exercises[i] as Map<String, dynamic>;
        checkProse(ex['prompt'] as String?, {
          'chapter': chapter['id'],
          'exercise': ex['id'],
          'field': 'prompt',
        });
        checkProse(ex['explanation'] as String?, {
          'chapter': chapter['id'],
          'exercise': ex['id'],
          'field': 'explanation',
        });
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
        checkProse(problem['summary'] as String?, {
          'problem': problem['id'],
          'field': 'summary',
        });
        checkProse(problem['problemStatement'] as String?, {
          'problem': problem['id'],
          'field': 'problemStatement',
        });
        checkProse(problem['walkthrough'] as String?, {
          'problem': problem['id'],
          'field': 'walkthrough',
        });
        for (final ex in (problem['examples'] as List? ?? const [])) {
          checkProse((ex as Map<String, dynamic>)['explanation'] as String?, {
            'problem': problem['id'],
            'field': 'example.explanation',
          });
        }
        for (final tq in (problem['thinkQuestions'] as List? ?? const [])) {
          final m = tq as Map<String, dynamic>;
          checkProse(m['question'] as String?, {
            'problem': problem['id'],
            'field': 'thinkQuestion.question',
          });
          for (final opt in (m['options'] as List? ?? const [])) {
            checkProse(opt as String?, {
              'problem': problem['id'],
              'field': 'thinkQuestion.option',
            });
          }
          checkProse(m['explanation'] as String?, {
            'problem': problem['id'],
            'field': 'thinkQuestion.explanation',
          });
        }
        for (final h in (problem['hints'] as List? ?? const [])) {
          checkProse(h as String?, {'problem': problem['id'], 'field': 'hint'});
        }
        final comp = problem['complexity'] as Map<String, dynamic>?;
        if (comp != null) {
          checkProse(comp['time'] as String?, {
            'problem': problem['id'],
            'field': 'complexity.time',
          });
          checkProse(comp['space'] as String?, {
            'problem': problem['id'],
            'field': 'complexity.space',
          });
        }
        for (final edge in (problem['edgeCases'] as List? ?? const [])) {
          checkProse(edge as String?, {
            'problem': problem['id'],
            'field': 'edgeCase',
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
