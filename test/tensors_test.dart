import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/features/tensors/tensor_model.dart';

void main() {
  final json = jsonDecode(
    File('assets/datasets/wine_quality/tensor_lab.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final a = TensorAssets.fromJson(json);
  List<double> vector(dynamic v) =>
      (v as List).map((x) => (x as num).toDouble()).toList();
  Map<String, dynamic> fresh() =>
      jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
  test('All source layouts match PyTorch values, strides, addresses and copy behavior', () {
    for (final r in json['layouts'] as List) {
      final layout = a.layout(r['name']);
      expect(layout.shape, r['shape']);
      expect(layout.stride, r['stride']);
      expect(layout.offset, r['storage_offset']);
      expect(layout.isContiguous, r['contiguous']);
      for (var i = 0; i < layout.shape[0]; i++) {
        for (var j = 0; j < layout.shape[1]; j++) {
          expect(layout.value(i, j), r['values'][i][j]);
          expect(layout.elementOffset(i, j), r['storage_indices'][i][j]);
        }
      }
      final copy = layout.contiguous();
      expect(copy.isContiguous, isTrue);
      expect(copy.overlaps, isFalse);
      expect(copy.stride, r['after_contiguous_stride']);
      expect(identical(copy, layout), r['contiguous_shares_storage']);
      for (var i = 0; i < layout.shape[0]; i++) {
        for (var j = 0; j < layout.shape[1]; j++) {
          expect(copy.value(i, j), layout.value(i, j));
        }
      }
    }
    expect(a.layout('expand').overlaps, isTrue);
    expect(a.layout('slice').overlaps, isFalse);
  });
  test('Layout honors nonzero offsets, singleton strides, bounds and immutable storage', () {
    final s = TensorLayout(
      storage: [0, 1, 2, 3, 4, 5],
      shape: [1, 3],
      stride: [99, 1],
      offset: 2,
    );
    expect(s.isContiguous, isTrue);
    expect(s.value(0, 2), 4);
    expect(identical(s.contiguous(), s), isTrue);
    expect(() => s.value(1, 0), throwsRangeError);
    expect(() => s.value(0, -1), throwsRangeError);
    expect(() => s.storage[0] = 4, throwsUnsupportedError);
    expect(() => s.shape[0] = 3, throwsUnsupportedError);
    expect(
      () => TensorLayout(storage: [1], shape: [2, 1], stride: [1, 1]),
      throwsArgumentError,
    );
    expect(
      () => TensorLayout(storage: [1], shape: [1, 1], stride: [-1, 1]),
      throwsArgumentError,
    );
    expect(() => a.layout('bad'), throwsArgumentError);
  });
  test('Actual training rows preserve feature order, standardization and immutability', () {
    expect(a.samples.map((s) => s.sourceRow), [
      1,
      4,
      5,
      6,
      7,
      9,
      11,
      14,
      17,
      18,
      19,
      20,
      23,
      25,
      26,
      28,
    ]);
    expect(a.features[10], 'alcohol');
    expect(a.features[1], 'volatile acidity');
    for (final s in a.samples) {
      for (var d = 0; d < 11; d++) {
        expect(
          s.standardized[d],
          closeTo((s.raw[d] - a.mean[d]) / a.scale[d], 1e-12),
        );
      }
      expect(s.positive, s.quality >= 6 ? 1 : 0);
    }
    expect(() => a.samples.clear(), throwsUnsupportedError);
    expect(() => a.samples.first.raw[0] = 9, throwsUnsupportedError);
    expect(() => a.gradientX[0][0] = 9, throwsUnsupportedError);
  });
  test('Correct and pairwise broadcast match PyTorch references including singleton trap', () {
    for (final r in json['broadcast_references'] as List) {
      final n = r['batch'] as int;
      final correct = BroadcastResult.compute(
        a.probabilities(n),
        a.labels(n),
        columnTarget: false,
      );
      final wrong = BroadcastResult.compute(
        a.probabilities(n),
        a.labels(n),
        columnTarget: true,
      );
      expect(correct.shape, r['correct_shape']);
      expect(wrong.shape, r['wrong_shape']);
      expect(correct.mse, closeTo(r['correct_mse'], 1e-14));
      expect(wrong.mse, closeTo(r['wrong_mse'], 1e-14));
      for (var i = 0; i < n; i++) {
        expect(
          correct.residual[0][i],
          closeTo(r['correct_residual'][i], 1e-14),
        );
        for (var j = 0; j < n; j++) {
          expect(
            wrong.residual[i][j],
            closeTo(r['wrong_residual'][i][j], 1e-14),
          );
        }
      }
      if (n == 1) {
        expect(correct.mse, wrong.mse);
        expect(correct.shape, isNot(wrong.shape));
      } else {
        expect(correct.mse, isNot(wrong.mse));
      }
      expect(() => wrong.residual.first[0] = 9, throwsUnsupportedError);
    }
  });
  test('Gradient microscope matches PyTorch autograd and independent finite differences', () {
    for (final r in json['gradient_references'] as List) {
      final t = vector(r['parameters']);
      final result = GradientResult.compute(a.gradientX, a.labels(16), t);
      expect(result.loss, closeTo(r['loss'], 1e-13));
      for (var d = 0; d < 3; d++) {
        expect(result.gradient[d], closeTo(r['gradient'][d], 1e-13));
        const eps = 1e-6;
        final plus = [...t]..[d] += eps;
        final minus = [...t]..[d] -= eps;
        final finite =
            (GradientResult.compute(a.gradientX, a.labels(16), plus).loss -
                GradientResult.compute(a.gradientX, a.labels(16), minus).loss) /
            (2 * eps);
        expect(result.gradient[d], closeTo(finite, 1e-8));
      }
      expect(() => result.gradient[0] = 0, throwsUnsupportedError);
    }
    final start = GradientResult.compute(a.gradientX, a.labels(16), [0, 0, 0]);
    final next = start.step([0, 0, 0], .1);
    expect(
      GradientResult.compute(a.gradientX, a.labels(16), next).loss,
      lessThan(start.loss),
    );
  });
  test('Stable BCE handles extreme logits without sigmoid-log underflow', () {
    final high = GradientResult.compute(
      [
        [0, 0],
      ],
      [0],
      [0, 0, 1000],
    );
    expect(high.loss, 1000);
    expect(high.gradient, [0, 0, 1]);
    final low = GradientResult.compute(
      [
        [0, 0],
      ],
      [1],
      [0, 0, -1000],
    );
    expect(low.loss, 1000);
    expect(low.gradient, [0, 0, -1]);
    final right = GradientResult.compute(
      [
        [0, 0],
      ],
      [1],
      [0, 0, 1000],
    );
    expect(right.loss, 0);
    expect(right.gradient, [0, 0, 0]);
  });
  test('Numerical contracts reject invalid inputs and learning rates', () {
    for (final pair in [
      ([.5], [2.0]),
      ([double.nan], [0.0]),
      ([1.1], [1.0]),
      (<double>[], <double>[]),
      ([.2, .3], [1.0]),
    ]) {
      expect(
        () => BroadcastResult.compute(pair.$1, pair.$2, columnTarget: true),
        throwsArgumentError,
      );
    }
    expect(
      () => GradientResult.compute([], [], [0, 0, 0]),
      throwsArgumentError,
    );
    expect(
      () => GradientResult.compute(
        [
          [1, 2],
        ],
        [2],
        [0, 0, 0],
      ),
      throwsArgumentError,
    );
    expect(
      () => GradientResult.compute(
        [
          [1],
        ],
        [0],
        [0, 0, 0],
      ),
      throwsArgumentError,
    );
    expect(
      () => GradientResult.compute(
        [
          [1, 2],
        ],
        [0],
        [double.nan, 0, 0],
      ),
      throwsArgumentError,
    );
    final g = GradientResult.compute(
      [
        [1, 2],
      ],
      [0],
      [0, 0, 0],
    );
    for (final rate in [0.0, -1.0, double.infinity, double.nan]) {
      expect(() => g.step([0, 0, 0], rate), throwsArgumentError);
    }
    expect(() => a.probabilities(0), throwsArgumentError);
    expect(() => a.labels(17), throwsArgumentError);
    expect(
      () => GradientResult.compute(
        List.generate(8, (_) => [1e308, 0.0]),
        List.filled(8, 0.0),
        [0, 0, 0],
      ),
      throwsArgumentError,
    );
  });
  test(
    'Corrupt source schemas, transformations and duplicate rows are rejected',
    () {
      final j = fresh();
      j['samples'][0]['standardized'][0] += 1;
      expect(() => TensorAssets.fromJson(j), throwsFormatException);
      final k = fresh();
      k['samples'][1]['source_row_1based'] =
          k['samples'][0]['source_row_1based'];
      expect(() => TensorAssets.fromJson(k), throwsFormatException);
      final l = fresh();
      l['scale'][0] = 0;
      expect(() => TensorAssets.fromJson(l), throwsFormatException);
      final m = fresh();
      m['layout_storage'][0] += 1;
      expect(() => TensorAssets.fromJson(m), throwsFormatException);
      final n = fresh();
      n['feature_names'].removeLast();
      expect(() => TensorAssets.fromJson(n), throwsFormatException);
      final o = fresh();
      o['samples'][0]['positive'] = 1 - o['samples'][0]['positive'];
      expect(() => TensorAssets.fromJson(o), throwsFormatException);
      final swapped = fresh();
      final names = swapped['feature_names'] as List;
      final first = names[0];
      names[0] = names[1];
      names[1] = first;
      expect(() => TensorAssets.fromJson(swapped), throwsFormatException);
      final dtype = fresh()..['dtype'] = 'float32';
      expect(() => TensorAssets.fromJson(dtype), throwsFormatException);
      final columns = fresh()..['gradient_columns'] = [1, 10];
      expect(() => TensorAssets.fromJson(columns), throwsFormatException);
    },
  );
}
