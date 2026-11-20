import 'dart:math' as math;

/// A specified teaching MDP; the probabilities and rewards are assumptions.
/// Start: safe -> terminal(+1), advance -> Middle(0).
/// Middle: safe -> terminal(+1), try -> terminal(+4) or Start(-1).
class BellmanModel {
  final double discount, successProbability;
  BellmanModel({this.discount = .9, this.successProbability = .7}) {
    if (!discount.isFinite ||
        discount < 0 ||
        discount >= 1 ||
        !successProbability.isFinite ||
        successProbability < 0 ||
        successProbability > 1) {
      throw ArgumentError(
        'Expected 0 <= discount < 1 and 0 <= probability <= 1',
      );
    }
  }

  List<double> actionValues(List<double> values, int state) {
    if (values.length != 3 || !values.every((value) => value.isFinite)) {
      throw ArgumentError('Expected three finite state values');
    }
    return switch (state) {
      0 => [1, discount * values[1]],
      1 => [
        1,
        successProbability * 4 +
            (1 - successProbability) * (-1 + discount * values[0]),
      ],
      2 => [0, 0],
      _ => throw RangeError.range(state, 0, 2, 'state'),
    };
  }

  /// Both updates read the old vector: this is a synchronous sweep.
  List<double> sweep(List<double> values) => [
    for (var state = 0; state < 3; state++)
      actionValues(values, state).reduce(math.max),
  ];

  double change(List<double> before, List<double> after) =>
      [for (var i = 0; i < 3; i++) (before[i] - after[i]).abs()]
          .reduce(math.max);

  // A posteriori error bound for the NEW iterate in this exact discounted MDP.
  double errorBound(double change) => discount * change / (1 - discount);
}
