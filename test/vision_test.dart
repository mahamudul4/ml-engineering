import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/features/vision/vision_model.dart';

void main() {
  final raw = jsonDecode(
        File('assets/datasets/digits/vision_lab.json').readAsStringSync(),
      ) as Map<String, dynamic>,
      a = VisionAssets.fromJson(raw);
  Map<String, dynamic> fresh() =>
      jsonDecode(jsonEncode(raw)) as Map<String, dynamic>;
  void nearMatrix(List<List<double>> got, dynamic expected) {
    expect(got.length, (expected as List).length);
    for (var i = 0; i < got.length; i++) {
      expect(got[i].length, (expected[i] as List).length);
      for (var j = 0; j < got[i].length; j++) {
        expect(got[i][j], closeTo((expected[i][j] as num).toDouble(), 1e-12));
      }
    }
  }

  test(
    'All18 actual-image cross-correlations match PyTorch, strides and padding',
    () {
      for (final r in raw['convolution_references'] as List) {
        final image = a.samples
            .firstWhere((s) => s.sourceRow == r['source_row_1based'])
            .normalized;
        final result = CorrelationResult.compute(
          image,
          a.kernels[r['kernel']]!,
          stride: r['stride'],
          padding: r['padding'],
        );
        nearMatrix(result.output, r['output']);
        expect(() => result.output.first[0] = 2, throwsUnsupportedError);
      }
    },
  );
  test('Cross-correlation convention, bounds, signed response and independent window sum', () {
    final image = <List<double>>[
          [1, 2, 3],
          [4, 5, 6],
          [7, 8, 9],
        ],
        k = <List<double>>[
          [1, 0],
          [0, -1],
        ];
    nearMatrix(CorrelationResult.compute(image, k).output, [
      [-4, -4],
      [-4, -4],
    ]);
    final p = CorrelationResult.compute(image, k, stride: 2, padding: 1);
    expect(p.output.length, 2);
    expect(p.output.first.first, -1);
    expect(
      () => CorrelationResult.compute(image, k, stride: 0),
      throwsArgumentError,
    );
    expect(
      () => CorrelationResult.compute(image, k, padding: -1),
      throwsArgumentError,
    );
    expect(
      () => CorrelationResult.compute([
        [1],
      ], k),
      throwsArgumentError,
    );
    expect(
      () => CorrelationResult.compute(
        [
          [double.nan],
        ],
        [
          [1],
        ],
      ),
      throwsArgumentError,
    );
    expect(
      () => CorrelationResult.compute(
        [
          [1, 2],
          [3],
        ],
        [
          [1],
        ],
      ),
      throwsArgumentError,
    );
  });
  test('All12 pooling/zero-fill references match and shift is not wrap', () {
    for (final r in raw['pool_references'] as List) {
      final original = a.samples
          .firstWhere((s) => s.sourceRow == r['source_row_1based'])
          .normalized;
      final image = r['shift_right'] == 1 ? shiftRight(original) : original;
      nearMatrix(image, r['input']);
      nearMatrix(pool2(image, average: r['mode'] == 'average'), r['output']);
    }
    nearMatrix(
      shiftRight([
        [1, 2],
        [3, 4],
      ]),
      [
        [0, 1],
        [0, 3],
      ],
    );
    expect(
      pool2([
        [1, 2],
        [3, 4],
      ]).single.single,
      4,
    );
    expect(
      pool2([
        [1, 2],
        [3, 4],
      ], average: true).single.single,
      2.5,
    );
    expect(
      () => pool2([
        [1],
      ]),
      throwsArgumentError,
    );
  });
  test(
    'Independent full CNN forward matches3 branches ×3 actual training images',
    () {
      for (final b in raw['branches'] as List) {
        final weights = a.branches[b['name']]!;
        for (var i = 0; i < 3; i++) {
          final got = weights.predict(a.samples[i].normalized);
          expect(got.features.length, 32);
          expect(got.logits.length, 5);
          for (var c = 0; c < 5; c++) {
            expect(got.logits[c], closeTo(b['logits'][i][c], 1e-11));
            expect(
              got.probability[c],
              closeTo(b['probabilities'][i][c], 1e-12),
            );
          }
          final expected = (b['features'][i] as List)
              .expand(
                (channel) => (channel as List).expand((row) => row as List),
              )
              .toList();
          for (var k = 0; k < 32; k++) {
            expect(got.features[k], closeTo(expected[k], 1e-12));
          }
          expect(got.probability.reduce((x, y) => x + y), closeTo(1, 1e-14));
          expect(got.digit, inInclusiveRange(5, 9));
          expect(() => got.logits[0] = 2, throwsUnsupportedError);
        }
      }
    },
  );
  test('Frozen backbone is unchanged while target head and fine-tuned features differ', () {
    final initial = a.branches['initial']!,
        frozen = a.branches['frozen']!,
        fine = a.branches['finetune']!;
    expect(jsonEncode(initial.conv1), jsonEncode(frozen.conv1));
    expect(jsonEncode(initial.conv2), jsonEncode(frozen.conv2));
    expect(initial.bias1, frozen.bias1);
    expect(initial.bias2, frozen.bias2);
    expect(jsonEncode(initial.head), isNot(jsonEncode(frozen.head)));
    expect(jsonEncode(initial.conv1), isNot(jsonEncode(fine.conv1)));
    expect(a.frozenChange, 0);
    expect(a.fineChange, closeTo(.15638945596806864, 1e-14));
    expect(
      () => initial.conv1.first.first.first[0] = 2,
      throwsUnsupportedError,
    );
    expect(() => a.branches.clear(), throwsUnsupportedError);
  });
  test(
    'Stable softmax and normalized input range reject numerical/shape mistakes',
    () {
      final p = VisionPrediction([1000, 999, -1000, 0, 1], List.filled(32, 0));
      expect(p.probability.every((v) => v.isFinite), isTrue);
      expect(p.probability.reduce((x, y) => x + y), closeTo(1, 1e-14));
      expect(p.digit, 5);
      final w = a.branches['frozen']!;
      expect(
        () => w.predict([
          [1, 2],
        ]),
        throwsArgumentError,
      );
      expect(
        () => w.predict(List.generate(8, (_) => List.filled(8, 16.0))),
        throwsArgumentError,
      );
      expect(
        () => w.predict(List.generate(8, (_) => List.filled(8, double.nan))),
        throwsArgumentError,
      );
    },
  );
  test('Real source samples preserve8x8 pixel ranges, target labels and immutable values', () {
    expect(a.samples.map((s) => s.digit), [5, 6, 9]);
    expect(a.roles['source_train'], 721);
    expect(a.roles['source_validation'], 180);
    expect(a.roles['target_train'], 717);
    expect(a.roles['target_validation'], 179);
    for (final s in a.samples) {
      for (var i = 0; i < 8; i++) {
        for (var j = 0; j < 8; j++) {
          expect(s.normalized[i][j], s.pixels[i][j] / 16);
        }
      }
      expect(() => s.pixels.first[0] = 9, throwsUnsupportedError);
    }
    expect(() => a.samples.clear(), throwsUnsupportedError);
  });
  test('Corrupt images, kernels, weight dimensions, scaling or labels are rejected', () {
    final j = fresh();
    j['samples'][0]['pixels'][0][0] = 17;
    expect(() => VisionAssets.fromJson(j), throwsFormatException);
    final k = fresh();
    k['samples'][1]['source_row_1based'] = k['samples'][0]['source_row_1based'];
    expect(() => VisionAssets.fromJson(k), throwsFormatException);
    final l = fresh();
    l['kernels']['sobel'][0][0] = 3;
    expect(() => VisionAssets.fromJson(l), throwsFormatException);
    final m = fresh();
    m['branches'][0]['weights']['head_weight'][0].removeLast();
    expect(() => VisionAssets.fromJson(m), throwsFormatException);
    final n = fresh();
    n['pixel_divisor'] = 255;
    expect(() => VisionAssets.fromJson(n), throwsFormatException);
    final o = fresh();
    o['target_labels'] = [0, 1, 2, 3, 4];
    expect(() => VisionAssets.fromJson(o), throwsFormatException);
    final p = fresh();
    p['frozen_backbone_max_abs'] = 1;
    expect(() => VisionAssets.fromJson(p), throwsFormatException);
    final changed = fresh();
    changed['branches'][1]['weights']['conv1_weight'][0][0][0][0] += 1;
    expect(() => VisionAssets.fromJson(changed), throwsFormatException);
    final roles = fresh();
    roles['roles']['source_train'] += 1;
    roles['roles']['target_train'] -= 1;
    expect(() => VisionAssets.fromJson(roles), throwsFormatException);
  });
}
