import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/features/sequence/sequence_model.dart';

void main() {
  final raw = jsonDecode(
    File('assets/datasets/bike_sharing/sequence_lab.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final a = SequenceAssets.fromJson(raw);
  Map<String, dynamic> fresh() =>
      jsonDecode(jsonEncode(raw)) as Map<String, dynamic>;
  void near(List<double> got, dynamic expected, {double tolerance = 1e-11}) {
    expect(got.length, (expected as List).length);
    for (var k = 0; k < got.length; k++) {
      expect(got[k], closeTo((expected[k] as num).toDouble(), tolerance));
    }
  }

  test('All real-window RNN GRU LSTM hidden states and gates match PyTorch-checked traces', () {
    for (var i = 0; i < 3; i++) {
      for (final ref in raw['queries'][i]['cell_references'] as List) {
        final trace = a.cells[ref['name']]!.trace(a.queries[i].standardized);
        expect(trace.length, 14);
        for (var t = 0; t < 14; t++) {
          near(trace[t].hidden, ref['trace'][t]['hidden']);
          near(trace[t].cell, ref['trace'][t]['cell']);
          for (final key in trace[t].gates.keys) {
            near(trace[t].gates[key]!, ref['trace'][t]['gates'][key]);
          }
        }
      }
    }
  });
  test('GRU gates reset the hidden candidate bias inside the candidate affine term', () {
    final j = fresh()['cells'][2] as Map<String, dynamic>, p = j['parameters'];
    p['w_ih'] = List.generate(9, (_) => [0.0]);
    p['w_hh'] = List.generate(9, (_) => List.filled(3, 0.0));
    p['b_ih'] = List.filled(9, 0.0);
    p['b_hh'] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.0, 2.0, 2.0];
    final state = RecurrentWeights.fromJson(j).trace([0]).single;
    final candidate = (exp(2) - 1) / (exp(2) + 1);
    near(state.gates['reset']!, [.5, .5, .5]);
    near(state.hidden, [.5 * candidate, .5 * candidate, .5 * candidate]);
    expect(
      (state.hidden[0] - .5 * ((exp(4) - 1) / (exp(4) + 1))).abs(),
      greaterThan(.05),
    );
  });
  test(
    'Unsorted right-padded lengths reproduce packed and naive PyTorch states',
    () {
      final cell = a.cells['gru_trained']!;
      for (var i = 0; i < 3; i++) {
        final q = a.padding[i], ref = raw['padding_references'][i];
        final valid = cell.trace(q.padded, length: q.length).last.hidden,
            naive = cell.trace(q.padded).last.hidden;
        near(valid, ref['valid_hidden']);
        near(naive, ref['naive_hidden']);
        final all = cell.trace(q.padded);
        for (var t = 0; t < 14; t++) {
          near(all[t].hidden, ref['all_hidden'][t]);
        }
        if (q.length < 14) {
          expect(
            List.generate(3, (k) => (valid[k] - naive[k]).abs()).reduce(max),
            greaterThan(1e-5),
          );
        } else {
          near(valid, naive);
        }
      }
    },
  );
  test('Seven-step fixed-origin recursion matches PyTorch without using future truth', () {
    final cell = a.cells['gru_trained']!;
    for (var i = 0; i < 3; i++) {
      final q = a.queries[i], ref = raw['queries'][i];
      final values = cell.recursive(q.counts, a.mean, a.scale, 7);
      near(values, ref['recursive_gru'], tolerance: 1e-8);
      expect(
        values.first,
        closeTo(cell.predict(q.standardized) * a.scale + a.mean, 1e-9),
      );
      near(cell.recursive(q.counts, a.mean, a.scale, 1), [values.first]);
      near(q.counts.skip(7).toList(), ref['seasonal7_fixed_origin']);
      final changed = fresh();
      changed['queries'][i]['future_counts'] = List.filled(7, 999999.0);
      final b = SequenceAssets.fromJson(changed);
      near(cell.recursive(b.queries[i].counts, b.mean, b.scale, 7), values);
    }
  });
  test(
    'Source calendar and fit-only count transforms preserve declared roles',
    () {
      expect(a.queries.map((q) => q.targetIndex), [365, 400, 540]);
      expect(a.mean, closeTo(3405.7616438356163, 1e-10));
      expect(a.scale, closeTo(1376.8636667749531, 1e-10));
      expect((raw['train_history'] as List).length, 81);
      expect(
        raw['train_history'].last['train_mse_scaled'],
        lessThan(raw['train_history'].first['train_mse_scaled']),
      );
      expect(
        raw['rolling_metrics']['gru']['mae'],
        greaterThan(raw['rolling_metrics']['naive']['mae']),
      );
      for (final q in a.queries) {
        expect(
          DateTime.parse(q.dates.last),
          DateTime.parse(q.targetDate).subtract(const Duration(days: 1)),
        );
        expect(
          DateTime.parse(q.futureDates.last).isAfter(DateTime(2012, 6, 30)),
          isFalse,
        );
        near(q.standardized, [
          for (final n in q.counts) (n - a.mean) / a.scale,
        ]);
      }
    },
  );
  test(
    'States, gate vectors, source observations and forecasts are immutable',
    () {
      final cell = a.cells['lstm_initial']!,
          state = cell.trace(a.queries.first.standardized).last;
      expect(() => state.hidden[0] = 0, throwsUnsupportedError);
      expect(() => state.cell[0] = 0, throwsUnsupportedError);
      expect(() => state.gates['input']![0] = 0, throwsUnsupportedError);
      expect(() => state.gates.clear(), throwsUnsupportedError);
      expect(() => a.cells.clear(), throwsUnsupportedError);
      expect(() => a.queries.first.counts[0] = 0, throwsUnsupportedError);
      expect(() => cell.inputWeight.first[0] = 0, throwsUnsupportedError);
      expect(
        () => a.cells['gru_trained']!.recursive(
          a.queries.first.counts,
          a.mean,
          a.scale,
          7,
        )[0] = 0,
        throwsUnsupportedError,
      );
    },
  );
  test(
    'Invalid sequence lengths, nonfinite inputs and forecast contracts fail',
    () {
      final cell = a.cells['gru_trained']!;
      for (final x in <List<double>>[
        [],
        [double.nan],
        [double.infinity],
        List.filled(65, 0),
      ]) {
        expect(() => cell.trace(x), throwsArgumentError);
      }
      for (final n in [0, -1, 15]) {
        expect(
          () => cell.trace(List.filled(14, 0), length: n),
          throwsArgumentError,
        );
      }
      expect(() => cell.predict([0]), throwsArgumentError);
      expect(
        () => a.cells['rnn_initial']!.predict(List.filled(14, 0)),
        throwsArgumentError,
      );
      for (final h in [0, 8]) {
        expect(
          () => cell.recursive(a.queries.first.counts, a.mean, a.scale, h),
          throwsArgumentError,
        );
      }
      expect(
        () => cell.recursive(a.queries.first.counts, a.mean, 0, 1),
        throwsArgumentError,
      );
      expect(
        () => cell.recursive(a.queries.first.counts, double.nan, a.scale, 1),
        throwsArgumentError,
      );
    },
  );
  test('Corrupt schema, future dates, padding prefixes and recurrent layouts are rejected', () {
    final changes = <void Function(Map<String, dynamic>)>[
      (j) => j['scale'] = 0,
      (j) => j['lookback'] = 13,
      (j) => j['parameter_count'] = 59,
      (j) => j['cells'][2]['parameters']['head_weight'] = [1, 2],
      (j) => j['cells'][0]['kind'] = 'gru',
      (j) => j['cells'][0]['parameters']['w_hh'][0] = [0],
      (j) => j['queries'][2]['future_dates'][6] = '2012-07-01',
      (j) => j['queries'][0]['history_dates'][0] = '2012-01-01',
      (j) => j['queries'][0]['history_dates'][0] = '2011-12-18T00:00:00Z',
      (j) => j['queries'][0]['history_dates'][0] = '2011-11-48',
      (j) => j['queries'][0]['standardized'][0] = 50,
      (j) => j['padding_references'][0]['padded'][13] = 1,
      (j) => j['padding_references'][0]['padded'][0] = 42,
      (j) => j['padding_references'][0]['length'] = 14,
    ];
    for (final change in changes) {
      final j = fresh();
      change(j);
      expect(() => SequenceAssets.fromJson(j), throwsA(anything));
    }
  });
}
