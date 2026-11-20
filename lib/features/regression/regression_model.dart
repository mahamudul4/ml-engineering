class RegressionModel {
  static const points = <(double, double)>[
    (1, 2),
    (2, 3),
    (3, 5),
    (4, 5),
    (5, 7),
    (6, 8),
  ];
  static double predict(double x, double weight, double bias) =>
      weight * x + bias;
  static double mse(double weight, double bias) =>
      points.fold<double>(
        0,
        (sum, p) =>
            sum +
            (predict(p.$1, weight, bias) - p.$2) *
                (predict(p.$1, weight, bias) - p.$2),
      ) /
      points.length;
  static (double, double) step(
    double weight,
    double bias, {
    double rate = .02,
  }) {
    var dw = 0.0;
    var db = 0.0;
    for (final p in points) {
      final e = predict(p.$1, weight, bias) - p.$2;
      dw += 2 * p.$1 * e / points.length;
      db += 2 * e / points.length;
    }
    return (weight - rate * dw, bias - rate * db);
  }

  static (double, double) fit() {
    final mx = points.fold<double>(0, (s, p) => s + p.$1) / points.length;
    final my = points.fold<double>(0, (s, p) => s + p.$2) / points.length;
    var numerator = 0.0;
    var denominator = 0.0;
    for (final p in points) {
      numerator += (p.$1 - mx) * (p.$2 - my);
      denominator += (p.$1 - mx) * (p.$1 - mx);
    }
    final w = numerator / denominator;
    return (w, my - w * mx);
  }
}
