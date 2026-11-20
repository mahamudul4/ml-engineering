import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/features/regression/regression_model.dart';

void main() {
  test('prediction and MSE agree with the lesson walkthrough', () {
    expect(RegressionModel.predict(4, 2.5, 1), 11);
    expect(RegressionModel.mse(1, 0), 2.5);
  });
  test('gradient descent reduces the initial loss', () {
    final next = RegressionModel.step(.6, .4);
    expect(
      RegressionModel.mse(next.$1, next.$2),
      lessThan(RegressionModel.mse(.6, .4)),
    );
    var w = .6, b = .4;
    for (int i = 0; i < 2000; i++) {
      final p = RegressionModel.step(w, b);
      w = p.$1;
      b = p.$2;
    }
    expect(w, closeTo(1.2, .001));
    expect(b, closeTo(.8, .001));
  });
  test('least-squares fit reaches the analytic optimum', () {
    final fit = RegressionModel.fit();
    expect(fit.$1, closeTo(1.2, 1e-10));
    expect(fit.$2, closeTo(.8, 1e-10));
    expect(RegressionModel.mse(fit.$1, fit.$2), closeTo(2 / 15, 1e-10));
    expect(RegressionModel.mse(fit.$1 + .01, fit.$2), greaterThan(2 / 15));
  });
}
