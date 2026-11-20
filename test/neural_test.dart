import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/features/neural/neural_model.dart';

void main() {
  final raw = jsonDecode(
        File('assets/datasets/wine_quality/neural_lab.json').readAsStringSync(),
      ) as Map<String, dynamic>,
      a = NeuralAssets.fromJson(raw);
  Map<String, dynamic> fresh() =>
      jsonDecode(jsonEncode(raw)) as Map<String, dynamic>;
  void nearVector(List<double> actual, dynamic expected) {
    expect(actual.length, (expected as List).length);
    for (var i = 0; i < actual.length; i++) {
      expect(actual[i], closeTo((expected[i] as num).toDouble(), 1e-12));
    }
  }

  test('Forward values match actual PyTorch references at initial/final weights and both activations', () {
    for (final r in raw['backprop_references'] as List) {
      final p = a.checkpoints
          .firstWhere((c) => c.evidence.epoch == r['epoch'])
          .parameters;
      for (var i = 0; i < 8; i++) {
        final trace = NeuralTrace.compute(
          a.X[i],
          a.y[i],
          p,
          tanh: r['activation'] == 'tanh',
        );
        nearVector(trace.preactivation, r['z1'][i]);
        nearVector(trace.hidden, r['hidden'][i]);
        nearVector(trace.gate, r['gate'][i]);
        expect(trace.logit, closeTo(r['logits'][i], 1e-12));
        expect(trace.probability, closeTo(r['probability'][i], 1e-12));
        expect(
          trace.contributions.fold(p.b2, (s, v) => s + v),
          closeTo(trace.logit, 1e-14),
        );
      }
    }
  });
  test(
    'All matrix chain-rule gradients match PyTorch for mean/sum and ReLU/tanh',
    () {
      for (final r in raw['backprop_references'] as List) {
        final p = a.checkpoints
                .firstWhere((c) => c.evidence.epoch == r['epoch'])
                .parameters,
            g = NeuralGradient.compute(
              a.X,
              a.y,
              p,
              sum: r['reduction'] == 'sum',
              tanh: r['activation'] == 'tanh',
            );
        expect(g.loss, closeTo(r['loss'], 1e-12));
        nearVector(g.dw2, r['dw2']);
        nearVector(g.db1, r['db1']);
        nearVector(g.dlogit, r['dlogit']);
        expect(g.db2, closeTo(r['db2'], 1e-12));
        for (var j = 0; j < 4; j++) {
          nearVector(g.dw1[j], r['dw1'][j]);
        }
      }
    },
  );
  test('Independent finite differences and explicit outer products agree with hidden gradient', () {
    final parameters =
            (raw['checkpoints'] as List).first['parameters']
                as Map<String, dynamic>,
        p = NeuralParameters.fromJson(parameters),
        g = NeuralGradient.compute(a.X, a.y, p);
    const eps = 1e-6;
    for (final coordinate in [(0, 0), (2, 10), (3, 5)]) {
      final plus = jsonDecode(jsonEncode(parameters)) as Map<String, dynamic>,
          minus = jsonDecode(jsonEncode(parameters)) as Map<String, dynamic>;
      plus['w1'][coordinate.$1][coordinate.$2] += eps;
      minus['w1'][coordinate.$1][coordinate.$2] -= eps;
      final numeric =
          (NeuralGradient.compute(
                a.X,
                a.y,
                NeuralParameters.fromJson(plus),
              ).loss -
              NeuralGradient.compute(
                a.X,
                a.y,
                NeuralParameters.fromJson(minus),
              ).loss) /
          (2 * eps);
      expect(g.dw1[coordinate.$1][coordinate.$2], closeTo(numeric, 1e-8));
      var outer = 0.0;
      for (var i = 0; i < 8; i++) {
        final trace = NeuralTrace.compute(a.X[i], a.y[i], p);
        outer +=
            g.dlogit[i] *
            p.w2[coordinate.$1] *
            trace.gate[coordinate.$1] *
            a.X[i][coordinate.$2];
      }
      expect(g.dw1[coordinate.$1][coordinate.$2], closeTo(outer, 1e-14));
    }
  });
  test('ReLU inactive connected gradients are numeric zero, unlike detached UI path', () {
    final j = fresh()['checkpoints'][0]['parameters'] as Map<String, dynamic>;
    j['w1'] = List.generate(4, (_) => List.filled(11, 0.0));
    j['b1'] = List.filled(4, -100.0);
    final p = NeuralParameters.fromJson(j),
        g = NeuralGradient.compute(a.X, a.y, p);
    expect(g.dw1.expand((r) => r).every((v) => v == 0), isTrue);
    expect(g.db1, [0, 0, 0, 0]);
    expect(g.dw2, [0, 0, 0, 0]);
    expect(g.db2, isNot(0));
    final mean = NeuralGradient.compute(
          a.X,
          a.y,
          a.checkpoints.first.parameters,
        ),
        sum = NeuralGradient.compute(
          a.X,
          a.y,
          a.checkpoints.first.parameters,
          sum: true,
        );
    expect(sum.loss, closeTo(8 * mean.loss, 1e-13));
    expect(sum.db2, closeTo(8 * mean.db2, 1e-13));
  });
  test('Source preprocessing scope, actual history endpoints and immutable snapshots', () {
    expect(a.trainRows, 776);
    expect(a.validationRows, 190);
    expect(a.trainGroups, 652);
    expect(a.validationGroups, 163);
    expect(a.history.length, 121);
    expect(a.checkpoints.map((c) => c.evidence.epoch), [
      0,
      1,
      5,
      10,
      20,
      40,
      80,
      120,
    ]);
    expect(a.history.last.trainLoss, closeTo(.5843037975982561, 1e-14));
    expect(a.history.last.validationLoss, closeTo(.6017428166583263, 1e-14));
    for (final s in a.samples) {
      for (var k = 0; k < 11; k++) {
        expect(s.x[k], closeTo((s.raw[k] - a.mean[k]) / a.scale[k], 1e-12));
      }
      expect(s.positive, s.quality >= 6 ? 1 : 0);
    }
    expect(
      () => a.checkpoints.first.parameters.w1[0][0] = 9,
      throwsUnsupportedError,
    );
    expect(() => a.history.clear(), throwsUnsupportedError);
    expect(() => a.samples.first.x[0] = 9, throwsUnsupportedError);
  });
  test('Stable sigmoid and BCE remain finite at extreme logits', () {
    expect(sigmoid(1000), 1);
    expect(sigmoid(-1000), 0);
    final j = fresh()['checkpoints'][0]['parameters'] as Map<String, dynamic>;
    j['w1'] = List.generate(4, (_) => List.filled(11, 0.0));
    j['b1'] = List.filled(4, 0.0);
    j['w2'] = List.filled(4, 0.0);
    j['b2'] = 1000.0;
    final p = NeuralParameters.fromJson(j),
        r = NeuralTrace.compute(List.filled(11, 0), 0, p);
    expect(r.loss, 1000);
    expect(r.probability, 1);
    expect(NeuralTrace.compute(List.filled(11, 0), 1, p).loss, 0);
  });
  test(
    'Exact shape, finite and binary contracts reject invalid calculations',
    () {
      final p = a.checkpoints.first.parameters;
      expect(() => NeuralTrace.compute([1, 2], 0, p), throwsArgumentError);
      expect(() => NeuralTrace.compute(a.X.first, 2, p), throwsArgumentError);
      expect(
        () => NeuralTrace.compute(List.filled(11, double.nan), 0, p),
        throwsArgumentError,
      );
      expect(() => NeuralGradient.compute([], [], p), throwsArgumentError);
      expect(() => NeuralGradient.compute(a.X, [1], p), throwsArgumentError);
      expect(
        () => NeuralParameters.fromJson({
          'w1': [
            [1],
          ],
          'b1': [0],
          'w2': [1],
          'b2': 0,
        }),
        throwsFormatException,
      );
    },
  );
  test('Corrupt feature order, checkpoints, source transforms and duplicated rows are rejected', () {
    final j = fresh();
    j['feature_names'][0] = 'wrong';
    expect(() => NeuralAssets.fromJson(j), throwsFormatException);
    final k = fresh();
    k['samples'][0]['standardized'][0] += 1;
    expect(() => NeuralAssets.fromJson(k), throwsFormatException);
    final l = fresh();
    l['samples'][1]['source_row_1based'] = l['samples'][0]['source_row_1based'];
    expect(() => NeuralAssets.fromJson(l), throwsFormatException);
    final m = fresh();
    m['history'][1]['epoch'] = 5;
    expect(() => NeuralAssets.fromJson(m), throwsFormatException);
    final n = fresh();
    n['checkpoints'][0]['train_bce'] += 1;
    expect(() => NeuralAssets.fromJson(n), throwsFormatException);
    final o = fresh();
    o['scale'][0] = 0;
    expect(() => NeuralAssets.fromJson(o), throwsFormatException);
    final q = fresh();
    q['dtype'] = 'float32';
    expect(() => NeuralAssets.fromJson(q), throwsFormatException);
    final accuracy = fresh();
    accuracy['checkpoints'][0]['validation_accuracy'] = .1;
    expect(() => NeuralAssets.fromJson(accuracy), throwsFormatException);
    final activation = fresh()..['activation'] = 'tanh';
    expect(() => NeuralAssets.fromJson(activation), throwsFormatException);
  });
}
