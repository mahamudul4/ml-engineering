import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/features/ensembles/ensemble_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Soft averaging differs from hard majority and respects prefix count',
    () {
      final r = MemberAverage.compute(
        [.49, .49, .99],
        [false, false, false],
        count: 3,
      );
      expect(r.probability, closeTo(1.97 / 3, 1e-14));
      expect(r.eligible, 3);
      expect(r.hardPositive, 1);
      expect(
        MemberAverage.compute(
          [.49, .49, .99],
          [false, false, false],
          count: 2,
        ).probability,
        .49,
      );
    },
  );
  test(
    'OOB denominator uses eligible members and no support stays undefined',
    () {
      final r = MemberAverage.compute(
        [.2, .9, .4],
        [true, false, false],
        count: 3,
        oobOnly: true,
      );
      expect(r.probability, closeTo(.65, 1e-14));
      expect(r.eligible, 2);
      final empty = MemberAverage.compute(
        [.2, .9],
        [true, false],
        count: 1,
        oobOnly: true,
      );
      expect(empty.probability, isNull);
      expect(empty.eligible, 0);
      expect(MemberAverage.compute([.2], [true], count: 1).probability, .2);
    },
  );
  test('Invalid member shapes, nonfinite probabilities and counts fail', () {
    expect(() => MemberAverage.compute([], [], count: 1), throwsArgumentError);
    expect(
      () => MemberAverage.compute([.2], [], count: 1),
      throwsArgumentError,
    );
    for (final p in [double.nan, double.infinity, -.1, 1.1]) {
      expect(
        () => MemberAverage.compute([p], [false], count: 1),
        throwsArgumentError,
      );
    }
    expect(
      () => MemberAverage.compute([.2], [false], count: 0),
      throwsArgumentError,
    );
    expect(
      () => MemberAverage.compute([.2], [false], count: 2),
      throwsArgumentError,
    );
  });
  test('Real bagging asset exposes empty first-member OOB and immutable member data', () async {
    final asset = await EnsembleAssets.load(), point = asset.points.first;
    expect(asset.members, 24);
    expect(asset.points.length, 12);
    expect(point.inBag.first, isTrue);
    expect(
      MemberAverage.compute(
        point.probabilities,
        point.inBag,
        count: 1,
        oobOnly: true,
      ).probability,
      isNull,
    );
    for (final row in asset.points) {
      final vote = MemberAverage.compute(
        row.probabilities,
        row.inBag,
        count: 24,
        oobOnly: true,
      );
      expect(vote.eligible, greaterThan(0));
      expect(vote.probability, inInclusiveRange(0, 1));
    }
    expect(() => point.inBag.clear(), throwsUnsupportedError);
    expect(() => point.probabilities[0] = 0, throwsUnsupportedError);
    expect(() => asset.points.clear(), throwsUnsupportedError);
  });
  test('Boosting asset reconstructs every stage from rate-scaled actual tree outputs', () async {
    final asset = await EnsembleAssets.load();
    expect(asset.rounds, 16);
    expect(asset.trainRows, 26050);
    expect(asset.validRows, 6511);
    expect(asset.probeRows.length, 8);
    for (final run in asset.runs) {
      for (var point = 0; point < 8; point++) {
        var current = asset.base;
        expect(run.predictions[point][0], closeTo(current, 1e-12));
        for (var t = 0; t < 16; t++) {
          current += run.rate * run.outputs[point][t];
          expect(current, closeTo(run.predictions[point][t + 1], 1e-10));
        }
      }
      for (var t = 1; t < 17; t++) {
        expect(
          run.trainRmse[t],
          lessThanOrEqualTo(run.trainRmse[t - 1] + 1e-10),
        );
      }
    }
    expect(asset.runs[0].validRmse.last, closeTo(11.368836680466202, 1e-10));
    expect(asset.runs[2].validRmse.last, closeTo(11.220875494404499, 1e-10));
    expect(
      () => asset.runs.first.predictions.first.clear(),
      throwsUnsupportedError,
    );
    expect(() => asset.targets.clear(), throwsUnsupportedError);
  });
  test('Changing rate uses a separately fitted path rather than scaling saved corrections', () async {
    final a = await EnsembleAssets.load();
    // First tree sees the same initial residual; later trees see rate-specific residuals.
    expect(a.runs[0].outputs[0][0], closeTo(a.runs[2].outputs[0][0], 1e-12));
    expect(
      (a.runs[0].outputs[0][1] - a.runs[2].outputs[0][1]).abs(),
      greaterThan(1e-5),
    );
    expect(a.runs[0].trainRmse.first, a.runs[2].trainRmse.first);
  });
  test(
    'Corrupt provenance, shapes and additive updates are rejected',
    () async {
      final bag = jsonDecode(
        await rootBundle.loadString(
          'assets/datasets/adult/ensemble_bagging_lab.json',
        ),
      ) as Map<String, dynamic>;
      final boost = jsonDecode(
        await rootBundle.loadString(
          'assets/datasets/adult/ensemble_boosting_lab.json',
        ),
      ) as Map<String, dynamic>;
      expect(
        () => EnsembleAssets.fromJson({...bag, 'sha256': 'wrong'}, boost),
        throwsFormatException,
      );
      final bad = jsonDecode(jsonEncode(boost)) as Map<String, dynamic>;
      bad['runs'][0]['probe_predictions'][0][1] += 1;
      expect(() => EnsembleAssets.fromJson(bag, bad), throwsFormatException);
      final badShape = jsonDecode(jsonEncode(boost)) as Map<String, dynamic>;
      badShape['rounds'] = 15;
      expect(
        () => EnsembleAssets.fromJson(bag, badShape),
        throwsFormatException,
      );
    },
  );
}
