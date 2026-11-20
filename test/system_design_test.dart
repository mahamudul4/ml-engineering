import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/features/system_design/design_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DesignAssets a;
  setUpAll(() async {
    a = await DesignAssets.load();
  });
  void same(dynamic x, dynamic y) {
    if (y is Map) {
      expect((x as Map).keys.toSet(), y.keys.toSet());
      for (final k in y.keys) {
        same(x[k], y[k]);
      }
    } else if (y is List) {
      expect((x as List).length, y.length);
      for (var j = 0; j < y.length; j++) {
        same(x[j], y[j]);
      }
    } else if (y is num) {
      expect(x, closeTo(y, math.max(1e-9, y.abs() * 1e-11)));
    } else {
      expect(x, y);
    }
  }

  Map<String, dynamic> clone(dynamic x) =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(x)));
  test('Original source and all4601 row roles preserve disjoint exact-profile groups and reserved scope', () {
    final r = a.data['report'];
    expect(r['source_rows'], 4601);
    expect(r['unique_profiles'], 4207);
    expect(r['roles'], {'train': 3183, 'validation': 738, 'reserved': 680});
    expect(r['reserved_outcomes_scored'], 0);
    expect(
      r['source_sha256']['spambase.data'],
      'b1ef93de71f97714d3d7d4f58fc9f718da7bbc8ac8a150eff2778616a8097b12',
    );
    final roles = a.data['spam']['roles'],
        groups = a.data['spam']['groups'] as List,
        all = <int>{},
        sets = <Set<int>>[];
    for (final role in ['train', 'validation', 'reserved']) {
      final ids = (roles[role] as List).cast<int>();
      expect(ids.every((i) => i >= 0 && i < 4601), isTrue);
      expect(ids.toSet().length, ids.length);
      expect(all.intersection(ids.toSet()), isEmpty);
      all.addAll(ids);
      sets.add({for (final i in ids) groups[i] as int});
    }
    expect(all.length, 4601);
    for (var i = 0; i < 3; i++) {
      for (var j = i + 1; j < 3; j++) {
        expect(sets[i].intersection(sets[j]), isEmpty);
      }
    }
  });
  test('All738 actual57-feature probabilities match independent sklearn source references', () {
    final model = clone(a.data['spam']['model']);
    expect(model['fit_rows'], 3183);
    expect(model['fields'].length, 57);
    expect((model['fields'] as List).toSet().length, 57);
    expect(model['fields'].first, 'word_freq_make');
    expect(model['fields'].last, 'capital_run_length_total');
    for (final row in a.data['spam']['validation']) {
      expect(row['features'].length, 57);
      expect(
        designSpamPredict(model, row['features']),
        closeTo(row['score'], 1e-10),
      );
    }
  });
  test('Shape,scale,finite values and negative inputs guard linear inference safely', () {
    final model = clone(a.data['spam']['model']),
        features = List<dynamic>.from(
          a.data['spam']['validation'][0]['features'],
        );
    expect(designValidSpam(model), isTrue);
    for (final change in [
      {'scale': List<double>.filled(57, 0)},
      {
        'weights': [1, 2],
      },
      {'intercept': double.nan},
      {'version': 'wrong'},
      {'mean': List<double>.filled(57, double.infinity)},
    ]) {
      expect(designSpamPredict({...model, ...change}, features), isNull);
    }
    expect(designSpamPredict(model, [1, 2]), isNull);
    features[0] = -1;
    expect(designSpamPredict(model, features), isNull);
    features[0] = double.nan;
    expect(designSpamPredict(model, features), isNull);
    expect(
      designSpamPredict({
        ...model,
        'intercept': -1e6,
      }, List<double>.filled(57, 0)),
      0,
    );
  });
  test('Every1215 architecture,cache,load,replica,scale and budget reference matches', () {
    expect((a.data['capacity'] as Map).length, 1215);
    for (final entry in (a.data['capacity'] as Map).entries) {
      final p = (entry.key as String).split(':'), ref = entry.value;
      same(
        a.capacity(
          p[0],
          qps: ref['qps'],
          hit: (ref['hit'] as num).toDouble(),
          replicas: ref['replicas'],
          scale: (ref['scale'] as num).toDouble(),
          deadline: ref['deadline'],
        ),
        ref,
      );
    }
  });
  test('Parallel maximum,serial sum,zero misses and unstable exact boundary have distinct meanings', () {
    final p = a.capacity('recommendation');
    expect(p['critical_ms'], 20);
    expect(p['serial_work_ms'], 31);
    expect(p['parallel_saved_ms'], 11);
    expect(p['ideal_capacity'], 800);
    expect(p['backend_qps'], 500);
    expect(p['utilization'], .625);
    expect(p['in_service'], 10);
    final overloaded = a.capacity(
      'recommendation',
      qps: 200,
      hit: 0,
      replicas: 1,
    );
    expect(overloaded['utilization'], 1);
    expect(overloaded['stable'], isFalse);
    expect(overloaded['in_service'], isNull);
    expect(a.capacity('rag', hit: 1)['backend_qps'], 0);
    expect(a.capacity('rag', qps: 0)['in_service'], 0);
    expect(() => a.capacity('spam', hit: double.nan), throwsArgumentError);
    expect(() => a.capacity('spam', replicas: 0), throwsArgumentError);
  });
  test('All72 selective decision policies match source routes,admissions and retrospective metrics', () {
    expect((a.data['policies'] as Map).length, 72);
    for (final r in (a.data['policies'] as Map).values) {
      same(
        a.review(
          low: r['low'],
          high: r['high'],
          budget: r['budget'],
          overflow: r['overflow'],
          fpCost: r['fp_cost'],
        ),
        r,
      );
    }
    final r = a.review();
    expect(r['n'], 738);
    expect(r['decided'], 606);
    expect(r['pending'], 132);
    expect(r['review'], 50);
    expect(r['defer'], 82);
    expect(r['false_blocks'], 10);
    expect(r['missed_spam'], 8);
    expect(r['automatic_cost'], 1008);
  });
  test('Contract failure blocks before prediction and no automatic decisions means undefined conditional accuracy', () {
    final r = _NoScores(a.data).review(fault: true);
    expect(r['contract_blocked'], 738);
    expect(r['pending'], 738);
    expect(r['coverage'], 0);
    expect(r['conditional_accuracy'], isNull);
    expect(r['automatic_cost'], 0);
    final data = clone(a.data);
    data['spam']['model']['scale'] = List<double>.filled(57, 0);
    expect(_NoScores(data).review()['contract_blocked'], 738);
  });
  test('Routing is invariant to true labels and cost;boundary ties use stable source ordinals', () {
    final rows = [
          for (final r in a.scoredRows)
            {...Map<String, dynamic>.from(r), 'label': 1 - (r['label'] as int)},
        ],
        base = a.review(),
        changed = designReviewPolicy(rows);
    expect(changed['routes'], base['routes']);
    expect(changed['review_ids'], base['review_ids']);
    expect(a.review(fpCost: 10)['routes'], base['routes']);
    final small = [
      {'index': 9, 'score': .2, 'label': 1},
      {'index': 8, 'score': .8, 'label': 0},
      {'index': 3, 'score': .5, 'label': 1},
      {'index': 2, 'score': .5, 'label': 0},
    ];
    final p = designReviewPolicy(small, budget: 1);
    expect(p['routes'], ['defer', 'block', 'defer', 'review']);
    expect(p['review_ids'], [2]);
    expect(p['false_blocks'], 1);
  });
  test('All fifteen source-backed request/fault responses match independent Python pipelines', () {
    for (final system in designCases) {
      for (final fault in designFaults) {
        same(
          a.response(system, fault: fault),
          a.data['responses'][system][fault],
        );
      }
    }
    expect(
      a.response('forecast', fault: 'upstream')['output']['prediction'],
      2368,
    );
    expect(a.response('rag')['reason'], 'unverified_hypothesis');
    expect(a.response('rag', fault: 'upstream')['output'], isNull);
  });
  test('Five dependency fields reject wrong/missing values and guard even absent component instances', () {
    for (final system in designCases) {
      final expected = clone(a.data['manifests'][system]);
      for (final key in expected.keys) {
        expect(designContractErrors(expected, {...expected, key: 'wrong'}), [
          key,
        ]);
        final missing = {...expected}..remove(key);
        expect(designContractErrors(expected, missing), [key]);
      }
      expect(
        DesignAssets(a.data)
            .response(system, fault: 'model_mismatch')['status'],
        'BLOCKED',
      );
    }
    expect(
      DesignAssets(a.data).response('rag', fault: 'upstream')['status'],
      'ABSTAIN',
    );
    expect(
      DesignAssets(a.data).response('spam', fault: 'upstream')['output'],
      isNull,
    );
  });
  test('Frozen response policy scope and all normal response outputs exclude target labels', () {
    expect(a.data['response_policies']['spam']['binary_threshold'], .5);
    expect(a.data['response_policies']['recommendation'], {
      'policy': 'rrf_cf',
      'budget': 50,
      'k': 10,
      'fallback': 'fit_popularity',
    });
    for (final system in designCases) {
      expect(
        a.data['manifests'][system]['policy_identity'],
        matches(RegExp(r'^[0-9a-f]{64}$')),
      );
      final r = a.response(system);
      expect(r.containsKey('gold'), isFalse);
      expect(r.containsKey('outcome'), isFalse);
      if (r['output'] != null) {
        expect((r['output'] as Map).containsKey('label'), isFalse);
      }
    }
    expect(a.response('recommendation')['output']['items'].length, 10);
    expect(a.response('search')['output']['documents'].length, 5);
  });
  test('Empty policy cohorts and invalid numerical/policy inputs never fabricate certainty', () {
    final empty = designReviewPolicy([]);
    expect(empty['n'], 0);
    expect(empty['coverage'], isNull);
    expect(empty['conditional_accuracy'], isNull);
    expect(() => designReviewPolicy([], low: double.nan), throwsArgumentError);
    expect(
      () => designReviewPolicy([], low: .8, high: .2),
      throwsArgumentError,
    );
    expect(() => designReviewPolicy([], budget: -1), throwsArgumentError);
    expect(
      () => designReviewPolicy([], overflow: 'oracle'),
      throwsArgumentError,
    );
    expect(
      () => designReviewPolicy([
        {'index': 1, 'score': double.nan, 'label': 0},
      ]),
      throwsArgumentError,
    );
    expect(() => a.response('unknown'), throwsArgumentError);
    expect(() => a.response('spam', fault: 'real_outage'), throwsArgumentError);
  });
}

class _NoScores extends DesignAssets {
  _NoScores(super.data);
  @override
  List<dynamic> get scoredRows =>
      throw StateError('Inference must not run after a failed contract');
}
