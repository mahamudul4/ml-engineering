import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/features/diffusion/diffusion_model.dart';

Matcher nearList(List<double> expected, [double tolerance = 1e-9]) =>
    pairwiseCompare<double, double>(
      expected,
      (a, b) => (a - b).abs() < tolerance,
      'near reference',
    );
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DiffusionAssets a;
  setUpAll(() async {
    a = await DiffusionAssets.load();
  });
  test('Capped cosine alpha bar matches beta product and clean boundary', () {
    final bar = a.alphaBar, beta = DiffusionAssets.vector(a.data['beta']);
    expect(bar.length, 33);
    expect(bar[0], 1);
    var product = 1.0;
    for (var t = 1; t <= 32; t++) {
      product *= 1 - beta[t - 1];
      expect(bar[t], closeTo(product, 1e-14));
      expect(bar[t], lessThan(bar[t - 1]));
    }
  });
  test('All thirty real-image corruption marginals match Python', () {
    for (final row in a.samples) {
      final clean = DiffusionAssets.vector(row['unit_pixels'])
              .map((v) => 2 * v - 1)
              .toList(),
          eps = DiffusionAssets.vector(row['epsilon']);
      expect(noiseForward(clean, eps, 1), clean);
      for (final r in row['references']) {
        expect(
          noiseForward(clean, eps, a.alphaBar[r['t']]),
          nearList(DiffusionAssets.vector(r['xt'])),
        );
      }
    }
  });
  test('All conditional and null complete denoiser forwards match CPU', () {
    for (final row in a.samples) {
      for (final r in row['references']) {
        final x = DiffusionAssets.vector(r['xt']);
        expect(
          a.predict(x, r['t'], row['digit']),
          nearList(DiffusionAssets.vector(r['conditional'])),
        );
        expect(
          a.predict(x, r['t'], 10),
          nearList(DiffusionAssets.vector(r['null'])),
        );
      }
    }
  });
  test('All five full DDIM trajectories match Python including strided destinations', () {
    for (final r in a.data['traces']) {
      final actual = a.sample(
        label: r['label'],
        guidance: (r['guidance'] as num).toDouble(),
        steps: r['steps'],
      );
      expect(actual.length, r['trace'].length);
      for (var i = 0; i < actual.length; i++) {
        expect(actual[i].t, r['trace'][i]['t']);
        expect(
          actual[i].pixels,
          nearList(DiffusionAssets.vector(r['trace'][i]['pixels']), 1e-8),
        );
      }
      expect(actual.last.t, 0);
    }
  });
  test('CFG endpoints, extrapolation and final DDIM clean boundary', () {
    final u = List.filled(64, 2.0), c = List.filled(64, 5.0);
    expect(guidedNoise(u, c, 0), u);
    expect(guidedNoise(u, c, 1), c);
    expect(guidedNoise(u, c, 2), List.filled(64, 8.0));
    expect(
      ddimStep(List.filled(64, .5), List.filled(64, 0), .25, 1),
      List.filled(64, 1),
    );
  });
  test(
    'Unclipped epsilon error amplification agrees with independent algebra',
    () {
      const alpha = .01;
      final x = List.filled(64, .2), eps = List.filled(64, .3);
      final noisy = noiseForward(x, eps, alpha);
      final clean = cleanEstimate(noisy, eps, alpha, clip: false);
      expect(clean, nearList(x));
      final wrong = cleanEstimate(
        noisy,
        List.filled(64, .4),
        alpha,
        clip: false,
      );
      expect(wrong.first - x.first, closeTo(-math.sqrt(99) * .1, 1e-12));
    },
  );
  test('Ten image embeddings, ten name embeddings and one hundred cosine scores match CPU', () async {
    for (var i = 0; i < 10; i++) {
      final row = a.samples[i],
          x = DiffusionAssets.vector(a.samples[i]['unit_pixels']);
      expect(
        a.imageEmbedding(x),
        nearList(DiffusionAssets.vector(row['image_embedding'])),
      );
      expect(
        a.textEmbedding(i),
        nearList(DiffusionAssets.vector(a.data['text_embeddings'][i])),
      );
      expect(
        a.similarities(x),
        nearList(DiffusionAssets.vector(row['cosines'])),
      );
    }
    // Declared numerical edge fixture: match PyTorch F.normalize epsilon policy.
    final json = jsonDecode(
      await rootBundle.loadString('assets/datasets/digits/diffusion_lab.json'),
    ) as Map<String, dynamic>;
    json['weights']['alignment']['names.weight'][0] = List.filled(8, 1e-14);
    expect(
      DiffusionAssets.fromJson(json).textEmbedding(0),
      nearList(List.filled(8, .01), 1e-12),
    );
  });
  test('Temperature softmax is stable and keeps ranking', () {
    final cold = probabilities([.1, .8, .3], .1),
        warm = probabilities([.1, .8, .3], .5);
    expect(cold.indexOf(cold.reduce(math.max)), 1);
    expect(warm.indexOf(warm.reduce(math.max)), 1);
    expect(cold[1], greaterThan(warm[1]));
    expect(warm.reduce((x, y) => x + y), closeTo(1, 1e-12));
    expect(probabilities([1000, -1000], .1), [1, 0]);
  });
  test(
    'Invalid numerical inputs and malformed schedules fail explicitly',
    () async {
      for (final fn in [
        () => a.predict(List.filled(64, 0), 0, 0),
        () => a.predict(List.filled(64, 0), 1, 11),
        () => a.predict([0], 1, 0),
        () => a.sample(steps: 4),
        () => a.sample(guidance: double.nan),
        () => noiseForward(List.filled(64, 0), List.filled(64, 0), 0),
        () => guidedNoise(List.filled(64, 0), List.filled(64, 0), 5),
        () => probabilities([], 1),
        () => probabilities([0], 0),
        () => a.imageEmbedding(List.filled(64, 2)),
      ]) {
        expect(fn, throwsArgumentError);
      }
      final j = jsonDecode(
        await rootBundle.loadString(
          'assets/datasets/digits/diffusion_lab.json',
        ),
      ) as Map<String, dynamic>;
      j['alpha_bar'][1] = 1;
      expect(() => DiffusionAssets.fromJson(j), throwsFormatException);
    },
  );
  test(
    'Source roles stay separate and nested frozen evidence is immutable',
    () {
      final fit = (a.report['fit_rows_1based'] as List).toSet(),
          diag = (a.report['diagnostic_rows_1based'] as List).toSet();
      expect(fit.length, 1438);
      expect(diag.length, 359);
      expect(fit.intersection(diag), isEmpty);
      expect(() => a.samples.clear(), throwsUnsupportedError);
      expect(() => a.samples[0]['epsilon'][0] = 0, throwsUnsupportedError);
      expect(() => a.sample().first.pixels.clear(), throwsUnsupportedError);
    },
  );
}
