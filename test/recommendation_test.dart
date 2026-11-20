import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/features/recommendation/recommendation_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late RecommendationAssets a;
  setUpAll(() async {
    a = await RecommendationAssets.load();
  });
  test('Original source roles keep all 100836 ratings with strict timestamp boundary', () {
    final fit = a.data['train'] as List,
        future = a.data['future'] as List,
        cut = a.data['report']['cutoff_timestamp'] as int;
    expect(fit.length, 80668);
    expect(future.length, 20168);
    expect(fit.every((r) => r[3] <= cut), isTrue);
    expect(future.every((r) => r[3] > cut), isTrue);
    expect(a.movies.length, 7867);
    expect(a.history.length, 522);
    expect(fit.map((r) => (r[0], r[1])).toSet().length, fit.length);
  });
  test(
    'IDF statistics derive from fit metadata, zero-genre vectors remain zero',
    () {
      for (var j = 0; j < a.genres.length; j++) {
        final df = a.movies.values
            .where((m) => m.genres.contains(a.genres[j]))
            .length;
        expect(
          a.idf[j],
          closeTo(1 + math.log((1 + a.movies.length) / (1 + df)), 1e-12),
        );
      }
      for (final m in a.movies.values) {
        final norm = a.features[m.id]!.fold(0.0, (s, v) => s + v * v);
        expect(norm, closeTo(m.genres.isEmpty ? 0 : 1, 1e-12));
      }
    },
  );
  test('Bayesian shrinkage uses all ratings, limits, cold fallback and global mean', () {
    expect(a.mean, closeTo(a.data['report']['global_mean'], 1e-12));
    for (final i in a.movies.keys.take(100)) {
      expect(
        a.bayesian(i, strength: 0),
        closeTo(a.totals[i]! / a.counts[i]!, 1e-12),
      );
      final x = a.bayesian(i);
      expect(
        x,
        greaterThanOrEqualTo(
          math.min(a.mean, a.totals[i]! / a.counts[i]!) - 1e-12,
        ),
      );
      expect(
        x,
        lessThanOrEqualTo(
          math.max(a.mean, a.totals[i]! / a.counts[i]!) + 1e-12,
        ),
      );
    }
    expect(a.bayesian(-1), a.mean);
  });
  test('Every saved source neighbor matches support, score, order, self and overlap gate', () {
    for (final sample in a.data['samples']) {
      final ns = a.neighbours(sample['user']);
      expect(
        ns.map((n) => n.user).toList(),
        (sample['neighbours'] as List).map((n) => n[0]).toList(),
      );
      for (var j = 0; j < ns.length; j++) {
        final ref = sample['neighbours'][j];
        expect(ns[j].similarity, closeTo(ref[1], 1e-12));
        expect(ns[j].overlap, ref[2]);
        expect(ns[j].user, isNot(sample['user']));
        expect(ns[j].overlap, greaterThanOrEqualTo(2));
      }
    }
  });
  test(
    'All saved score traces and unfiltered top10 lists reproduce in Dart',
    () {
      for (final sample in a.data['samples']) {
        for (final method in recommendationMethods) {
          final top = a.recommend(sample['user'], method),
              refs = sample['top'][method] as List;
          expect(
            top.map((r) => r.movie).toList(),
            refs.map((r) => r[0]).toList(),
          );
          for (var j = 0; j < top.length; j++) {
            expect(top[j].score, closeTo(refs[j][1], 1e-11));
          }
          expect(
            a
                .recommend(sample['user'], method, excludeSeen: false)
                .map((r) => r.movie)
                .toList(),
            sample['unfiltered'][method],
          );
        }
      }
    },
  );
  test('Every future user full-catalog top10 reproduces all four methods', () {
    for (final row in a.data['rows']) {
      for (final method in recommendationMethods) {
        expect(
          a.recommend(row['user'], method).map((r) => r.movie).toList(),
          row['rankings'][method],
          reason: 'user ${row['user']} $method',
        );
      }
    }
  });
  test('Original cold source user uses explicit popularity fallback without synthetic taste', () {
    final sample = (a.data['samples'] as List).last, u = sample['user'] as int;
    expect(a.history.containsKey(u), isFalse);
    expect(a.neighbours(u), isEmpty);
    for (final method in ['content', 'user_cf']) {
      expect(
        a.recommend(u, method).map((r) => r.movie).toList(),
        a.recommend(u, 'popularity').map((r) => r.movie).toList(),
      );
    }
  });
  test(
    'All observed low-rated items are excluded, topK fills after filtering',
    () {
      final sample = a.data['samples'][0], u = sample['user'] as int;
      expect(a.history[u]!.values.any((r) => r < 4), isTrue);
      for (final method in recommendationMethods) {
        final ranked = a.recommend(u, method, k: 50);
        expect(ranked.length, 50);
        expect(
          ranked.every((r) => !a.history[u]!.containsKey(r.movie)),
          isTrue,
        );
        expect(ranked.map((r) => r.movie).toSet().length, 50);
      }
    },
  );
  test('Real item-pair co-like count and cosine match source references', () {
    for (final p in a.data['item_pairs']) {
      final actual = a.itemSimilarity(p['a'], p['b']);
      for (final key in ['cosine', 'shrunk']) {
        expect(actual[key], closeTo(p[key], 1e-12));
      }
      expect(actual['overlap'], p['overlap']);
    }
  });
  test(
    'Both cohorts and all scorecard measures reproduce all method references',
    () {
      for (final method in recommendationMethods) {
        for (final warm in [true, false]) {
          final actual = recommendationScorecard(
                a.data['rows'],
                method,
                warmOnly: warm,
                catalogSize: a.movies.length,
              ),
              ref = a.data['scorecards'][method][warm ? 'warm' : 'all'];
          for (final key in actual.keys) {
            expect(actual[key], closeTo(ref[key], 1e-12));
          }
        }
      }
    },
  );
  test(
    'Mathematical metric fixture, empty targets and empty cohort stay explicit',
    () {
      final m = recommendationMetrics([10, 20, 30, 40, 50], [20, 40, 60], k: 5);
      expect(m['hits'], 2);
      expect(m['precision'], .4);
      expect(m['recall'], 2 / 3);
      expect(recommendationMetrics([1, 2], [])['ndcg'], isNull);
      expect(recommendationMetrics([1, 2], [])['recall'], isNull);
      expect(recommendationScorecard([], 'user_cf')['recall'], isNull);
    },
  );
  test('Genre ties use numeric IDs, cold item unknown and alternate neighbor settings change scores', () {
    final u = a.data['samples'][0]['user'] as int,
        defaultScores = a.scores(u, 'user_cf'),
        changed = a.scores(u, 'user_cf', shrink: 0, neighbourLimit: 5);
    expect(
      defaultScores.keys.any(
        (i) => (defaultScores[i]! - changed[i]!).abs() > 1e-6,
      ),
      isTrue,
    );
    final ids = a.recommend(
      (a.data['samples'] as List).last['user'],
      'content',
      k: 50,
    );
    for (var j = 1; j < ids.length; j++) {
      if (ids[j].score == ids[j - 1].score) {
        expect(ids[j].movie, greaterThan(ids[j - 1].movie));
      }
    }
    expect(() => a.scores(u, 'unknown'), throwsArgumentError);
  });
}
