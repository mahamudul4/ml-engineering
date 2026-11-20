import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/features/adaptation/adaptation_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AdaptationAssets a;
  late Map<String, dynamic> lab;
  setUpAll(() async {
    a = await AdaptationAssets.load();
    lab = jsonDecode(
      await rootBundle.loadString(
        'assets/datasets/scifact_rag/adaptation_lab.json',
      ),
    );
  });
  test('All24 actual sample model forwards match complete259 Python logits and normalized states', () {
    for (final s in lab['samples']) {
      for (final name in a.models.keys) {
        final trace = a.models[name]!.run(List<int>.from(s['ids'])),
            ref = s['references'][name],
            logits = trace.matrices['logits']!.last;
        for (var i = 0; i < 259; i++) {
          expect(logits[i], closeTo(ref['logits'][i], 1e-10));
        }
        for (var i = 0; i < 8; i++) {
          expect(
            trace.matrices['normalized']!.last[i],
            closeTo(ref['normalized'][i], 1e-11),
          );
        }
        expect(
          supportProbability(logits),
          closeTo(ref['conditional_support_probability'], 1e-12),
        );
      }
    }
  });
  test(
    'Actual LoRA merge,scale0base andscale1trained logits are identical',
    () {
      final zero = a.scaledAdapter(0), one = a.scaledAdapter(1);
      for (final s in a.samples) {
        for (final pair in [
          (zero, a.models['base']!),
          (one, a.models['lora']!),
        ]) {
          final actual = pair.$1.run(s.ids).matrices['logits']!.last,
              expected = pair.$2.run(s.ids).matrices['logits']!.last;
          for (var i = 0; i < 259; i++) {
            expect(actual[i], closeTo(expected[i], 1e-11));
          }
        }
      }
      expect(() => a.scaledAdapter(-1), throwsArgumentError);
      expect(() => a.scaledAdapter(double.nan), throwsArgumentError);
    },
  );
  test('Prefix byte budget,BOS,newline andUnicode truncation follow Python contract', () {
    for (final s in a.samples) {
      expect(adaptationPrefix(s.text), s.ids);
      expect(s.ids.length, lessThanOrEqualTo(26));
      expect(s.ids.first, 257);
      expect(s.ids.last, 10);
    }
    expect(adaptationPrefix(''), [257, 10]);
    expect(adaptationPrefix('বাংলা বাংলা বাংলা').length, 26);
  });
  test('ResponseNLL uses257classes whileconditionalprobabilityuses2', () {
    final logits = List<double>.filled(259, 0);
    expect(responseNLL(logits, 83), closeTo(math.log(257), 1e-13));
    expect(supportProbability(logits), .5);
    logits[256] = 10000;
    logits[257] = 10000;
    expect(responseNLL(logits, 67), closeTo(math.log(257), 1e-13));
    expect(() => responseNLL([0], 83), throwsArgumentError);
    expect(
      () => responseNLL(List.filled(259, double.nan), 83),
      throwsArgumentError,
    );
    expect(() => responseNLL(List.filled(259, 0), 0), throwsArgumentError);
  });
  test('LoRA shapes,finite weights andimmutableexport rejectbadcontracts', () {
    expect(() => adapterDelta([], a.b), throwsArgumentError);
    expect(() => adapterDelta(a.a, [], scale: 1), throwsArgumentError);
    expect(() => a.a[0][0] = 0, throwsUnsupportedError);
    expect(() => a.b[0][0] = 0, throwsUnsupportedError);
    expect(() => a.samples.first.ids.add(0), throwsUnsupportedError);
  });
  test('Majority failure andhead-onlyint8scope stayexplicit', () {
    final r = a.report;
    expect(r['train_queries'], 505);
    expect(r['diagnostic_queries'], 188);
    expect(r['runs']['lora']['trainable_parameters'], 534);
    expect(r['runs']['full']['trainable_parameters'], 5019);
    for (final name in ['full', 'lora']) {
      expect(
        r['runs'][name]['diagnostic']['accuracy'],
        r['majority_diagnostic_accuracy'],
      );
      expect(r['runs'][name]['diagnostic']['contradict_predictions'], 0);
    }
    expect(r['runs']['int8_head_demo']['codes_bytes'], 2072);
    expect(r['runs']['int8_head_demo']['scales_float64_bytes'], 2072);
  });
  test(
    'Every int8 roundtripheadweight reconstructs storeddequantized model',
    () {
      final codes = lab['quantization']['codes'],
          scales = lab['quantization']['scales'],
          head = a.models['int8_head_demo']!.matrices['head.weight']!;
      for (var i = 0; i < 259; i++) {
        for (var j = 0; j < 8; j++) {
          expect(head[i][j], closeTo(codes[i][j] * scales[i], 1e-13));
        }
      }
    },
  );
}
