import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

void finiteSeries(List<double> x) {
  if (x.isEmpty || x.any((v) => !v.isFinite)) {
    throw ArgumentError('Nonempty finite series');
  }
}

double robustAnomalyScore(double value, double median, double mad) {
  if (!value.isFinite || !median.isFinite || !mad.isFinite || mad <= 0) {
    throw ArgumentError('Finite center and positive MAD');
  }
  final s = .6744897501960817 * (value - median).abs() / mad;
  if (!s.isFinite) throw ArgumentError('Score overflow');
  return s;
}

List<double> baselineForecast(
  List<double> history, {
  required int horizon,
  required String method,
  int period = 7,
  int gap = 0,
}) {
  finiteSeries(history);
  if (horizon < 1 || period < 1 || gap < 0) {
    throw ArgumentError('Positive horizon/period and nonnegative gap');
  }
  if (!['naive', 'seasonal', 'drift'].contains(method)) {
    throw ArgumentError('Unknown method');
  }
  if (method == 'seasonal' && history.length < period ||
      method == 'drift' && history.length < 2) {
    throw ArgumentError('Insufficient history');
  }
  final values = [
    for (var i = 0; i < horizon; i++)
      switch (method) {
        'naive' => history.last,
        'seasonal' => history[history.length - period + (gap + i) % period],
        _ =>
          history.last +
              (gap + i + 1) *
                  (history.last - history.first) /
                  (history.length - 1),
      },
  ];
  finiteSeries(values);
  return List.unmodifiable(values);
}

class ForecastMetrics {
  final double mae, rmse;
  final double? mase7;
  ForecastMetrics._(this.mae, this.rmse, this.mase7);
  factory ForecastMetrics.compute(
    List<double> actual,
    List<double> prediction,
    List<double> training,
  ) {
    finiteSeries(actual);
    finiteSeries(prediction);
    finiteSeries(training);
    if (actual.length != prediction.length || training.length < 8) {
      throw ArgumentError('Aligned forecasts and >=8 training rows');
    }
    var absError = 0.0, squared = 0.0, denominator = 0.0;
    for (var i = 0; i < actual.length; i++) {
      final e = actual[i] - prediction[i];
      absError += e.abs();
      squared += e * e;
    }
    for (var i = 7; i < training.length; i++) {
      denominator += (training[i] - training[i - 7]).abs();
    }
    final mae = absError / actual.length,
        rmse = sqrt(squared / actual.length),
        den = denominator / (training.length - 7);
    if (!mae.isFinite || !rmse.isFinite || !den.isFinite) {
      throw ArgumentError('Metric overflow');
    }
    return ForecastMetrics._(mae, rmse, den == 0 ? null : mae / den);
  }
}

class TemporalFold {
  final int trainStart, origin, gap, horizon;
  const TemporalFold._(this.trainStart, this.origin, this.gap, this.horizon);
  factory TemporalFold.create({
    required int n,
    required int origin,
    required int horizon,
    int gap = 0,
    int? window,
  }) {
    if (origin < 8 ||
        horizon < 1 ||
        gap < 0 ||
        origin + gap + horizon > n ||
        window != null && window < 8) {
      throw ArgumentError('Bounded chronological fold');
    }
    return TemporalFold._(
      window == null ? 0 : max(0, origin - window),
      origin,
      gap,
      horizon,
    );
  }
  int get validStart => origin + gap;
  int get validEnd => validStart + horizon;
  int get trainCount => origin - trainStart;
}

class AnomalyObservation {
  final int sourceRow;
  final String date;
  final double actual, lag7, residual, score;
  AnomalyObservation.fromJson(Map<String, dynamic> j)
    : sourceRow = j['source_row_1based'],
      date = j['date'],
      actual = (j['actual'] as num).toDouble(),
      lag7 = (j['lag7'] as num).toDouble(),
      residual = (j['residual'] as num).toDouble(),
      score = (j['robust_score'] as num).toDouble() {
    finiteSeries([actual, lag7, residual, score]);
    if (sourceRow < 8 || score < 0 || (actual - lag7 - residual).abs() > 1e-8) {
      throw const FormatException('Invalid weekly difference');
    }
  }
}

class TemporalAssets {
  final List<String> dates;
  final List<double> counts;
  final List<AnomalyObservation> queries;
  final int trainEnd;
  final double median, mad;
  TemporalAssets.fromJson(Map<String, dynamic> j)
    : dates = List.unmodifiable(List<String>.from(j['dates'])),
      counts = List.unmodifiable(
        (j['counts'] as List).map((v) => (v as num).toDouble()),
      ),
      queries = List.unmodifiable(
        (j['anomaly_queries'] as List).map(
          (v) => AnomalyObservation.fromJson(v),
        ),
      ),
      trainEnd = j['train_end'],
      median = (j['anomaly_fit']['median'] as num).toDouble(),
      mad = (j['anomaly_fit']['mad'] as num).toDouble() {
    finiteSeries(counts);
    if (dates.length != counts.length ||
        trainEnd < 8 ||
        trainEnd >= counts.length ||
        queries.isEmpty ||
        queries.map((q) => q.sourceRow).toSet().length != queries.length) {
      throw const FormatException('Invalid temporal pool');
    }
    for (var i = 0; i < dates.length; i++) {
      final d = DateTime.parse('${dates[i]}T00:00:00Z');
      if (counts[i] < 0 ||
          (i > 0 &&
              d
                      .difference(DateTime.parse('${dates[i - 1]}T00:00:00Z'))
                      .inDays !=
                  1)) {
        throw const FormatException('Complete daily calendar required');
      }
    }
    for (final q in queries) {
      final i = q.sourceRow - 1;
      if (i < trainEnd ||
          i >= counts.length ||
          q.date != dates[i] ||
          q.actual != counts[i] ||
          q.lag7 != counts[i - 7] ||
          (robustAnomalyScore(q.residual, median, mad) - q.score).abs() >
              1e-10) {
        throw const FormatException('Unaligned query or anomaly score');
      }
    }
  }
  List<double> history(int origin, {int? window}) {
    final f = TemporalFold.create(
      n: counts.length,
      origin: origin,
      horizon: 1,
      window: window,
    );
    return List.unmodifiable(counts.sublist(f.trainStart, origin));
  }

  static TemporalAssets? _cached;
  static Future<TemporalAssets> load() async {
    if (_cached != null) return _cached!;
    final j = jsonDecode(
      await rootBundle.loadString(
        'assets/datasets/bike_sharing/temporal_lab.json',
      ),
    ) as Map<String, dynamic>;
    final parsed = TemporalAssets.fromJson(j);
    _cached = parsed;
    return parsed;
  }
}
