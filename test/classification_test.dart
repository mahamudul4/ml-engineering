import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/features/classification/classification_model.dart';
import 'package:ml_path/features/regression/polynomial_lab.dart';

void main() {
  test('sigmoid and softmax stay stable at extreme logits', () {
    expect(ClassificationModel.sigmoid(0), .5);
    expect(ClassificationModel.sigmoid(-1000), 0);
    expect(ClassificationModel.sigmoid(1000), 1);
    expect(ClassificationModel.sigmoid(2), closeTo(.880797, 1e-6));
    final p = ClassificationModel.softmax([1000, 1000, 1000]);
    expect(p.reduce((a, b) => a + b), closeTo(1, 1e-12));
    expect(p.first, closeTo(1 / 3, 1e-12));
    expect(() => ClassificationModel.softmax([]), throwsArgumentError);
    expect(() => ClassificationModel.sigmoid(double.nan), throwsArgumentError);
  });
  test(
    'binary loss and finite-difference logit gradients match the lesson',
    () {
      expect(ClassificationModel.logLoss(0, 1), closeTo(math.log(2), 1e-12));
      expect(ClassificationModel.logLoss(1000, 0), 1000);
      expect(ClassificationModel.logLoss(-1000, 1), 1000);
      const epsilon = 1e-5, z = .7;
      final gradient =
          (ClassificationModel.logLoss(z + epsilon, 1) -
              ClassificationModel.logLoss(z - epsilon, 1)) /
          (2 * epsilon);
      expect(gradient, closeTo(ClassificationModel.sigmoid(z) - 1, 1e-8));
    },
  );
  test(
    'threshold metrics, inclusive ties and undefined cases are explicit',
    () {
      final m = ConfusionMetrics.evaluate(
        ThresholdDemo.labels,
        ThresholdDemo.scores,
        .5,
      );
      expect([m.tn, m.fp, m.fn, m.tp], [3, 2, 2, 3]);
      expect(m.precision, .6);
      expect(m.recall, .6);
      expect(m.f1, .6);
      final high = ConfusionMetrics.evaluate(
        ThresholdDemo.labels,
        ThresholdDemo.scores,
        .8,
      );
      expect([high.tn, high.fp, high.fn, high.tp], [4, 1, 4, 1]);
      final none = ConfusionMetrics.evaluate(
        ThresholdDemo.labels,
        ThresholdDemo.scores,
        1,
      );
      expect(none.precision, isNull);
      expect(none.recall, 0);
      expect(none.f1, 0);
      final tie = ConfusionMetrics.evaluate([1], [.5], .5);
      expect(tie.tp, 1);
      final negative = ConfusionMetrics.evaluate([0], [.1], .5);
      expect(negative.recall, isNull);
      expect(negative.f1, isNull);
      expect(
        () => ConfusionMetrics.evaluate([1], [double.nan], .5),
        throwsArgumentError,
      );
    },
  );
  test('recall never decreases as threshold is lowered for fixed scores', () {
    var previous = 0.0;
    for (var i = 20; i >= 0; i--) {
      final m = ConfusionMetrics.evaluate(
        ThresholdDemo.labels,
        ThresholdDemo.scores,
        i / 20,
      );
      expect(m.recall!, greaterThanOrEqualTo(previous));
      previous = m.recall!;
      expect(m.total, 10);
    }
  });
  test(
    'boundary intersections handle vertical, horizontal and zero weights',
    () {
      final vertical = ClassificationModel.boundary(1, 0, -2);
      expect(vertical.length, 2);
      expect(vertical.every((p) => p.$1 == 2), isTrue);
      final horizontal = ClassificationModel.boundary(0, 1, -2);
      expect(horizontal.length, 2);
      expect(horizontal.every((p) => p.$2 == 2), isTrue);
      expect(ClassificationModel.boundary(0, 0, 0), isEmpty);
      expect(ClassificationModel.boundary(1, 1, 1), isEmpty);
      for (final p in ClassificationModel.boundary(1, 1, -4)) {
        expect(p.$1 + p.$2, closeTo(4, 1e-12));
      }
    },
  );
  test('polynomial generating coefficients reach zero toy loss', () {
    expect(PolynomialModel.predict(3, 2, .5), 11.5);
    expect(PolynomialModel.mse(2, .5), 0);
    expect(PolynomialModel.mse(1, 0), greaterThan(0));
  });
}
