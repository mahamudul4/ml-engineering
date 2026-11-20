import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/features/interview_practice/practice_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late PracticeAssets a;
  late PracticeSqlStore sql;
  late Directory dir;
  setUpAll(() async {
    a = await PracticeAssets.load();
    dir = await Directory.systemTemp.createTemp('ml_interview39_test_');
    sql = await PracticeSqlStore.open(
      a,
      factory: databaseFactoryFfi,
      path: '${dir.path}/practice.sqlite',
    );
  });
  tearDownAll(() async {
    await sql.close();
    await dir.delete(recursive: true);
  });
  void same(dynamic actual, dynamic expected) {
    if (expected is Map) {
      expect((actual as Map).keys.toSet(), expected.keys.toSet());
      for (final key in expected.keys) {
        same(actual[key], expected[key]);
      }
    } else if (expected is List) {
      expect((actual as List).length, expected.length);
      for (var j = 0; j < expected.length; j++) {
        same(actual[j], expected[j]);
      }
    } else if (expected is num) {
      expect(
        actual,
        closeTo(expected, math.max(1e-10, expected.abs() * 1e-11)),
      );
    } else {
      expect(actual, expected);
    }
  }

  test('Fit-only source snapshot,738 diagnostics and source contracts remain scoped', () {
    final r = a.data['report'];
    expect(r['fit_rows'], 80668);
    expect(r['fit_users'], 522);
    expect(r['fit_items'], 7867);
    expect(r['fit_cutoff'], 1458635162);
    expect(r['validation_rows'], 738);
    expect(r['reserved_outcomes_scored'], 0);
    expect((r['dependencies'] as Map).length, 2);
    expect((r['database_sha256'] as String).length, 64);
    expect(a.catalog.length, 7867);
    expect(a.catalog.map((r) => r['id']).toSet().length, 7867);
    expect(a.catalog.fold<int>(0, (n, r) => n + (r['n'] as int)), 80668);
  });
  test('All18 merge and bounded-heap presets match independent Python IDs and comparator counts', () {
    for (final entry in (a.data['algorithms'] as Map).entries) {
      final p = (entry.key as String).split(':');
      same(
        practiceTopK(
          a.catalog,
          minimum: int.parse(p[0]),
          k: int.parse(p[1]),
          method: p[2],
        ),
        entry.value,
      );
    }
    expect(practiceTopK(a.catalog)['ids'], [
      1041,
      1104,
      3451,
      80906,
      2360,
      951,
      105504,
      1217,
      318,
      905,
    ]);
  });
  test('Heap equals independent total-order sort for every source preset and reversed input', () {
    for (final minimum in [1, 10, 50]) {
      final rows = a.catalog.where((r) => (r['n'] as int) >= minimum).toList()
        ..sort((x, y) {
          final key = practiceRankKey(y).compareTo(practiceRankKey(x));
          return key != 0 ? key : (x['id'] as int).compareTo(y['id'] as int);
        });
      for (final k in [5, 10, 20]) {
        expect(
          practiceTopK(a.catalog, k: k, minimum: minimum)['ids'],
          rows.take(k).map((r) => r['id']).toList(),
        );
        expect(
          practiceTopK(
            a.catalog.reversed.toList(),
            k: k,
            minimum: minimum,
          )['ids'],
          rows.take(k).map((r) => r['id']).toList(),
        );
      }
    }
  });
  test(
    'K0,K>n,empty eligibility,deterministic ties and invalid Top-K requests',
    () {
      final fixture = [
        {'id': 2, 'n': 2, 'total': 8.0},
        {'id': 1, 'n': 2, 'total': 8.0},
        {'id': 3, 'n': 1, 'total': 1.0},
      ];
      for (final method in ['heap', 'merge']) {
        expect(practiceTopK(fixture, k: 2, minimum: 1, method: method)['ids'], [
          1,
          2,
        ]);
        expect(
          practiceTopK(fixture, k: 20, minimum: 1, method: method)['ids'],
          [1, 2, 3],
        );
        expect(
          practiceTopK(fixture, k: 0, minimum: 1, method: method)['ids'],
          isEmpty,
        );
        expect(
          practiceTopK(fixture, k: 2, minimum: 50, method: method)['ids'],
          isEmpty,
        );
      }
      for (final run in [
        () => practiceTopK(fixture, k: -1),
        () => practiceTopK(fixture, minimum: 0),
        () => practiceTopK(fixture, method: 'random'),
      ]) {
        expect(run, throwsArgumentError);
      }
    },
  );
  test('Actual SQLite executes all104 source-backed query presets with exact row identities', () async {
    for (final entry in (a.data['sql'] as Map).entries) {
      final p = (entry.key as String).split(':');
      final plan = practiceSqlPlan(
        task: p[0],
        variant: p[1],
        genre: p[2],
        minimum: int.parse(p[3]),
        k: int.parse(p[4]),
      );
      same(await sql.query(plan), entry.value);
    }
  });
  test('JOIN fanout changes counts,weighted mean and empty-genre coverage despite same522 users', () async {
    final correct = (await sql.query(practiceSqlPlan())).single,
        wrong = (await sql.query(practiceSqlPlan(variant: 'fanout'))).single;
    expect(correct['n'], 80668);
    expect(wrong['n'], 217203);
    expect(correct['users'], 522);
    expect(wrong['users'], 522);
    expect(correct['movies'], 7867);
    expect(wrong['movies'], 7865);
    expect(correct['mean'], closeTo(3.5084791986909307, 1e-12));
    expect(wrong['mean'], closeTo(3.5214062420868957, 1e-12));
    expect(
      (await sql.db.rawQuery(
        'SELECT COUNT(*) AS n FROM movies m WHERE NOT EXISTS(SELECT 1 FROM movie_genres g WHERE g.movie_id=m.movie_id)',
      )).single['n'],
      2,
    );
  });
  test('SQLite source constraints,read-only mode,query parameters and handle reopen protect data', () async {
    expect(
      (await sql.db.rawQuery('PRAGMA integrity_check')).single.values.single,
      'ok',
    );
    expect(await sql.db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    expect(
      (await sql.db.rawQuery('SELECT MIN(ts) AS lo,MAX(ts) AS hi FROM ratings'))
          .single['hi'],
      lessThanOrEqualTo(1458635162),
    );
    await expectLater(
      sql.db.execute('DELETE FROM ratings'),
      throwsA(isA<DatabaseException>()),
    );
    final plan = practiceSqlPlan(
      task: 'top_movies',
      genre: 'Drama',
      minimum: 50,
      k: 5,
    );
    expect(plan.parameters, ['Drama', 'Drama', 50, 5]);
    expect(plan.sql, contains('LIMIT ?'));
    final reopened = await PracticeSqlStore.open(
      a,
      factory: databaseFactoryFfi,
      path: '${dir.path}/practice.sqlite',
    );
    expect((await reopened.query(practiceSqlPlan())).single['n'], 80668);
    await reopened.close();
    expect((await sql.query(practiceSqlPlan())).single['n'], 80668);
  });
  test(
    'Actual SQL Top-K equals Dart heap for every support and K contract',
    () async {
      for (final minimum in [1, 10, 50]) {
        for (final k in [5, 10, 20]) {
          final rows = await sql.query(
            practiceSqlPlan(task: 'top_movies', minimum: minimum, k: k),
          );
          expect(
            rows.map((r) => r['movie_id']).toList(),
            practiceTopK(a.catalog, minimum: minimum, k: k)['ids'],
          );
        }
      }
    },
  );
  test(
    'Window oracle,integer division,empty AVG and invalid SQL selector cases',
    () async {
      final actual = await sql.query(
        practiceSqlPlan(task: 'latest_user', k: 1000),
      );
      final source = await sql.db.rawQuery(
        'SELECT user_id,movie_id,rating,ts FROM ratings',
      );
      final expected = <int, Map<String, Object?>>{};
      for (final r in source) {
        final u = r['user_id'] as int, old = expected[u];
        if (old == null ||
            (r['ts'] as int) > (old['ts'] as int) ||
            (r['ts'] == old['ts'] &&
                (r['movie_id'] as int) > (old['movie_id'] as int))) {
          expected[u] = r;
        }
      }
      final users = expected.keys.toList()..sort();
      same(actual, [for (final u in users) expected[u]]);
      expect(actual.length, 522);
      final empty = (await sql.db.rawQuery(
        'SELECT COUNT(*) AS n,AVG(rating) AS mean FROM ratings WHERE rating>5',
      )).single;
      expect(empty, {'n': 0, 'mean': null});
      expect(
        (await sql.db.rawQuery(
          'SELECT 1/2 AS a,1.0/2 AS b,1.0/NULLIF(0,0) AS c',
        )).single,
        {'a': 0, 'b': .5, 'c': null},
      );
      for (final run in [
        () => practiceSqlPlan(task: 'delete'),
        () => practiceSqlPlan(genre: "All' OR 1=1"),
        () => practiceSqlPlan(variant: 'unknown'),
        () => practiceSqlPlan(k: -1),
        () => practiceSqlPlan(minimum: 0),
      ]) {
        expect(run, throwsArgumentError);
      }
    },
  );
  test('All738 actual-feature logits and stable probabilities match frozen independent references', () {
    final expected = a.data['diagnostics'] as List;
    expect(a.diagnostics.length, 738);
    for (var j = 0; j < 738; j++) {
      same(a.diagnostics[j], expected[j]);
    }
    expect(a.diagnostics.map((r) => r['index']).toSet().length, 738);
  });
  test('All27 diagnostic presets including both authored bugs match Python counts/loss/ratios', () {
    for (final entry in (a.data['metrics'] as Map).entries) {
      final p = (entry.key as String).split(':');
      same(
        practiceMetrics(
          a.diagnostics,
          threshold: double.parse(p[0]),
          bug: p[1],
          fpCost: int.parse(p[2]),
        ),
        entry.value,
      );
    }
  });
  test('Correct precision,wrong denominator and logit threshold have distinct minimal failures', () {
    final correct = practiceMetrics(a.diagnostics),
        swapped = practiceMetrics(a.diagnostics, bug: 'precision_swap'),
        scale = practiceMetrics(a.diagnostics, bug: 'logit_threshold');
    expect(
      [correct['tp'], correct['fp'], correct['tn'], correct['fn']],
      [226, 20, 462, 30],
    );
    expect(correct['precision'], 226 / 246);
    expect(swapped['reported_precision'], 226 / 256);
    expect(swapped['precision'], correct['precision']);
    expect(scale['fn'], isNot(correct['fn']));
    expect(scale['bce'], correct['bce']);
    expect(swapped['bce'], correct['bce']);
    expect(practiceMetrics(a.diagnostics, fpCost: 100)['symbolic_cost'], 2030);
  });
  test('Empty,class-absent,extreme logits and invalid diagnostic inputs preserve defined metrics', () {
    final empty = practiceMetrics([]);
    expect(empty['precision'], isNull);
    expect(empty['accuracy'], isNull);
    expect(empty['bce'], isNull);
    final extremes = [
      {'label': 1, 'logit': 1000.0, 'score': 1.0},
      {'label': 0, 'logit': -1000.0, 'score': 0.0},
    ];
    final r = practiceMetrics(extremes);
    expect(r['bce'], 0);
    expect(r['accuracy'], 1);
    expect(practiceMetrics([extremes.last])['recall'], isNull);
    for (final run in [
      () => practiceMetrics([], threshold: double.nan),
      () => practiceMetrics([], threshold: 1.1),
      () => practiceMetrics([], bug: 'unknown'),
      () => practiceMetrics([], fpCost: -1),
      () => practiceMetrics([
        {'label': 2, 'logit': 0.0, 'score': .5},
      ]),
      () => practiceMetrics([
        {'label': 1, 'logit': double.infinity, 'score': 1.0},
      ]),
    ]) {
      expect(run, throwsArgumentError);
    }
  });
  test('Threshold/cost do not change fixed-score BCE and cost never changes decisions', () {
    final base = practiceMetrics(a.diagnostics);
    for (final t in [.2, .5, .8]) {
      for (final cost in [1, 10, 100]) {
        final r = practiceMetrics(a.diagnostics, threshold: t, fpCost: cost),
            control = practiceMetrics(a.diagnostics, threshold: t);
        expect(r['bce'], base['bce']);
        for (final key in ['tp', 'fp', 'tn', 'fn', 'precision', 'recall']) {
          expect(r[key], control[key]);
        }
      }
    }
  });
}
