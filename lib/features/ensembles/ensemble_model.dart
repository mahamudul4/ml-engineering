import 'dart:convert';

import 'package:flutter/services.dart';

class MemberAverage {
  final int eligible, hardPositive;
  final double? probability;
  MemberAverage._(this.eligible, this.hardPositive, this.probability);
  factory MemberAverage.compute(
    List<double> probabilities,
    List<bool> inBag, {
    required int count,
    bool oobOnly = false,
  }) {
    if (probabilities.isEmpty ||
        probabilities.length != inBag.length ||
        count < 1 ||
        count > probabilities.length ||
        probabilities.any((p) => !p.isFinite || p < 0 || p > 1)) {
      throw ArgumentError(
        'Aligned finite member probabilities and bounded prefix required.',
      );
    }
    var n = 0, hard = 0;
    var total = 0.0;
    for (var i = 0; i < count; i++) {
      if (oobOnly && inBag[i]) continue;
      n++;
      total += probabilities[i];
      if (probabilities[i] > .5) hard++;
    }
    return MemberAverage._(n, hard, n == 0 ? null : total / n);
  }
}

class BaggingPoint {
  final int sourceRow, positive;
  final List<double> probabilities;
  final List<bool> inBag;
  BaggingPoint.fromJson(Map<String, dynamic> j)
    : sourceRow = j['source_row_1based'],
      positive = j['positive'],
      probabilities = List.unmodifiable(
        (j['probabilities'] as List).map((p) => (p as num).toDouble()),
      ),
      inBag = List<bool>.unmodifiable(j['in_bag']) {
    if (sourceRow < 1 || ![0, 1].contains(positive)) {
      throw FormatException('Invalid real observation.');
    }
    MemberAverage.compute(probabilities, inBag, count: probabilities.length);
  }
}

class BoostRun {
  final double rate;
  final List<double> trainRmse, validRmse;
  final List<List<double>> predictions, outputs;
  BoostRun.fromJson(Map<String, dynamic> j)
    : rate = (j['rate'] as num).toDouble(),
      trainRmse = List.unmodifiable(
        (j['train_rmse'] as List).map((x) => (x as num).toDouble()),
      ),
      validRmse = List.unmodifiable(
        (j['valid_rmse'] as List).map((x) => (x as num).toDouble()),
      ),
      predictions = _matrix(j['probe_predictions']),
      outputs = _matrix(j['probe_tree_outputs']) {
    if (!rate.isFinite ||
        rate <= 0 ||
        rate > 1 ||
        trainRmse.length < 2 ||
        trainRmse.length != validRmse.length ||
        predictions.isEmpty ||
        predictions.length != outputs.length ||
        [...trainRmse, ...validRmse].any((x) => !x.isFinite || x < 0)) {
      throw FormatException('Invalid boosting curve.');
    }
    for (var i = 0; i < predictions.length; i++) {
      if (predictions[i].length != trainRmse.length ||
          outputs[i].length != trainRmse.length - 1 ||
          [...predictions[i], ...outputs[i]].any((x) => !x.isFinite)) {
        throw FormatException('Invalid boosting dimensions.');
      }
      for (var t = 0; t < outputs[i].length; t++) {
        if ((predictions[i][t] + rate * outputs[i][t] - predictions[i][t + 1])
                .abs() >
            1e-8) {
          throw FormatException('Inconsistent additive update.');
        }
      }
    }
  }
  static List<List<double>> _matrix(List<dynamic> j) => List.unmodifiable([
    for (final row in j)
      List<double>.unmodifiable(
        (row as List).map((x) => (x as num).toDouble()),
      ),
  ]);
}

class EnsembleAssets {
  static EnsembleAssets? _loaded;
  final List<BaggingPoint> points;
  final List<BoostRun> runs;
  final List<int> probeRows;
  final List<double> targets;
  final int members, rounds, trainRows, validRows;
  final double base;
  EnsembleAssets._(
    this.points,
    this.runs,
    this.probeRows,
    this.targets,
    this.members,
    this.rounds,
    this.trainRows,
    this.validRows,
    this.base,
  );
  static Future<EnsembleAssets> load() async {
    if (_loaded != null) return _loaded!;
    final raw = await Future.wait([
      rootBundle.loadString('assets/datasets/adult/ensemble_bagging_lab.json'),
      rootBundle.loadString('assets/datasets/adult/ensemble_boosting_lab.json'),
    ]);
    final assets = EnsembleAssets.fromJson(
      jsonDecode(raw[0]),
      jsonDecode(raw[1]),
    );
    _loaded = assets;
    return assets;
  }

  factory EnsembleAssets.fromJson(
    Map<String, dynamic> bag,
    Map<String, dynamic> boost,
  ) {
    const hash =
        '5b00264637dbfec36bdeaab5676b0b309ff9eb788d63554ca0a249491c86603d';
    if (bag['sha256'] != hash || boost['sha256'] != hash) {
      throw FormatException('Expected bundled Adult provenance.');
    }
    final points = List<BaggingPoint>.unmodifiable([
      for (final j in bag['points']) BaggingPoint.fromJson(j),
    ]);
    final runs = List<BoostRun>.unmodifiable([
      for (final j in boost['runs']) BoostRun.fromJson(j),
    ]);
    final rows = List<int>.unmodifiable([
      for (final j in boost['probes']) j['source_row_1based'] as int,
    ]);
    final targets = List<double>.unmodifiable([
      for (final j in boost['probes']) (j['target'] as num).toDouble(),
    ]);
    final int members = bag['members'],
        rounds = boost['rounds'],
        train = boost['train_rows'],
        valid = boost['valid_rows'];
    final base = (boost['base'] as num).toDouble();
    if (points.isEmpty ||
        members < 1 ||
        rounds < 1 ||
        rows.isEmpty ||
        train < 1 ||
        valid < 1 ||
        !base.isFinite ||
        targets.any((t) => !t.isFinite) ||
        rows.any((i) => i < 1) ||
        points.map((p) => p.sourceRow).toSet().length != points.length ||
        runs.isEmpty ||
        runs.map((r) => r.rate).toSet().length != runs.length ||
        points.any((p) => p.probabilities.length != members) ||
        runs.any(
          (r) =>
              r.trainRmse.length != rounds + 1 ||
              r.predictions.length != rows.length ||
              r.predictions.any((p) => (p.first - base).abs() > 1e-8),
        )) {
      throw FormatException('Inconsistent ensemble assets.');
    }
    return EnsembleAssets._(
      points,
      runs,
      rows,
      targets,
      members,
      rounds,
      train,
      valid,
      base,
    );
  }
}
