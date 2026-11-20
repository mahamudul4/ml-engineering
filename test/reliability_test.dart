import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/features/reliability/reliability_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ReliabilityAssets a;
  late Map<String, dynamic> lab;
  setUpAll(() async {
    a = await ReliabilityAssets.load();
    lab = jsonDecode(
      await rootBundle.loadString(
        'assets/datasets/scifact_rag/reliability_lab.json',
      ),
    );
  });
  void close(dynamic actual, dynamic expected) {
    if (expected is num) {
      expect(actual, closeTo(expected, 1e-10));
    } else if (expected is Map) {
      expect((actual as Map).keys.toSet(), expected.keys.toSet());
      for (final key in expected.keys) {
        close(actual[key], expected[key]);
      }
    } else if (expected is List) {
      expect((actual as List).length, expected.length);
      for (var i = 0; i < expected.length; i++) {
        close(actual[i], expected[i]);
      }
    } else {
      expect(actual, expected);
    }
  }

  test(
    'All3full188-query audits,confidencebins,and18sweepreferencesmatchPython',
    () {
      for (final name in a.variants.keys) {
        close(
          reliabilityAudit(a.variants[name]!),
          lab['variants'][name]['audit'],
        );
      }
    },
  );
  test('All120replayedrequestclocks,percentilesandthroughputmatchPython', () {
    for (final size in [1, 4, 8]) {
      close(
        servingReplay(a.requests, batchSize: size),
        lab['replay_runs']['$size'],
      );
    }
  });
  test('Actualslicevaluesandmajoritycollapsearevisible', () {
    final rows = a.variants['lora']!,
        long = rows.where((r) => utf8.encode(r.text).length > 80).toList();
    expect(rows.length, 188);
    expect(long.length, 93);
    final r = reliabilityAudit(rows);
    expect([r['tp'], r['tn'], r['fp'], r['fn']], [124, 0, 64, 0]);
    expect(r['contradict_recall'], 0);
    expect(reliabilityAudit(a.variants['base']!)['precision'], isNull);
  });
  test('Selectiveinclusiveboundaryandemptyacceptedriskremaincorrect', () {
    final rows = [
      ReliabilityRow('1', 'Example', 1, .8, 2, 1),
      ReliabilityRow('2', 'Example', 0, .2, 2, 1),
    ];
    expect(selectiveAudit(rows, .8)['accepted'], 2);
    expect(selectiveAudit(rows, .9)['risk'], isNull);
    expect(selectiveAudit(rows, .9)['accuracy'], isNull);
    expect(selectiveAudit(rows, .9)['coverage'], 0);
    expect(reliabilityAudit(rows)['brier'], closeTo(.04, 1e-14));
    expect(selectiveAudit(a.variants['lora']!, 1)['accepted'], 0);
  });
  test('ECElastbinandzeroemptybinsdonotfabricatecalibration', () {
    final rows = [
      ReliabilityRow('a', 'Fixture', 1, 1, 2, 1),
      ReliabilityRow('b', 'Fixture', 0, 0, 2, 1),
    ];
    final r = reliabilityAudit(rows);
    expect(r['ece'], 0);
    expect(r['bins'][4]['count'], 2);
    expect(r['bins'][0]['accuracy'], isNull);
    expect(r['bins'][0]['gap'], isNull);
    expect(r['binary_nll_clipped'], greaterThan(0));
  });
  test(
    'Cachekeysisolatequeryandallfiveversion-scopefieldswithUnicodeescaping',
    () {
      final values = [
        'বাংলা "query"\n',
        'model',
        'corpus',
        'prompt',
        'scope',
        'greedy',
      ];
      final key = reliabilityCacheKey(
        values[0],
        values[1],
        values[2],
        values[3],
        values[4],
        values[5],
      );
      expect(jsonDecode(key), values);
      for (var i = 0; i < 6; i++) {
        final changed = List<String>.from(values);
        changed[i] += '-new';
        expect(
          reliabilityCacheKey(
            changed[0],
            changed[1],
            changed[2],
            changed[3],
            changed[4],
            changed[5],
          ),
          isNot(key),
        );
      }
      expect(
        () => reliabilityCacheKey('', 'm', 'c', 'p', 's', 'd'),
        throwsArgumentError,
      );
    },
  );
  test(
    'Invalidprobabilities,duplicateIDs,bins,thresholdsandreplaycostsreject',
    () {
      expect(() => reliabilityAudit([]), throwsArgumentError);
      final row = ReliabilityRow('1', 'Fixture', 1, .5, 2, 1);
      expect(() => reliabilityAudit([row, row]), throwsArgumentError);
      expect(
        () => reliabilityAudit([
          ReliabilityRow('1', 'Fixture', 1, double.nan, 2, 1),
        ]),
        throwsArgumentError,
      );
      expect(() => reliabilityAudit([row], bins: 0), throwsArgumentError);
      expect(() => selectiveAudit([row], .4), throwsArgumentError);
      expect(() => servingReplay([], batchSize: 1), throwsArgumentError);
      expect(
        () => servingReplay(a.requests, batchSize: 0),
        throwsArgumentError,
      );
      expect(
        () => servingReplay(a.requests, interval: double.nan),
        throwsArgumentError,
      );
      expect(
        () => servingReplay([const ServingRequest('x', 0, 1)]),
        throwsArgumentError,
      );
    },
  );
  test('Partialbatch,zerocostandimmutablemodelsareexplicit', () {
    final r = servingReplay(a.requests.take(5).toList(), batchSize: 4);
    expect(r['rows'].length, 5);
    expect(
      (r['rows'] as List).every((dynamic x) => (x['queue_ms'] as num) >= 0),
      isTrue,
    );
    final zero = servingReplay(
      [const ServingRequest('a', 1, 1)],
      interval: 0,
      prefill: 0,
      decode: 0,
      overhead: 0,
    );
    expect(zero['throughput_per_second'], isNull);
    expect(zero['p95_ms'], 0);
    expect(() => a.variants.clear(), throwsUnsupportedError);
    expect(() => a.variants['lora']!.clear(), throwsUnsupportedError);
    expect(() => a.requests.clear(), throwsUnsupportedError);
  });
}
