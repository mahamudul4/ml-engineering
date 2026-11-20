import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/features/feature_systems/feature_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FeatureSystemAssets a;
  setUpAll(() async {
    a = await FeatureSystemAssets.load();
  });
  void equal(Map<String, dynamic> actual, Map<String, dynamic> ref) {
    expect(actual.keys.toSet(), ref.keys.toSet());
    for (final key in featureFields) {
      if (ref[key] == null) {
        expect(actual[key], isNull, reason: key);
      } else {
        expect(actual[key], closeTo(ref[key], 1e-10), reason: key);
      }
    }
  }

  test('Original source prefix, source hashes and reserved holdout scope remain explicit', () {
    final r = a.data['report'];
    expect(r['used_rows'], 547);
    expect(r['reserved_outcomes_used'], 0);
    expect(r['first_date'], '2011-01-01');
    expect(r['last_date'], '2012-06-30');
    expect(
      r['source_hashes']['day.csv'],
      'a6bcf826782d3c0fbfdcbeead17cd0884185a0dafe8ff10cd48a874ee7ba18be',
    );
    for (final scenario in featureScenarios) {
      expect(a.events(scenario).length, 547);
      expect(a.events(scenario).last['event_day'], 546);
      expect(a.events(scenario).map((r) => r['event_key']).toSet().length, 547);
    }
  });
  test('Every1092 correct snapshot and retrospective vector matches independent Python/SQL reference', () {
    for (final scenario in featureScenarios) {
      for (final row in a.data['statistics'][scenario]['snapshots_data']) {
        final pit = pointInTimeFeatures(a.events(scenario), row['target']);
        equal(pit, Map<String, dynamic>.from(row['features']));
        final latest = pointInTimeFeatures(
          a.events(scenario),
          row['target'],
          latest: true,
        );
        equal(latest, Map<String, dynamic>.from(row['latest']));
        expect(featureDifference(pit, latest), row['different']);
      }
    }
  });
  test('Incremental availability-prefix state agrees for all1092 cutoffs', () {
    for (final scenario in featureScenarios) {
      final events = [...a.events(scenario)]
        ..sort((x, y) {
          final c = (x['available_day'] as int).compareTo(y['available_day']);
          return c != 0 ? c : (x['event_day'] as int).compareTo(y['event_day']);
        });
      var cursor = 0;
      final state = <dynamic>[];
      for (final row in a.data['statistics'][scenario]['snapshots_data']) {
        final target = row['target'] as int;
        while (cursor < events.length &&
            events[cursor]['available_day'] <= target) {
          state.add(events[cursor++]);
        }
        equal(
          pointInTimeFeatures(state, target),
          Map<String, dynamic>.from(row['features']),
        );
      }
    }
  });
  test('All eight real cases preserve original counts while schedule changes availability only', () {
    for (final c in a.data['cases']) {
      final events = a.events(c['scenario']);
      equal(
        pointInTimeFeatures(events, c['target']),
        Map<String, dynamic>.from(c['features']),
      );
      expect(
        events.firstWhere((r) => r['event_day'] == c['target'])['cnt'],
        c['outcome'],
      );
      expect(c['window'].length, 7);
    }
    for (var j = 0; j < 547; j++) {
      final x = a.events('on_time')[j], y = a.events('late_fixture')[j];
      for (final k in ['cnt', 'date', 'weekday', 'event_key', 'event_day']) {
        expect(x[k], y[k]);
      }
      expect(y['available_day'] - x['available_day'], j % 17 == 0 ? 3 : 0);
    }
  });
  test('Exact event and knowledge boundaries exclude target and include available-at-cutoff', () {
    final rows = a.events('late_fixture');
    final historical = pointInTimeFeatures(rows, 375),
        later = pointInTimeFeatures(rows, 375, asof: 378);
    expect(historical['lag1'], isNull);
    expect(historical['observed7'], 6);
    expect(historical['age_days'], 1);
    expect(later['observed7'], 7);
    expect(later['lag1'], rows[374]['cnt']);
    final modified = [
      for (final r in rows)
        {
          ...Map<String, dynamic>.from(r),
          if (r['event_day'] >= 375) 'cnt': 999999,
        },
    ];
    equal(pointInTimeFeatures(modified, 375), historical);
    expect(pointInTimeFeatures(rows, 375, asof: 377)['lag1'], isNull);
  });
  test('Null lags, empty means, known-row denominators and freshness have separate semantics', () {
    equal(pointInTimeFeatures(a.events('late_fixture'), 1), {
      'lag1': null,
      'lag7': null,
      'mean7': null,
      'observed7': 0,
      'age_days': null,
    });
    final rows = a.events('late_fixture'),
        t = 375,
        known = rows
            .where(
              (r) =>
                  r['event_day'] >= t - 7 &&
                  r['event_day'] < t &&
                  r['available_day'] <= t,
            )
            .toList();
    expect(
      pointInTimeFeatures(rows, t)['mean7'],
      known.fold<int>(0, (s, r) => s + (r['cnt'] as int)) / 6,
    );
    expect(pointInTimeFeatures(rows, 376)['age_days'], 0);
    expect(pointInTimeFeatures(rows, 376)['observed7'], 6);
  });
  test('Normal, duplicate and invalid-delivery replays reproduce actual SQLite ingestion counts', () {
    for (final config in [
      ('normal', false, false),
      ('duplicates', true, false),
      ('invalid', true, true),
    ]) {
      expect(
        featureReplay(
          a.events('late_fixture'),
          duplicates: config.$2,
          invalid: config.$3,
        ),
        a.data['replays'][config.$1],
      );
    }
  });
  test(
    'Logical batch size changes grouping while canonical stored state stays547',
    () {
      for (final n in [1, 32, 128]) {
        final r = featureReplay(
          a.events('late_fixture'),
          duplicates: true,
          invalid: true,
          chunk: n,
        );
        expect(r['stored'], 547);
        expect(r['inserted'], 547);
        expect(r['duplicates'], 547);
        expect(r['rejected'], 1);
        expect(r['batches'], (1095 / n).ceil());
      }
      expect(featureReplay([])['stored'], 0);
      expect(() => featureReplay([], chunk: 0), throwsArgumentError);
    },
  );
  test('Structural and semantic quality checks reject invalid payloads before deduplication', () {
    final r = Map<String, dynamic>.from(a.events('on_time').first);
    expect(validateFeatureEvent(r), isEmpty);
    expect(validateFeatureEvent({...r, 'cnt': -1}), ['negative_count']);
    expect(validateFeatureEvent({...r, 'cnt': true}), ['type:cnt']);
    expect(validateFeatureEvent({...r, 'date': null}), ['type:date']);
    expect(
      validateFeatureEvent({...r, 'available_day': 0}),
      contains('availability_before_day_close'),
    );
    expect(validateFeatureEvent({...r, 'weekday': 0}), contains('weekday'));
    expect(
      validateFeatureEvent({...r, 'event_key': 'wrong'}),
      contains('entity_key'),
    );
  });
  test(
    'Five contract dependencies block before computation even with empty input',
    () {
      final expected = a.manifest('late_fixture');
      expect(featureContractErrors(expected, {...expected}), isEmpty);
      equal(
        guardedPointInTimeFeatures(a.events('late_fixture'), 375, expected, {
          ...expected,
        })!,
        pointInTimeFeatures(a.events('late_fixture'), 375),
      );
      for (final key in expected.keys) {
        final bad = {...expected, key: 'wrong'};
        expect(featureContractErrors(expected, bad), [key]);
        expect(guardedPointInTimeFeatures([], 375, expected, bad), isNull);
        final missing = {...expected}..remove(key);
        expect(featureContractErrors(expected, missing), [key]);
      }
    },
  );
  test('Negative control exposes98 late-history mismatches and33 missing lag1 snapshots', () {
    for (final pair in [('on_time', 0, 0), ('late_fixture', 98, 33)]) {
      var mismatch = 0, missing = 0;
      for (var t = 1; t < 547; t++) {
        final p = pointInTimeFeatures(a.events(pair.$1), t);
        if (featureDifference(
          p,
          pointInTimeFeatures(a.events(pair.$1), t, latest: true),
        ).isNotEmpty) {
          mismatch++;
        }
        if (p['lag1'] == null) missing++;
      }
      expect(mismatch, pair.$2);
      expect(missing, pair.$3);
    }
  });
  test('Calendar arithmetic handles leap day and never assumes source ingestion timezone', () {
    expect(featureDate(0), '2011-01-01');
    expect(featureDate(365), '2012-01-01');
    expect(featureDate(424), '2012-02-29');
    expect(featureDate(546), '2012-06-30');
    for (final scenario in featureScenarios) {
      for (final row in a.events(scenario)) {
        expect(validateFeatureEvent(Map<String, dynamic>.from(row)), isEmpty);
      }
    }
  });
}
