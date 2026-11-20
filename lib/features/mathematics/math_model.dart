import 'dart:math';

class MathVector {
  final double x, y;
  MathVector(this.x, this.y) {
    if (!x.isFinite || !y.isFinite) {
      throw ArgumentError('Finite coordinates required.');
    }
  }
  MathVector scale(double amount) => MathVector(x * amount, y * amount);
  MathVector minus(MathVector other) => MathVector(x - other.x, y - other.y);
  double dot(MathVector other) {
    final result = x * other.x + y * other.y;
    if (!result.isFinite) throw ArgumentError('Dot product overflow.');
    return result;
  }

  double get norm {
    final scale = max(x.abs(), y.abs());
    if (scale == 0) return 0;
    final result = scale * sqrt(pow(x / scale, 2) + pow(y / scale, 2));
    if (!result.isFinite) throw ArgumentError('Vector norm overflow.');
    return result;
  }
}

class VectorProjection {
  final MathVector unit, projected, residual;
  final double signedLength;
  VectorProjection._(
    this.unit,
    this.projected,
    this.residual,
    this.signedLength,
  );
  factory VectorProjection.of(MathVector point, MathVector direction) {
    final norm = direction.norm;
    if (norm == 0) {
      throw ArgumentError('Cannot project onto the zero direction.');
    }
    // Normalize by division, avoiding reciprocal overflow for tiny directions.
    final unit = MathVector(direction.x / norm, direction.y / norm);
    final amount = point.dot(unit);
    final projected = unit.scale(amount);
    return VectorProjection._(unit, projected, point.minus(projected), amount);
  }
}

/// A rotated SPD quadratic with eigenvalues 1 and kappa, minimum at the origin.
class QuadraticSurface {
  final double kappa;
  static const angle = pi / 6;
  QuadraticSurface(this.kappa) {
    if (!kappa.isFinite || kappa < 1 || kappa > 100) {
      throw ArgumentError('Curvature ratio must be in 1..100.');
    }
  }
  MathVector gradient(MathVector point) {
    final c = cos(angle), s = sin(angle);
    final low = c * point.x + s * point.y;
    final high = -s * point.x + c * point.y;
    return MathVector(c * low - s * kappa * high, s * low + c * kappa * high);
  }

  double loss(MathVector point) {
    final c = cos(angle), s = sin(angle);
    final low = c * point.x + s * point.y;
    final high = -s * point.x + c * point.y;
    final result = .5 * (low * low + kappa * high * high);
    if (!result.isFinite) throw ArgumentError('Loss overflow.');
    return result;
  }
}

class QuadraticRun {
  final List<MathVector> points;
  final List<double> losses;
  final bool stopped;
  QuadraticRun._(List<MathVector> points, List<double> losses, this.stopped)
    : points = List.unmodifiable(points),
      losses = List.unmodifiable(losses);
  factory QuadraticRun.compute({
    required double kappa,
    required double ratio,
    required int steps,
  }) {
    if (!ratio.isFinite ||
        ratio <= 0 ||
        ratio > 3 ||
        steps < 0 ||
        steps > 100) {
      throw ArgumentError('Use positive eta*L <= 3 and 0..100 steps.');
    }
    final surface = QuadraticSurface(kappa);
    final rate = ratio / kappa;
    final points = [MathVector(3, 2)];
    final losses = [surface.loss(points.first)];
    var stopped = false;
    for (var i = 0; i < steps; i++) {
      final next = points.last.minus(surface.gradient(points.last).scale(rate));
      final loss = surface.loss(next);
      if (next.norm > 1e6 || loss > 1e12) {
        stopped = true;
        break;
      }
      points.add(next);
      losses.add(loss);
    }
    return QuadraticRun._(points, losses, stopped);
  }
}
