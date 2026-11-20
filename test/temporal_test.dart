import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/features/temporal/temporal_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Robust anomaly score uses a frozen reference and rejects undefined scale',
    () {
      expect(robustAnomalyScore(6, 0, 2), closeTo(2.023469250588245, 1e-12));
      expect(robustAnomalyScore(-6, 0, 2), robustAnomalyScore(6, 0, 2));
      expect(robustAnomalyScore(26, 20, 2), robustAnomalyScore(6, 0, 2));
      expect(() => robustAnomalyScore(1, 0, 0), throwsArgumentError);
      expect(() => robustAnomalyScore(double.nan, 0, 1), throwsArgumentError);
    },
  );
  test('Fixed origin baselines wrap season, advance across a gap and preserve inputs', () {
    final history = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0];
    expect(baselineForecast(history, horizon: 10, method: 'seasonal'), [
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      1,
      2,
      3,
    ]);
    expect(baselineForecast(history, horizon: 3, method: 'seasonal', gap: 9), [
      3,
      4,
      5,
    ]);
    expect(baselineForecast(history, horizon: 3, method: 'naive', gap: 9), [
      7,
      7,
      7,
    ]);
    expect(baselineForecast([2, 4, 6], horizon: 3, method: 'drift', gap: 1), [
      10,
      12,
      14,
    ]);
    expect(history, [1, 2, 3, 4, 5, 6, 7]);
    expect(
      () => baselineForecast([1], horizon: 1, method: 'drift'),
      throwsArgumentError,
    );
    expect(
      () => baselineForecast(history, horizon: 0, method: 'naive'),
      throwsArgumentError,
    );
    expect(
      () => baselineForecast(history, horizon: 1, method: 'missing'),
      throwsArgumentError,
    );
  });
  test('Forecast metrics use training seasonal scale and return undefined zero MASE', () {
    final m = ForecastMetrics.compute([1, 3], [2, 1], [1, 2, 3, 4, 5, 6, 7, 8]);
    expect(m.mae, 1.5);
    expect(m.rmse, closeTo(sqrt(2.5), 1e-12));
    expect(m.mase7, closeTo(1.5 / 7, 1e-12));
    expect(m.rmse, greaterThanOrEqualTo(m.mae));
    final constant = ForecastMetrics.compute(
      [2, 3],
      [1, 1],
      List.filled(10, 1),
    );
    expect(constant.mase7, isNull);
    expect(
      () => ForecastMetrics.compute([1], [1, 2], List.filled(10, 1)),
      throwsArgumentError,
    );
    expect(
      () => ForecastMetrics.compute([], [], List.filled(10, 1)),
      throwsArgumentError,
    );
  });
  test(
    'Temporal folds enforce disjoint ordered boundaries and rolling history',
    () {
      final f = TemporalFold.create(
        n: 200,
        origin: 100,
        horizon: 14,
        gap: 7,
        window: 60,
      );
      expect(f.trainStart, 40);
      expect(f.trainCount, 60);
      expect(f.validStart, 107);
      expect(f.validEnd, 121);
      final edge = TemporalFold.create(
        n: 121,
        origin: 100,
        horizon: 14,
        gap: 7,
      );
      expect(edge.validEnd, 121);
      expect(
        () => TemporalFold.create(n: 120, origin: 100, horizon: 14, gap: 7),
        throwsArgumentError,
      );
      expect(
        () => TemporalFold.create(n: 200, origin: 100, horizon: 1, window: 7),
        throwsArgumentError,
      );
    },
  );
  test('Runtime forecasts match independent Python reference assets', () async {
    final a = await TemporalAssets.load(),
        j = jsonDecode(
          await rootBundle.loadString(
            'assets/datasets/bike_sharing/temporal_lab.json',
          ),
        );
    for (final ref in j['forecast_references']) {
      final pred = baselineForecast(
        a.history(ref['origin']),
        horizon: ref['horizon'],
        method: ref['method'],
        gap: ref['gap'],
      );
      for (var i = 0; i < pred.length; i++) {
        expect(
          pred[i],
          closeTo((ref['prediction'][i] as num).toDouble(), 1e-9),
        );
      }
    }
    expect(a.counts.length, 547);
    expect(a.dates.last, '2012-06-30');
    expect(a.queries.length, 42);
    expect(a.median, 54.5);
    expect(a.mad, 489.5);
    for (final q in a.queries) {
      expect(
        robustAnomalyScore(q.residual, a.median, a.mad),
        closeTo(q.score, 1e-12),
      );
    }
    expect(() => a.counts[0] = 0, throwsUnsupportedError);
    expect(() => a.queries.clear(), throwsUnsupportedError);
  });
  test('Future suffix changes do not change frozen-origin forecasts', () async {
    final a = await TemporalAssets.load(), copy = a.counts.toList();
    final expected = baselineForecast(
      copy.sublist(0, 365),
      horizon: 28,
      method: 'seasonal',
    );
    copy.fillRange(365, copy.length, 999999);
    expect(
      baselineForecast(copy.sublist(0, 365), horizon: 28, method: 'seasonal'),
      expected,
    );
    final shifted = TemporalFold.create(
      n: 547,
      origin: 365,
      horizon: 14,
      gap: 7,
    );
    expect(a.dates[shifted.validStart], '2012-01-08');
    expect(a.history(365, window: 90).length, 90);
  });
  test('Lower alert thresholds contain every higher-threshold flag', () async {
    final a = await TemporalAssets.load(),
        scores = a.queries.map((q) => q.score).toList();
    final low = {
          for (var i = 0; i < scores.length; i++)
            if (scores[i] > .5) i,
        },
        high = {
          for (var i = 0; i < scores.length; i++)
            if (scores[i] > 3.5) i,
        };
    expect(low.containsAll(high), isTrue);
    expect(low.length, greaterThan(high.length));
  });
  test('Asset parsing rejects calendar gaps, misaligned observations and corrupt scores', () async {
    final source = await rootBundle.loadString(
      'assets/datasets/bike_sharing/temporal_lab.json',
    );
    final gap = jsonDecode(source);
    gap['dates'][50] = gap['dates'][49];
    expect(() => TemporalAssets.fromJson(gap), throwsFormatException);
    final score = jsonDecode(source);
    score['anomaly_queries'][0]['robust_score'] = 999;
    expect(() => TemporalAssets.fromJson(score), throwsFormatException);
    final raw = jsonDecode(source);
    raw['counts'][365] = 999;
    expect(() => TemporalAssets.fromJson(raw), throwsFormatException);
  });
}
