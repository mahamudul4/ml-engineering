import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/features/preparation/preparation_model.dart';

void main() {
  test('imputation then scaling matches the worked example', () {
    final recipe = NumericRecipe.fit([10, 20, null, 90]);
    expect(recipe.fill, 20);
    expect(recipe.mean, 35);
    expect(recipe.std, closeTo(math.sqrt(1025), 1e-12));
    expect(recipe.impute(null), 20);
    expect(recipe.transform(35), 0);
    final mean = NumericRecipe.fit([
      10,
      20,
      null,
      90,
    ], strategy: FillStrategy.mean);
    expect(mean.fill, 40);
    expect(mean.mean, 40);
    expect(NumericRecipe.fit([10, 20, 30, 40]).fill, 25);
  });
  test('transform never learns from a changed held-out value', () {
    final train = <double?>[10, 20, null, 90];
    final recipe = NumericRecipe.fit(train);
    for (final heldout in [40.0, 140.0, 200.0]) {
      expect(recipe.transform(heldout), (heldout - 35) / math.sqrt(1025));
      expect(recipe.fill, 20);
      expect(recipe.mean, 35);
      expect(recipe.fitRows, 4);
    }
    final leaked = NumericRecipe.fit([...train, 140]);
    expect(leaked.fill, 55);
    expect(leaked.mean, 63);
    expect(train, [
      10,
      20,
      null,
      90,
    ], reason: 'Input records must not be mutated');
  });
  test('empty, all-missing, constant and non-finite policies are explicit', () {
    expect(() => NumericRecipe.fit([]), throwsArgumentError);
    expect(() => NumericRecipe.fit([null, null]), throwsArgumentError);
    expect(() => NumericRecipe.fit([double.nan]), throwsArgumentError);
    expect(() => NumericRecipe.fit([double.infinity]), throwsArgumentError);
    final constant = NumericRecipe.fit([5, 5, null]);
    expect(constant.std, 0);
    expect(constant.scale, 1);
    expect(constant.transform(null), 0);
    expect(() => constant.transform(double.nan), throwsArgumentError);
  });
  test('frozen vocabulary ignores unseen values without adding columns', () {
    final encoder = FrozenEncoder.fit(['A', 'A', 'B', 'C', null]);
    expect(encoder.vocabulary, ['A', 'B', 'C', FrozenEncoder.missing]);
    expect(encoder.encode('B'), [0, 1, 0, 0]);
    expect(encoder.encode('D'), [0, 0, 0, 0]);
    expect(encoder.encode('D', policy: UnknownPolicy.infrequentIfExists), [
      0,
      0,
      0,
      0,
    ]);
    expect(encoder.encode(null), [0, 0, 0, 1]);
    expect(encoder.vocabulary.length, 4);
  });
  test('unknown maps to a rare bucket only if fitted and policy allows it', () {
    final encoder = FrozenEncoder.fit([
      'A',
      'A',
      'B',
      'C',
      null,
    ], minFrequency: 2);
    expect(encoder.vocabulary, ['A', FrozenEncoder.infrequent]);
    expect(encoder.encode('D'), [0, 0]);
    expect(encoder.encode('D', policy: UnknownPolicy.infrequentIfExists), [
      0,
      1,
    ]);
    expect(encoder.encode('B'), [0, 1]);
    expect(encoder.encode(null), [0, 1]);
    expect(encoder.encode('A'), [1, 0]);
    expect(() => encoder.vocabulary.add('D'), throwsUnsupportedError);
  });
  test('categorical all-missing and invalid contracts are handled', () {
    final allMissing = FrozenEncoder.fit([null, null]);
    expect(allMissing.encode(null), [1]);
    expect(() => FrozenEncoder.fit([]), throwsArgumentError);
    expect(
      () => FrozenEncoder.fit(['A'], minFrequency: 0),
      throwsArgumentError,
    );
    expect(
      () => FrozenEncoder.fit([FrozenEncoder.missing]),
      throwsArgumentError,
    );
  });
}
