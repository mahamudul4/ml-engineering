import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/features/attention/attention_model.dart';

void main() {
  final raw = jsonDecode(
        File('assets/datasets/bike_sharing/attention_lab.json')
            .readAsStringSync(),
      ) as Map<String, dynamic>,
      a = AttentionAssets.fromJson(raw);
  Map<String, dynamic> fresh() =>
      jsonDecode(jsonEncode(raw)) as Map<String, dynamic>;
  void near(dynamic got, dynamic expected, {double tolerance = 1e-10}) {
    if (got is List) {
      expect(got.length, (expected as List).length);
      for (var i = 0; i < got.length; i++) {
        near(got[i], expected[i], tolerance: tolerance);
      }
    } else {
      expect(
        (got as num).toDouble(),
        closeTo((expected as num).toDouble(), tolerance),
      );
    }
  }

  test('All15 actual-window Transformer modes match independent PyTorch intermediates', () {
    for (var i = 0; i < 3; i++) {
      for (final r in raw['queries'][i]['references'] as List) {
        final t = a.model.run(
              a.queries[i].standardized,
              causal: r['causal'],
              valid: r['valid'],
              usePosition: r['use_position'],
            ),
            ref = r['trace'];
        for (final key in t.matrices.keys) {
          near(t.matrices[key], ref[key]);
        }
        for (final pair in [
          (t.q, 'q'),
          (t.k, 'k'),
          (t.v, 'v'),
          (t.scores, 'scores'),
          (t.weights, 'weights'),
          (t.mixed, 'mixed'),
        ]) {
          near(pair.$1, ref[pair.$2]);
        }
        near(t.prediction, ref['prediction']);
      }
    }
  });
  test(
    'Causal and padding masks give zero blocked mass and normalized valid rows',
    () {
      // A single block's final query sees the same full history in both modes.
      final source = a.queries.first.standardized;
      final causalLast = a.model.run(source);
      final fullLast = a.model.run(source, causal: false);
      near(causalLast.prediction, fullLast.prediction);
      near(
        causalLast.matrices['state']!.last,
        fullLast.matrices['state']!.last,
      );
      for (final causal in [false, true]) {
        for (final valid in [1, 10, 14]) {
          final t = a.model.run(
            a.queries.first.standardized,
            causal: causal,
            valid: valid,
          );
          for (var h = 0; h < 2; h++) {
            for (var i = 0; i < 14; i++) {
              expect(
                t.weights[h][i].reduce((a, b) => a + b),
                closeTo(1, 1e-12),
              );
              for (var j = 0; j < 14; j++) {
                if (j >= valid || (causal && j > i)) {
                  expect(t.weights[h][i][j], 0);
                } else {
                  expect(t.weights[h][i][j], greaterThanOrEqualTo(0));
                }
              }
            }
          }
          if (causal) {
            near(t.weights.first.first, [1, ...List.filled(13, 0)]);
          }
        }
      }
    },
  );
  test(
    'Reordering later valid actual values preserves causal query prefix only',
    () {
      final s = a.queries.first.standardized,
          changed = [
            ...s.take(6),
            ...s.skip(6).take(4).toList().reversed,
            ...s.skip(10),
          ];
      final causal = a.model.run(s, valid: 10),
          other = a.model.run(changed, valid: 10);
      near(
        causal.matrices['state']!.take(6).toList(),
        other.matrices['state']!.take(6).toList(),
      );
      final full = a.model.run(s, causal: false, valid: 10),
          fullChanged = a.model.run(changed, causal: false, valid: 10);
      final delta = List.generate(
        4,
        (k) =>
            (full.matrices['state']![5][k] -
                    fullChanged.matrices['state']![5][k])
                .abs(),
      ).reduce(max);
      expect(delta, greaterThan(1e-8));
      final padChanged = [...s.take(10), ...List.filled(4, 99999.0)];
      near(
        causal.matrices['state']!.take(10).toList(),
        a.model.run(padChanged, valid: 10).matrices['state']!.take(10).toList(),
      );
    },
  );
  test('Head mixture and residual equations agree with independently summed values', () {
    final t = a.model.run(a.queries.first.standardized);
    for (var h = 0; h < 2; h++) {
      for (var i = 0; i < 14; i++) {
        for (var d = 0; d < 2; d++) {
          final expected = List.generate(
            14,
            (j) => t.weights[h][i][j] * t.v[h][j][d],
          ).reduce((a, b) => a + b);
          near(t.mixed[h][i][d], expected);
        }
      }
    }
    for (var i = 0; i < 14; i++) {
      near(t.matrices['concat']![i], [...t.mixed[0][i], ...t.mixed[1][i]]);
      for (var k = 0; k < 4; k++) {
        near(
          t.matrices['residual1']![i][k],
          t.matrices['embedding']![i][k] + t.matrices['attention']![i][k],
        );
        near(
          t.matrices['state']![i][k],
          t.matrices['residual1']![i][k] + t.matrices['ff_output']![i][k],
        );
      }
    }
  });
  test('Sinusoidal positions and full no-position permutation equivariance are explicit', () {
    final pe = sinusoidalPositions();
    near(pe.first, [0, 1, 0, 1]);
    near(pe[3], [sin(3), cos(3), sin(.03), cos(.03)]);
    final s = a.queries.first.standardized,
        order = List.generate(14, (i) => 13 - i),
        permuted = [for (final i in order) s[i]];
    final first = a.model.run(s, causal: false, usePosition: false),
        second = a.model.run(permuted, causal: false, usePosition: false);
    near(second.matrices['state'], [
      for (final i in order) first.matrices['state']![i],
    ]);
    final positioned = a.model.run(s), off = a.model.run(s, usePosition: false);
    expect((positioned.prediction - off.prediction).abs(), greaterThan(1e-6));
  });
  test('Training roles calendar transform and immutable forward evidence are preserved', () {
    expect(a.queries.map((q) => q.targetIndex), [365, 400, 540]);
    expect(a.mean, closeTo(3405.7616438356163, 1e-10));
    expect(a.scale, closeTo(1376.8636667749531, 1e-10));
    final t = a.model.run(a.queries.first.standardized);
    expect(() => t.weights[0][0][0] = 0, throwsUnsupportedError);
    expect(() => t.matrices['state']![0][0] = 0, throwsUnsupportedError);
    expect(() => t.matrices.clear(), throwsUnsupportedError);
    expect(
      () => a.model.matrices['position']![0][0] = 0,
      throwsUnsupportedError,
    );
    expect(() => a.queries.first.counts[0] = 0, throwsUnsupportedError);
    expect((raw['train_history'] as List).length, 81);
    expect(
      raw['train_history'].last['train_mse_scaled'],
      lessThan(raw['train_history'].first['train_mse_scaled']),
    );
    expect(
      raw['rolling_metrics']['transformer']['mae'],
      greaterThan(raw['rolling_metrics']['naive']['mae']),
    );
    expect(
      raw['rolling_metrics']['transformer']['rmse'],
      lessThan(raw['rolling_metrics']['naive']['rmse']),
    );
  });
  test(
    'Nonfinite inputs, wrong sequence widths and empty visibility lengths fail',
    () {
      for (final s in <List<double>>[
        [],
        List.filled(13, 0),
        List.filled(15, 0),
        List.filled(14, double.nan),
        List.filled(14, double.infinity),
        List.filled(14, 1e308),
      ]) {
        expect(() => a.model.run(s), throwsArgumentError);
      }
      for (final n in [-1, 0, 15]) {
        expect(
          () => a.model.run(a.queries.first.standardized, valid: n),
          throwsArgumentError,
        );
      }
    },
  );
  test(
    'Corrupt positional weights, dates, scaling and model schema fail early',
    () {
      for (final change in <void Function(Map<String, dynamic>)>[
        (j) => j['scale'] = 0,
        (j) => j['parameter_count'] = 241,
        (j) => j['heads'] = 3,
        (j) => j['weights']['attn.in_proj_weight'][0] = [1, 2],
        (j) => j['weights']['position'][0][0] = 1,
        (j) => j['weights']['norm1.weight'] = [1, 2],
        (j) => j['queries'][2]['target_date'] = '2012-07-01',
        (j) => j['queries'][0]['history_dates'][0] = '2011-11-48',
        (j) => j['queries'][0]['standardized'][0] = 999,
      ]) {
        final j = fresh();
        change(j);
        expect(() => AttentionAssets.fromJson(j), throwsA(anything));
      }
    },
  );
}
