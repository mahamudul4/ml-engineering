import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/features/generative/generative_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GenerativeAssets a;
  setUpAll(() async {
    a = await GenerativeAssets.load();
  });
  test(
    'Ten real diagnostic encodings, reconstructions, BCE and KL match PyTorch',
    () {
      for (final row in a.images) {
        final x = GenerativeAssets.vector(row['pixels']);
        final (mu, lv) = a.encode(x);
        expect(
          mu,
          orderedEqualsWithTolerance(GenerativeAssets.vector(row['mu']), 1e-12),
        );
        expect(
          lv,
          orderedEqualsWithTolerance(
            GenerativeAssets.vector(row['logvar']),
            1e-12,
          ),
        );
        expect(
          a.decode(mu),
          orderedEqualsWithTolerance(
            GenerativeAssets.vector(row['reconstruction']),
            1e-12,
          ),
        );
        expect(gaussianKL(mu, lv), closeTo(row['kl'], 1e-12));
        expect(
          reconstructionBCE(a.decodeLogits(mu), x),
          closeTo(row['bce'], 1e-10),
        );
      }
    },
  );
  test('All sixteen actual generator, decoder and discriminator forwards match CPU', () {
    for (final r in a.samples) {
      final z = GenerativeAssets.vector(r['z']);
      final fake = a.generate(z);
      expect(
        fake,
        orderedEqualsWithTolerance(GenerativeAssets.vector(r['gan']), 1e-12),
      );
      expect(
        a.decode(z),
        orderedEqualsWithTolerance(GenerativeAssets.vector(r['vae']), 1e-12),
      );
      expect(a.discriminate(fake), closeTo(r['d_fake'], 1e-12));
    }
  });
  test('Gaussian KL independent known cases and nonunit variance', () {
    expect(gaussianKL([0, 0], [0, 0]), 0);
    expect(gaussianKL([1, 0], [0, 0]), .5);
    expect(
      gaussianKL([1], [math.log(4)]),
      closeTo(.5 * (4 - math.log(4)), 1e-12),
    );
  });
  test('Pathwise sample and finite-difference derivatives', () {
    expect(reparameterize([1, -1], [0, 0], [2, -2]), [3, -3]);
    const h = 1e-5;
    final up = reparameterize([1], [h], [2]).single,
        down = reparameterize([1], [-h], [2]).single;
    expect((up - down) / (2 * h), closeTo(1, 1e-9));
  });
  test('Stable BCE extreme logits and soft targets', () {
    expect(reconstructionBCE([1000, -1000], [0, 1]), 2000);
    expect(
      reconstructionBCE([1000, -1000, 0], [1, 0, .5]),
      closeTo(math.log(2), 1e-12),
    );
    expect(softplus(1000), 1000);
    expect(sigmoid(-1000), 0);
  });
  test('Minimax saturation and non-saturating logit finite differences', () {
    const x = -8.0, h = 1e-4;
    final mini = (-softplus(x + h) + softplus(x - h)) / (2 * h),
        non = (softplus(-x - h) - softplus(-x + h)) / (2 * h);
    expect(mini, closeTo(-sigmoid(x), 1e-9));
    expect(non, closeTo(sigmoid(x) - 1, 1e-9));
    expect(non.abs(), greaterThan(.999));
    expect(mini.abs(), lessThan(.001));
  });
  test('Malformed dimensions, invalid values and overflow fail explicitly', () {
    for (final fn in [
      () => gaussianKL([], []),
      () => gaussianKL([0], [double.nan]),
      () => gaussianKL([0], [1000]),
      () => reparameterize([0], [0], []),
      () => a.encode(List.filled(64, 2)),
      () => a.generate([0]),
      () => a.decode([double.infinity, 0]),
      () => reconstructionBCE([0], [2]),
    ]) {
      expect(fn, throwsArgumentError);
    }
  });
  test('Shape-invalid saved weights are rejected before inference', () async {
    final j = jsonDecode(
      await rootBundle.loadString('assets/datasets/digits/generative_lab.json'),
    ) as Map<String, dynamic>;
    j['weights']['vae']['enc.weight'] = [
      [0.0],
    ];
    expect(() => GenerativeAssets.fromJson(j), throwsFormatException);
  });
  test(
    'Source role IDs stay disjoint and exported nested evidence is immutable',
    () {
      final train = (a.report['train_rows_1based'] as List).toSet(),
          diag = (a.report['diagnostic_rows_1based'] as List).toSet();
      expect(train.length, 1438);
      expect(diag.length, 359);
      expect(train.intersection(diag), isEmpty);
      expect(() => a.images.clear(), throwsUnsupportedError);
      expect(() => a.images.first['pixels'][0] = 1, throwsUnsupportedError);
    },
  );
}

Matcher orderedEqualsWithTolerance(List<double> expected, double epsilon) =>
    pairwiseCompare<double, double>(
      expected,
      (a, b) => (a - b).abs() <= epsilon,
      'within $epsilon of reference',
    );
