import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/features/recommender_capstone/capstone_model.dart';
import 'package:ml_path/features/recommendation/recommendation_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late RecommenderCapstoneAssets a;
  setUpAll(() async {
    a = await RecommenderCapstoneAssets.load();
  });
  test(
    'Original source contract and chronological role counts stay pinned',
    () {
      final r = a.data['report'];
      expect(r['raw_rows'], 100836);
      expect(r['fit_rows'], 80668);
      expect(r['validation_rows'], 10084);
      expect(r['audit_rows'], 10084);
      expect(r['fit_cutoff'], 1458635162);
      expect(r['validation_cutoff'], 1498029445);
      expect(a.model.movies.length, 7867);
      expect(a.model.history.length, 522);
      expect(a.model.positiveCounts.values.reduce((x, y) => x + y), 39254);
      expect(
        r['source_hashes']['ratings.csv.gz'],
        '45062b5491127e0c5715a8fe1422c97434438ec1958c70f8199432e840a5e460',
      );
    },
  );
  test('Every actual source case full Dart retriever reproduces all three Top100 lists', () {
    for (final id in a.data['samples']) {
      final row = a.row(id);
      for (final source in capstoneSources) {
        expect(
          a.model.recommend(id, source, k: 100).map((r) => r.movie).toList(),
          row['sources'][source],
        );
      }
    }
  });
  test(
    'All role users, three fusion lists and contribution traces match Python',
    () {
      for (final rows in (a.data['roles'] as Map).values) {
        for (final row in rows) {
          for (final policy in capstonePolicies.keys) {
            final actual = capstoneFuse(
                  Map<String, dynamic>.from(row['sources']),
                  policy: policy,
                ),
                ref = row['pipelines'][policy];
            expect(actual.candidates, ref['candidates']);
            expect(actual.ranked, ref['ranked']);
            for (var j = 0; j < 10; j++) {
              expect(actual.trace[j]['ranks'], ref['trace'][j]['ranks']);
              expect(
                actual.trace[j]['score'],
                closeTo(ref['trace'][j]['score'], 1e-12),
              );
              for (var k = 0; k < 3; k++) {
                expect(
                  actual.trace[j]['contributions'][k],
                  closeTo(ref['trace'][j]['contributions'][k], 1e-12),
                );
              }
            }
          }
        }
      }
    },
  );
  test('Budgets25/50/100 produce unique bounded unions, all seen excluded', () {
    for (final id in a.data['samples']) {
      final row = a.row(id), seen = a.model.history[id] ?? {};
      for (final budget in [25, 50, 100]) {
        final r = capstoneFuse(
          Map<String, dynamic>.from(row['sources']),
          budget: budget,
        );
        expect(r.candidates.length, lessThanOrEqualTo(3 * budget));
        expect(r.candidates.toSet().length, r.candidates.length);
        expect(r.ranked.toSet().length, r.ranked.length);
        expect(r.ranked.every(r.candidates.contains), isTrue);
        expect(r.candidates.any(seen.containsKey), isFalse);
      }
    }
  });
  test('One-based reciprocal ranks, absent contribution and ID ties have explicit fixture behavior', () {
    final r = capstoneFuse({
      'popularity': [7, 3],
      'content': [3, 7],
      'user_cf': <int>[],
    });
    expect(r.ranked, [3, 7]);
    expect(r.trace.first['contributions'][2], 0);
    expect(r.trace.first['score'], closeTo(1 / 61 + 1 / 62, 1e-12));
    expect(
      capstoneFuse({for (final name in capstoneSources) name: <int>[]}).ranked,
      isEmpty,
    );
    expect(() => capstoneFuse({}, budget: 1), throwsArgumentError);
  });
  test('Validation-only selection preserves preset tie order independently of audit cards', () {
    expect(
      capstoneSelect(
        Map<String, dynamic>.from(a.data['scorecards']['validation']),
      ),
      'rrf_cf',
    );
    final tie = {
      for (final p in capstonePolicies.keys)
        p: {
          'warm': {'ndcg': .1, 'recall': .2},
        },
    };
    expect(capstoneSelect(tie), 'rrf_equal');
    tie['rrf_content']!['warm']!['recall'] = .3;
    expect(capstoneSelect(tie), 'rrf_content');
    expect(a.data['policy']['selected'], 'rrf_cf');
  });
  test('All30 role/method/cohort scorecards reproduce independent macro metrics and pool ceilings', () {
    for (final role in ['validation', 'audit']) {
      final rows = a.data['roles'][role] as List;
      for (final method in [
        'popularity',
        'user_cf',
        ...capstonePolicies.keys,
      ]) {
        for (final scope in ['warm', 'broad', 'cold']) {
          final selected = rows
              .where(
                (r) => scope == 'warm'
                    ? r['train_count'] > 0 && (r['eligible'] as List).isNotEmpty
                    : (r['positive'] as List).isNotEmpty &&
                          (scope != 'cold' || r['train_count'] == 0),
              )
              .toList();
          final totals = {
                'precision': 0.0,
                'recall': 0.0,
                'ndcg': 0.0,
                'candidate_recall': 0.0,
                'oracle_recall10': 0.0,
                'mean_candidates': 0.0,
              },
              union = <int>{};
          for (final row in selected) {
            final ranked = List<int>.from(row['rankings'][method]),
                gold = Set<int>.from(
                  row[scope == 'warm' ? 'eligible' : 'positive'],
                ),
                pool = List<int>.from(
                  capstonePolicies.containsKey(method)
                      ? row['pipelines'][method]['candidates']
                      : (row['sources'][method] as List).take(10),
                );
            final metrics = recommendationMetrics(ranked, gold),
                hits = pool.where(gold.contains).length;
            for (final key in ['precision', 'recall', 'ndcg']) {
              totals[key] = totals[key]! + (metrics[key] as num).toDouble();
            }
            totals['candidate_recall'] =
                totals['candidate_recall']! + hits / gold.length;
            totals['oracle_recall10'] =
                totals['oracle_recall10']! + math.min(10, hits) / gold.length;
            totals['mean_candidates'] =
                totals['mean_candidates']! + pool.length;
            union.addAll(ranked);
          }
          final ref = a.data['scorecards'][role][method][scope];
          expect(selected.length, ref['users']);
          for (final key in totals.keys) {
            expect(totals[key]! / selected.length, closeTo(ref[key], 1e-12));
          }
          expect(union.length / 7867, closeTo(ref['catalog_coverage'], 1e-12));
        }
      }
    }
  });
  test('Cold source policies reduce to correlated popularity fallback', () {
    final row = a.row((a.data['samples'] as List).last);
    expect(row['train_count'], 0);
    expect(row['cold_fallback'], true);
    for (final source in capstoneSources) {
      expect(row['sources'][source], row['sources']['popularity']);
    }
    for (final p in capstonePolicies.keys) {
      expect(
        capstoneFuse(
          Map<String, dynamic>.from(row['sources']),
          policy: p,
        ).ranked,
        row['rankings']['popularity'],
      );
    }
  });
  test(
    'All five required artifact fields reject absent or incompatible values',
    () {
      final expected = Map<String, dynamic>.from(a.data['manifest']);
      expect(capstoneContractErrors(expected, {...expected}), isEmpty);
      expect(
        capstoneGuardedReplay(a.data['roles']['audit'], expected, {
          ...expected,
        })?['hits'],
        2,
      );
      for (final key in expected.keys) {
        final missing = {...expected}..remove(key),
            wrong = {...expected, key: 'software-fixture'};
        expect(capstoneContractErrors(expected, missing), [key]);
        expect(capstoneContractErrors(expected, wrong), [key]);
        expect(
          capstoneGuardedReplay(a.data['roles']['audit'], expected, wrong),
          isNull,
        );
      }
    },
  );
  test('All cache key modes match actual source replay, guard every response and report collisions', () {
    final row = a.row((a.data['samples'] as List).first),
        manifest = Map<String, dynamic>.from(a.data['manifest']);
    final original = capstoneCacheSignature(row, manifest, 'rrf_cf');
    for (final key in manifest.keys) {
      expect(
        capstoneCacheSignature(row, {
          ...manifest,
          key: 'new-generation',
        }, 'rrf_cf'),
        isNot(original),
      );
    }
    expect(
      capstoneCacheSignature(
        {...row, 'history_sha256': 'new-history'},
        manifest,
        'rrf_cf',
      ),
      isNot(original),
    );
    expect(capstoneCacheSignature(row, manifest, 'rrf_equal'), isNot(original));
    expect(
      capstoneCacheSignature(row, manifest, 'rrf_cf', budget: 100),
      isNot(original),
    );
    for (final mode in ['complete', 'shared_user', 'omit_policy']) {
      final r = capstoneReplay(
        a.data['roles']['audit'],
        Map<String, dynamic>.from(a.data['manifest']),
        mode: mode,
      );
      expect(r, a.data['cache'][mode]);
      for (final t in r['trace']) {
        expect(
          t['ranked'],
          capstoneFuse(
            Map<String, dynamic>.from(a.row(t['user'])['sources']),
            policy: t['policy'],
          ).ranked,
        );
      }
    }
    expect(a.data['cache']['complete']['hits'], 2);
    expect(a.data['cache']['shared_user']['rejected'], 1);
    expect(a.data['cache']['omit_policy']['rejected'], 3);
  });
  test(
    'Actual paired mean and stronger CF baseline are retained as limits',
    () {
      final rows = (a.data['roles']['audit'] as List).where(
            (r) => r['train_count'] > 0 && (r['eligible'] as List).isNotEmpty,
          ),
          d = <double>[];
      for (final r in rows) {
        double recall(String p) =>
            (recommendationMetrics(
                      List<int>.from(r['rankings'][p]),
                      List<int>.from(r['eligible']),
                    )['recall']
                    as num)
                .toDouble();
        d.add(recall('rrf_cf') - recall('popularity'));
      }
      expect(d.length, 18);
      expect(
        d.reduce((x, y) => x + y) / d.length,
        closeTo(a.data['paired']['mean'], 1e-12),
      );
      expect(a.data['paired']['low'], 0);
      for (final role in ['validation', 'audit']) {
        expect(
          a.data['scorecards'][role]['user_cf']['warm']['ndcg'],
          greaterThan(a.data['scorecards'][role]['rrf_cf']['warm']['ndcg']),
        );
      }
    },
  );
  test('Original IDF frequencies and genre vectors can be rebuilt from fit-only catalog', () {
    final movies = a.model.movies.values.toList(), genres = a.model.genres;
    for (var j = 0; j < genres.length; j++) {
      final df = movies
          .where((movie) => movie.genres.contains(genres[j]))
          .length;
      expect(
        a.model.idf[j],
        closeTo(1 + math.log((1 + movies.length) / (1 + df)), 1e-12),
      );
    }
    for (final vector in a.model.features.values) {
      final norm = vector.fold(0.0, (s, x) => s + x * x);
      expect(norm, anyOf(closeTo(0, 1e-12), closeTo(1, 1e-12)));
    }
  });
}
