import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/features/mathematics/math_model.dart';

void main() {
  test(
    'projection decomposes into orthogonal components and preserves Pythagoras',
    () {
      final x = MathVector(3, 2);
      for (final u in [MathVector(1, 0), MathVector(1, 1), MathVector(-2, 3)]) {
        final result = VectorProjection.of(x, u);
        expect(result.residual.dot(result.unit), closeTo(0, 1e-12));
        expect(
          result.projected.dot(result.projected) +
              result.residual.dot(result.residual),
          closeTo(13, 1e-12),
        );
        final twice = VectorProjection.of(result.projected, u);
        expect(twice.projected.x, closeTo(result.projected.x, 1e-12));
        expect(twice.projected.y, closeTo(result.projected.y, 1e-12));
      }
    },
  );
  test('projection is unchanged by scaling/sign and supports a tiny nonzero direction', () {
    final x = MathVector(3, 2);
    for (final scale in [1.0, -2.0, 1e-300]) {
      final p = VectorProjection.of(x, MathVector(scale, 0));
      expect(p.projected.x, closeTo(3, 1e-12));
      expect(p.projected.y, 0);
      expect(p.residual.y, 2);
    }
  });
  test(
    'zero and nonfinite directions fail instead of returning false geometry',
    () {
      expect(
        () => VectorProjection.of(MathVector(3, 2), MathVector(0, 0)),
        throwsArgumentError,
      );
      expect(() => MathVector(double.nan, 0), throwsArgumentError);
      expect(() => MathVector(0, double.infinity), throwsArgumentError);
      expect(
        () => MathVector(1e308, 1e308).dot(MathVector(2, 2)),
        throwsArgumentError,
      );
      expect(MathVector(1e300, 0).norm, 1e300);
    },
  );
  test(
    'rotated quadratic gradient matches independent central differences',
    () {
      const h = 1e-5;
      for (final kappa in [1.0, 5.0, 20.0]) {
        final surface = QuadraticSurface(kappa);
        for (final point in [MathVector(3, 2), MathVector(-.5, 1.2)]) {
          final g = surface.gradient(point);
          final dx =
              (surface.loss(MathVector(point.x + h, point.y)) -
                  surface.loss(MathVector(point.x - h, point.y))) /
              (2 * h);
          final dy =
              (surface.loss(MathVector(point.x, point.y + h)) -
                  surface.loss(MathVector(point.x, point.y - h))) /
              (2 * h);
          expect(g.x, closeTo(dx, 1e-7));
          expect(g.y, closeTo(dy, 1e-7));
        }
      }
    },
  );
  test('stable descent is monotone, immutable and deterministic', () {
    final run = QuadraticRun.compute(kappa: 20, ratio: .8, steps: 100);
    for (var i = 1; i < run.losses.length; i++) {
      expect(run.losses[i], lessThanOrEqualTo(run.losses[i - 1] + 1e-12));
    }
    expect(run.losses.last, lessThan(run.losses.first / 100));
    expect(run.stopped, isFalse);
    expect(
      run.losses,
      QuadraticRun.compute(kappa: 20, ratio: .8, steps: 100).losses,
    );
    expect(() => run.losses.add(4), throwsUnsupportedError);
    expect(() => run.points.add(MathVector(0, 0)), throwsUnsupportedError);
  });
  test(
    'isotropic exact step and stability boundary match eigenvalue theory',
    () {
      final exact = QuadraticRun.compute(kappa: 1, ratio: 1, steps: 1);
      expect(exact.losses.last, closeTo(0, 1e-25));
      final boundary = QuadraticRun.compute(kappa: 1, ratio: 2, steps: 10);
      expect(boundary.losses.last, closeTo(boundary.losses.first, 1e-10));
    },
  );
  test(
    'unstable steps stop before invalid numbers enter the recorded trajectory',
    () {
      final run = QuadraticRun.compute(kappa: 5, ratio: 2.4, steps: 100);
      expect(run.stopped, isTrue);
      expect(run.losses.length, lessThan(101));
      expect(run.losses.every((v) => v.isFinite && v <= 1e12), isTrue);
      expect(run.points.every((v) => v.norm <= 1e6), isTrue);
      expect(run.losses.last, greaterThan(run.losses.first));
    },
  );
  test('curvature and step settings reject invalid contracts', () {
    for (final kappa in [0.0, -1.0, 101.0, double.nan]) {
      expect(
        () => QuadraticRun.compute(kappa: kappa, ratio: .8, steps: 1),
        throwsArgumentError,
      );
    }
    for (final ratio in [0.0, -1.0, 4.0, double.infinity]) {
      expect(
        () => QuadraticRun.compute(kappa: 5, ratio: ratio, steps: 1),
        throwsArgumentError,
      );
    }
    expect(
      () => QuadraticRun.compute(kappa: 5, ratio: .8, steps: 101),
      throwsArgumentError,
    );
  });
}
