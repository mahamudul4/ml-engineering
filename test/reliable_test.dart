import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/features/reliable/reliable_model.dart';

void main() {
  final raw = jsonDecode(
        File('assets/datasets/wine_quality/reliable_lab.json')
            .readAsStringSync(),
      ) as Map<String, dynamic>,
      a = ReliableAssets.fromJson(raw);
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

  test('All four stateful optimizer recurrences match PyTorch measured-gradient replay', () {
    for (final r in raw['optimizers']['replay'] as List) {
      final got = OptimizerReplay.compute(a.initial, a.gradient, r['kind']);
      nearMatrix(got.values, r['values']);
      expect(() => got.values.first[0] = 9, throwsUnsupportedError);
    }
    expect(
      OptimizerReplay.compute(a.initial, a.gradient, 'adam').values.last,
      isNot(
        OptimizerReplay.compute(a.initial, a.gradient, 'adamw').values.last,
      ),
    );
  });
  test(
    'Independent mathematical SGD momentum decay and Adam first-step checks',
    () {
      expect(
        OptimizerReplay.compute(
          [1],
          [2],
          'momentum',
          steps: 2,
          lr: .1,
          decay: 0,
        ).values.last.single,
        closeTo(.42, 1e-14),
      );
      expect(
        OptimizerReplay.compute(
          [2],
          [0],
          'adamw',
          steps: 1,
          lr: .1,
          decay: .2,
        ).values.last.single,
        closeTo(1.96, 1e-14),
      );
      expect(
        OptimizerReplay.compute(
          [2],
          [3],
          'sgd',
          steps: 1,
          lr: .1,
          decay: 0,
        ).values.last.single,
        closeTo(1.7, 1e-14),
      );
      expect(
        OptimizerReplay.compute(
          [1],
          [2],
          'adam',
          steps: 1,
          lr: .01,
          decay: 0,
        ).values.last.single,
        closeTo(1 - .01 * 2 / (2 + 1e-8), 1e-14),
      );
    },
  );
  test(
    'BN train/eval and LayerNorm outputs match actual PyTorch preactivations',
    () {
      final n = raw['normalization'];
      for (final pair in [
        ('batch_train', 'bn_train'),
        ('batch_eval', 'bn_eval'),
        ('layer', 'layer_norm'),
      ]) {
        final got = NormalizedBatch.compute(
          a.activations,
          pair.$1,
          runningMean: a.runningMean,
          runningVariance: a.runningVariance,
        );
        nearMatrix(got.values, n[pair.$2]);
        expect(() => got.values.first[0] = 1, throwsUnsupportedError);
      }
      final train = NormalizedBatch.compute(a.activations, 'batch_train');
      for (var k = 0; k < 4; k++) {
        expect(train.mean[k], closeTo(n['batch_mean'][k], 1e-13));
        expect(train.variance[k], closeTo(n['batch_var_biased'][k], 1e-13));
        expect(
          a.runningVariance[k],
          closeTo(.9 + .1 * train.variance[k] * 8 / 7, 1e-13),
        );
      }
    },
  );
  test('Normalization axes, epsilon, singleton and batchmate behavior', () {
    final X = <List<double>>[
          [1.0, 2, 3, 4],
          [2.0, 4, 6, 8],
        ],
        layer = NormalizedBatch.compute(X, 'layer');
    nearMatrix(NormalizedBatch.compute([X.first], 'layer').values, [
      layer.values.first,
    ]);
    final changed = NormalizedBatch.compute([
          X.first,
          [9, 10, 11, 12],
        ], 'batch_train'),
        base = NormalizedBatch.compute(X, 'batch_train');
    expect(changed.values.first, isNot(base.values.first));
    expect(
      NormalizedBatch.compute([
        [2, 2, 2, 2],
      ], 'layer').values.first,
      [0, 0, 0, 0],
    );
    expect(
      () => NormalizedBatch.compute([X.first], 'batch_train'),
      throwsArgumentError,
    );
    expect(() => NormalizedBatch.compute(X, 'batch_eval'), throwsArgumentError);
  });
  test('Complete recovery history exactly matches, reset optimizer schedule diverges after fork', () {
    expect(a.continuous.length, 41);
    for (var i = 0; i < 41; i++) {
      expect(a.resumed[i].train, a.continuous[i].train);
      expect(a.resumed[i].validation, a.continuous[i].validation);
      expect(a.resumed[i].nextLr, a.continuous[i].nextLr);
      if (i <= 20) {
        expect(a.weightsOnly[i].train, a.continuous[i].train);
      }
    }
    expect(a.continuous[20].nextLr, .005);
    expect(a.continuous[40].nextLr, .0025);
    expect(a.weightsOnly[40].nextLr, .005);
    expect(a.weightsOnly[21].train, isNot(a.continuous[21].train));
    expect(a.resumeError, 0);
    expect(a.weightsOnlyError, closeTo(.18636363570553197, 1e-14));
    expect(() => a.continuous.clear(), throwsUnsupportedError);
    expect(() => a.activations.first[0] = 8, throwsUnsupportedError);
  });
  test(
    'Replay and normalization reject nonfinite, shape and policy errors',
    () {
      for (final kind in ['bad', '']) {
        expect(
          () => OptimizerReplay.compute([1], [2], kind),
          throwsArgumentError,
        );
      }
      expect(
        () => OptimizerReplay.compute([1], [2, 3], 'adam'),
        throwsArgumentError,
      );
      expect(
        () => OptimizerReplay.compute([double.nan], [1], 'sgd'),
        throwsArgumentError,
      );
      expect(
        () => OptimizerReplay.compute([1], [2], 'adamw', steps: 101),
        throwsArgumentError,
      );
      expect(
        () => OptimizerReplay.compute([1], [2], 'sgd', lr: 0),
        throwsArgumentError,
      );
      expect(
        () => OptimizerReplay.compute([1], [2], 'sgd', decay: -1),
        throwsArgumentError,
      );
      expect(() => NormalizedBatch.compute([], 'layer'), throwsArgumentError);
      expect(
        () => NormalizedBatch.compute([
          [1, 2],
          [1],
        ], 'layer'),
        throwsArgumentError,
      );
      expect(
        () => NormalizedBatch.compute([
          [1, double.infinity],
        ], 'layer'),
        throwsArgumentError,
      );
      expect(
        () => NormalizedBatch.compute(
          [
            [1, 2],
          ],
          'layer',
          eps: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => NormalizedBatch.compute(
          [
            [1, 2],
          ],
          'batch_eval',
          runningMean: [0, 0],
          runningVariance: [-1, 1],
        ),
        throwsArgumentError,
      );
    },
  );
  test(
    'Corrupt histories, source identities and recipe state are rejected',
    () {
      final j = fresh();
      j['resumed_history'][22]['train_bce'] += 1;
      expect(() => ReliableAssets.fromJson(j), throwsFormatException);
      final k = fresh();
      k['continuous_history'][1]['epoch'] = 5;
      expect(() => ReliableAssets.fromJson(k), throwsFormatException);
      final l = fresh();
      l['weights_only_history'][10]['validation_bce'] += 1;
      expect(() => ReliableAssets.fromJson(l), throwsFormatException);
      final m = fresh();
      m['source_rows_1based'][1] = m['source_rows_1based'][0];
      expect(() => ReliableAssets.fromJson(m), throwsFormatException);
      final n = fresh();
      n['config']['dropout'] = .5;
      expect(() => ReliableAssets.fromJson(n), throwsFormatException);
      final p = fresh();
      p['normalization']['running_var'][0] += 1;
      expect(() => ReliableAssets.fromJson(p), throwsFormatException);
      final schema = fresh();
      schema['feature_names'][0] = 'wrong';
      expect(() => ReliableAssets.fromJson(schema), throwsFormatException);
      final epsilon = fresh();
      epsilon['normalization']['eps'] = .01;
      expect(() => ReliableAssets.fromJson(epsilon), throwsFormatException);
    },
  );
  test(
    'Running-stat references correspond to the actual bounded training rows',
    () {
      expect(a.sourceRows.length, 8);
      expect(a.sourceRows.first, 1);
      expect(a.activations.length, 8);
      expect(a.activations.every((r) => r.length == 4), isTrue);
      final computed = NormalizedBatch.compute(a.activations, 'batch_train');
      for (var k = 0; k < 4; k++) {
        expect(a.runningMean[k], closeTo(.1 * computed.mean[k], 1e-12));
      }
      final recipe = fresh();
      recipe['config']['seed'] = 18;
      expect(() => ReliableAssets.fromJson(recipe), throwsFormatException);
      final shape = fresh();
      shape['optimizers']['initial'].removeLast();
      expect(() => ReliableAssets.fromJson(shape), throwsFormatException);
    },
  );
}
