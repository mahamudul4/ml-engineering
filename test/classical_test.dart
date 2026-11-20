import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/features/classical/classical_model.dart';

ClassicalPoint point(int row, double a, double b, int y) =>
    ClassicalPoint.fromJson({
      'source_row_1based': row,
      'values': [a, b],
      'positive': y,
    });
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Fitted SVM scores, signed margins and width use the saved training transform', () async {
    final a = await ClassicalAssets.load();
    expect(a.svmTrainingRows, 1024);
    expect(a.svmPoints.length, 48);
    expect(a.snapshots.first.supportCount, 808);
    expect(a.snapshots.last.supportCount, 730);
    for (final m in a.snapshots) {
      expect(
        m.width,
        closeTo(
          2 / sqrt(m.weights[0] * m.weights[0] + m.weights[1] * m.weights[1]),
          1e-12,
        ),
      );
      for (final q in a.svmQueries) {
        final z = a.standardize(q.values);
        expect(
          m.signedMargin(z, q.positive),
          closeTo((2 * q.positive - 1) * m.score(z), 1e-12),
        );
      }
    }
    expect(a.snapshots.first.width, closeTo(2.323859480152266, 1e-10));
    expect(() => a.snapshots.first.score([double.nan, 0]), throwsArgumentError);
  });
  test('Neighbors use explicit pool order, selected exact matches and normalized weights', () {
    final pool = [point(1, 0, 0, 0), point(2, 0, 0, 1), point(3, 2, 0, 1)];
    final exact = NeighborResult.compute(
      pool,
      [0, 0],
      k: 3,
      scale: [1, 1],
      weighted: true,
    );
    expect(exact.probability, .5);
    expect(exact.exactOnly, isTrue);
    expect(exact.neighbors.map((n) => n.weight), [1, 1, 0]);
    final uniform = NeighborResult.compute(pool, [0, 0], k: 3, scale: [1, 1]);
    expect(uniform.probability, closeTo(2 / 3, 1e-12));
    final tied = NeighborResult.compute(
      [point(10, -1, 0, 0), point(20, 1, 0, 1)],
      [0, 0],
      k: 1,
      scale: [1, 1],
    );
    expect(tied.neighbors.first.point.sourceRow, 10);
  });
  test('Training scales and selected metrics can change the neighborhood', () {
    final pool = [point(1, 3, 0, 0), point(2, 0, 2, 1)];
    expect(
      NeighborResult.compute(
        pool,
        [0, 0],
        k: 1,
        scale: [10, 1],
        standardized: false,
      ).probability,
      1,
    );
    expect(
      NeighborResult.compute(pool, [0, 0], k: 1, scale: [10, 1]).probability,
      0,
    );
    final weighted = NeighborResult.compute(
      [point(1, 1, 0, 0), point(2, 2, 0, 1)],
      [0, 0],
      k: 2,
      scale: [1, 1],
      weighted: true,
    );
    expect(weighted.probability, closeTo(1 / 3, 1e-12));
  });
  test('Invalid neighbor sizes, scales and nonfinite points fail', () {
    final pool = [point(1, 1, 1, 0)];
    expect(
      () => NeighborResult.compute(pool, [0, 0], k: 0, scale: [1, 1]),
      throwsArgumentError,
    );
    expect(
      () => NeighborResult.compute(pool, [0, 0], k: 2, scale: [1, 1]),
      throwsArgumentError,
    );
    expect(
      () => NeighborResult.compute(pool, [0, 0], k: 1, scale: [0, 1]),
      throwsArgumentError,
    );
    expect(
      () => NeighborResult.compute(
        pool,
        [double.infinity, 0],
        k: 1,
        scale: [1, 1],
      ),
      throwsArgumentError,
    );
    expect(() => point(1, double.nan, 0, 0), throwsArgumentError);
  });
  test(
    'Gaussian log densities yield stable odds and posterior sensitivity',
    () {
      final means = [
            [0.0, 0.0],
            [2.0, 0.0],
          ],
          vars = [
            [1.0, 1.0],
            [1.0, 1.0],
          ];
      final r = GaussianResult.compute([0, 0], means, vars, .5);
      expect(r.logProbability[1] - r.logProbability[0], closeTo(-2, 1e-12));
      expect(
        r.logProbability.map(exp).reduce((a, b) => a + b),
        closeTo(1, 1e-12),
      );
      expect(
        GaussianResult.compute([0, 0], means, vars, .9).positiveProbability,
        greaterThan(r.positiveProbability),
      );
      expect(
        GaussianResult.compute(
          [0, 0],
          means,
          vars,
          .5,
          mode: 2,
        ).positiveProbability,
        .5,
      );
      final tail = GaussianResult.compute([1000, 1000], means, vars, .5);
      expect(tail.logProbability.every((x) => x.isFinite), isTrue);
      expect(
        () => GaussianResult.compute(
          [0, 0],
          means,
          [
            [0, 1],
            [1, 1],
          ],
          .5,
        ),
        throwsArgumentError,
      );
      expect(
        () => GaussianResult.compute([0, 0], means, vars, 1),
        throwsArgumentError,
      );
    },
  );
  test(
    'Real Gaussian posterior agrees with independent bundled library reference',
    () async {
      final a = await ClassicalAssets.load();
      final j = jsonDecode(
        await rootBundle.loadString(
          'assets/datasets/adult/classical_nb_lab.json',
        ),
      );
      for (var i = 0; i < a.nbQueries.length; i++) {
        final r = GaussianResult.compute(
          a.nbQueries[i].values,
          a.means,
          a.variances,
          a.priors[1],
        );
        for (var c = 0; c < 2; c++) {
          expect(
            r.logProbability[c],
            closeTo(j['reference_log_probability'][i][c], 1e-10),
          );
        }
      }
      expect(a.pool.length, 64);
      expect(a.epsilon, greaterThan(0));
      expect(() => a.pool.clear(), throwsUnsupportedError);
      expect(() => a.means.first.clear(), throwsUnsupportedError);
    },
  );
  test('Known source positions remain disjoint between displayed training and queries', () async {
    final a = await ClassicalAssets.load();
    final training = a.pool.map((p) => p.sourceRow).toSet();
    expect(a.knnQueries.any((p) => training.contains(p.sourceRow)), isFalse);
    for (final q in a.knnQueries) {
      final r = NeighborResult.compute(
        a.pool,
        q.values,
        k: 15,
        scale: a.knnScale,
        weighted: true,
      );
      expect(r.probability, inInclusiveRange(0, 1));
      expect(r.neighbors.length, 15);
    }
  });
  test(
    'Corrupt provenance, fitted normals and dataset shapes are rejected',
    () async {
      final raw = await Future.wait([
        for (final n in ['svm', 'knn', 'nb'])
          rootBundle.loadString(
            'assets/datasets/adult/classical_${n}_lab.json',
          ),
      ]);
      final s = jsonDecode(raw[0]) as Map<String, dynamic>,
          k = jsonDecode(raw[1]) as Map<String, dynamic>,
          b = jsonDecode(raw[2]) as Map<String, dynamic>;
      expect(
        () => ClassicalAssets.fromJson({...s, 'sha256': 'wrong'}, k, b),
        throwsFormatException,
      );
      final bad = jsonDecode(raw[0]) as Map<String, dynamic>;
      bad['snapshots'][0]['norm'] = 0;
      expect(() => ClassicalAssets.fromJson(bad, k, b), throwsFormatException);
    },
  );
}
