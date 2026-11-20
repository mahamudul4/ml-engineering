import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/features/unsupervised/unsupervised_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Nearest centers use squared Euclidean geometry and smallest-index ties',
    () {
      final centers = [
            [0.0, 0.0],
            [2.0, 0.0],
          ],
          points = [
            [0.0, 0.0],
            [1.0, 0.0],
            [2.0, 0.0],
          ];
      expect(nearestCenter(points[1], centers), 0);
      expect(clusteringInertia(points, centers), 1);
      expect(centers, [
        [0.0, 0.0],
        [2.0, 0.0],
      ]);
      expect(() => nearestCenter([0, 0], []), throwsArgumentError);
      expect(
        () => squaredDistance([double.nan, 0], [0, 0]),
        throwsArgumentError,
      );
      expect(() => clusteringInertia([], centers), throwsArgumentError);
    },
  );
  test(
    'Bundled Lloyd traces recompute objectives, assignments and mean updates',
    () async {
      final a = await UnsupervisedAssets.load(),
          points = a.points.map((p) => p.coordinates).toList();
      expect(points.length, 96);
      expect(a.runs.length, 4);
      for (final run in a.runs) {
        for (var t = 0; t < run.states.length; t++) {
          final s = run.states[t];
          expect(
            clusteringInertia(points, s.centers),
            closeTo(s.inertia, 1e-8),
          );
          if (t == 0) continue;
          final before = run.states[t - 1];
          expect(s.inertia, lessThanOrEqualTo(before.inertia + 1e-8));
          for (var c = 0; c < run.k; c++) {
            final members = [
              for (var i = 0; i < 96; i++)
                if (before.labels[i] == c) points[i],
            ];
            for (var d = 0; d < 2; d++) {
              final expected = members.isEmpty
                  ? before.centers[c][d]
                  : members.fold(0.0, (v, x) => v + x[d]) / members.length;
              expect(s.centers[c][d], closeTo(expected, 1e-10));
            }
          }
        }
      }
      expect(() => a.points[0].coordinates[0] = 0, throwsUnsupportedError);
      expect(() => a.runs.first.states.clear(), throwsUnsupportedError);
    },
  );
  test(
    'Density includes self, exact radius boundary and duplicate observations',
    () {
      final points = [
            [0.0, 0.0],
            [1.0, 0.0],
            [3.0, 0.0],
          ],
          r = DensityResult.compute(points, eps: 1, minSamples: 2);
      expect(r.counts, [2, 2, 1]);
      expect(r.core, [true, true, false]);
      expect(r.labels, [0, 0, -1]);
      expect(r.noise, 1);
      final duplicate = DensityResult.compute(
        [
          [0, 0],
          [0, 0],
          [1, 0],
        ],
        eps: 0,
        minSamples: 2,
      );
      expect(duplicate.labels, [0, 0, -1]);
      expect(duplicate.counts, [2, 2, 1]);
      expect(points, [
        [0, 0],
        [1, 0],
        [3, 0],
      ]);
    },
  );
  test('Non-core border never connects separated core components', () {
    // Four duplicates on each outside side, core anchors at -1 / +1,
    // and one ambiguous non-core border at zero. Radius 1, minSamples 5.
    final points = <List<double>>[
      [0, 0],
      [-1, 0],
      [-1.5, 0],
      [-1.5, 0],
      [-1.5, 0],
      [-1.5, 0],
      [1, 0],
      [1.5, 0],
      [1.5, 0],
      [1.5, 0],
      [1.5, 0],
    ];
    final r = DensityResult.compute(points, eps: 1, minSamples: 5);
    expect(r.core[0], isFalse);
    expect(r.counts[0], 3);
    expect(r.clusters, 2);
    expect(r.labels[0], 0);
    expect(r.labels[1], 0);
    expect(r.labels[6], 1);
    expect(r.borders, 1);
  });
  test('Runtime density matches independent Python references for actual observations', () async {
    final a = await UnsupervisedAssets.load(),
        j = jsonDecode(
          await rootBundle.loadString(
            'assets/datasets/adult/unsupervised_density_lab.json',
          ),
        );
    for (final ref in j['references']) {
      final r = DensityResult.compute(
        a.points.map((p) => p.coordinates).toList(),
        eps: (ref['eps'] as num).toDouble(),
        minSamples: ref['min_samples'],
      );
      expect(r.core, ref['core']);
      expect(r.labels, ref['labels']);
      expect(r.counts, ref['counts']);
    }
    final noise = DensityResult.compute(
      a.points.map((p) => p.coordinates).toList(),
      eps: .35,
      minSamples: 97,
    );
    expect(noise.noise, 96);
    expect(noise.clusters, 0);
    expect(noise.borders, 0);
    expect(() => noise.labels[0] = 3, throwsUnsupportedError);
    expect(
      () => DensityResult.compute(
        [
          [0, 0],
        ],
        eps: -1,
        minSamples: 1,
      ),
      throwsArgumentError,
    );
    expect(
      () => DensityResult.compute(
        [
          [0, 0],
        ],
        eps: 1,
        minSamples: 0,
      ),
      throwsArgumentError,
    );
  });
  test('PCA reconstruction obeys mean baseline, full basis and omitted singular energy', () async {
    final a = await UnsupervisedAssets.load();
    for (final p in a.pca) {
      expect(p.kept(0), 0);
      expect(p.kept(2), closeTo(1, 1e-12));
      for (final x in p.data) {
        expect(p.reconstruct(x, 0), p.mean);
        final full = p.reconstruct(x, 2);
        expect(full[0], closeTo(x[0], 1e-10));
        expect(full[1], closeTo(x[1], 1e-10));
        final restored = p.reconstruct(x, 1), v = p.components[0];
        expect(
          (x[0] - restored[0]) * v[0] + (x[1] - restored[1]) * v[1],
          closeTo(0, 1e-10),
        );
      }
      expect(
        p.mse(1) * p.data.length * 2,
        closeTo(pow(p.singular[1], 2).toDouble(), 1e-7),
      );
      expect(p.mse(0), greaterThan(p.mse(1)));
      expect(p.mse(2), lessThan(1e-20));
      expect(() => p.reconstruct([0, 0], 3), throwsArgumentError);
      expect(() => p.project([0], 1), throwsArgumentError);
    }
    expect(a.pca[0].ratio[0], isNot(closeTo(a.pca[1].ratio[0], 1e-4)));
  });
  test(
    'PCA sign changes preserve the projector and reject non-orthonormal assets',
    () async {
      final j = jsonDecode(
            await rootBundle.loadString(
              'assets/datasets/adult/unsupervised_pca_lab.json',
            ),
          ),
          original = j['runs'][1];
      final p = PcaFit.fromJson(original),
          flipped = jsonDecode(jsonEncode(original));
      flipped['components'][0] = [
        for (final v in original['components'][0]) -(v as num),
      ];
      final f = PcaFit.fromJson(flipped);
      for (final x in p.data) {
        final a = p.reconstruct(x, 1), b = f.reconstruct(x, 1);
        expect(a[0], closeTo(b[0], 1e-12));
        expect(a[1], closeTo(b[1], 1e-12));
      }
      flipped['components'][0] = [2, 0];
      expect(() => PcaFit.fromJson(flipped), throwsFormatException);
      expect(() => p.data.first[0] = 7, throwsUnsupportedError);
    },
  );
  test(
    'Asset parsing rejects source misalignment and inconsistent objectives',
    () async {
      final km = jsonDecode(
            await rootBundle.loadString(
              'assets/datasets/adult/unsupervised_kmeans_lab.json',
            ),
          ),
          pc = jsonDecode(
            await rootBundle.loadString(
              'assets/datasets/adult/unsupervised_pca_lab.json',
            ),
          );
      pc['source_rows'][0] = -1;
      expect(() => UnsupervisedAssets.fromJson(km, pc), throwsFormatException);
      km['runs'][0]['states'][0]['inertia'] = -1;
      expect(() => LloydRun.fromJson(km['runs'][0]), throwsFormatException);
    },
  );
}
