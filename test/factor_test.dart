import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/features/factorization/factor_model.dart';
import 'package:ml_path/features/recommendation/recommendation_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FactorAssets a;
  setUpAll(() async {
    a = await FactorAssets.load();
  });
  test('Same real source roles and complete rank8 dimensions', () {
    expect(a.users.length, 522);
    expect(a.items.length, 7867);
    expect(a.data['report']['positive_count'], 39254);
    for (final m in factorMethods.take(3)) {
      expect(a.weights[m]!.p.length, 522);
      expect(a.weights[m]!.q.length, 7867);
      expect(a.weights[m]!.q.every((r) => r.length == 8), isTrue);
    }
    expect(a.weights['fm']!.v.length, 8408);
    expect(a.weights['fm']!.linear.length, 8408);
  });
  test(
    'Every source case full-catalog top10 and exact scores match all models',
    () {
      for (final sample in a.data['samples']) {
        for (final m in factorMethods) {
          final result = a.recommend(sample['user'], m),
              ref = sample['top'][m] as List;
          expect(
            result.map((r) => r.movie).toList(),
            ref.map((r) => r[0]).toList(),
          );
          for (var j = 0; j < result.length; j++) {
            expect(result[j].score, closeTo(ref[j][1], 1e-10));
          }
        }
      }
    },
  );
  test(
    'All464 diagnostic lists reproduce through complete Dart model forward',
    () {
      for (final row in a.data['rows']) {
        for (final m in factorMethods) {
          expect(
            a.recommend(row['user'], m).map((r) => r.movie).toList(),
            row['rankings'][m],
            reason: '${row['user']} $m',
          );
        }
      }
    },
  );
  test(
    'Real9D ridge system, rhs, solve and source ratings match reference',
    () {
      final ref = a.data['als_audit'], u = a.updateUser(ref['user']);
      for (var j = 0; j < 9; j++) {
        expect(u.b[j], closeTo(ref['b'][j], 1e-11));
        expect(u.after[j], closeTo(ref['solution'][j], 1e-11));
        for (var k = 0; k < 9; k++) {
          expect(u.a[j][k], closeTo(ref['a'][j][k], 1e-11));
        }
        expect(factorDot(u.a[j], u.after), closeTo(u.b[j], 1e-10));
      }
    },
  );
  test('Conditional ridge objective decreases at each positive regularization setting', () {
    final uid = a.data['als_audit']['user'];
    for (final reg in [.1, 1.0, 10.0]) {
      final u = a.updateUser(uid, reg: reg);
      expect(u.afterLoss, lessThanOrEqualTo(u.beforeLoss + 1e-10));
      for (var j = 0; j < 9; j++) {
        expect(factorDot(u.a[j], u.after), closeTo(u.b[j], 1e-10));
      }
    }
    expect(
      () => factorSolve(
        [
          [0.0],
        ],
        [1],
      ),
      throwsArgumentError,
    );
  });
  test(
    'ALS full fit objective traces monotonically decrease, finite values',
    () {
      for (final m in ['explicit_als', 'implicit_als']) {
        final trace = (a.data['weights'][m]['trace'] as List).cast<num>();
        for (var j = 1; j < trace.length; j++) {
          expect(trace[j].isFinite, isTrue);
          expect(trace[j], lessThanOrEqualTo(trace[j - 1] + 1e-7));
        }
      }
    },
  );
  test(
    'Stable BPR real margin/loss/derivative and extreme algebraic fixtures',
    () {
      final pair = a.data['pair_audit'],
          u = pair['user'] as int,
          i = pair['positive'] as int,
          j = pair['unobserved'] as int,
          d = a.score(u, i, 'bpr') - a.score(u, j, 'bpr');
      expect(d, closeTo(pair['margin'], 1e-12));
      expect(factorSoftplus(-d), closeTo(pair['loss'], 1e-12));
      expect(factorBprDerivative(d), closeTo(pair['derivative'], 1e-12));
      expect(a.base.history[u]!.containsKey(j), isFalse);
      expect(a.base.history[u]![i], greaterThanOrEqualTo(4));
      expect(factorSoftplus(1000), 1000);
      expect(factorSoftplus(-1000), 0);
      expect(factorBprDerivative(1000), 0);
      expect(factorBprDerivative(-1000), -1);
      expect(factorBprDerivative(0), -.5);
    },
  );
  test('FM active source features, sparse pair expansion and cache equal trained score', () {
    final ref = a.data['fm_audit'],
        u = ref['user'] as int,
        i = ref['item'] as int,
        e = a.fmExplain(u, i);
    expect(e['indices'], ref['indices']);
    expect(e['values'], ref['values']);
    expect(e['score'], closeTo(ref['score'], 1e-11));
    expect(a.score(u, i, 'fm'), closeTo(e['score'], 1e-11));
    final sum = (e['pairs'] as List).fold(
      0.0,
      (s, p) => s + (p['value'] as num).toDouble(),
    );
    expect(sum, closeTo(e['interaction'], 1e-12));
  });
  test('FM genre input removal recomputes same weights, with only user/item dot remaining', () {
    final ref = a.data['fm_audit'],
        u = ref['user'] as int,
        i = ref['item'] as int,
        w = a.weights['fm']!,
        ui = a.userIndex[u]!,
        ii = a.users.length + a.itemIndex[i]!,
        e = a.fmExplain(u, i, genres: false);
    expect((e['pairs'] as List).length, 1);
    expect(e['interaction'], closeTo(factorDot(w.v[ui], w.v[ii]), 1e-12));
    expect(
      e['score'],
      closeTo(
        (w.raw['bias'] as num) +
            w.linear[ui] +
            w.linear[ii] +
            factorDot(w.v[ui], w.v[ii]),
        1e-12,
      ),
    );
    expect(
      (e['score'] as double) - (a.fmExplain(u, i)['score'] as double),
      isNot(closeTo(0, 1e-5)),
    );
  });
  test('All models exclude low-rated seen items and actual cold source user uses popularity', () {
    final cold = (a.data['samples'] as List).last['user'] as int;
    expect(a.userIndex.containsKey(cold), isFalse);
    for (final m in factorMethods) {
      expect(
        a.recommend(cold, m).map((r) => r.movie).toList(),
        a.base.recommend(cold, 'popularity').map((r) => r.movie).toList(),
      );
      final uid = a.data['samples'][0]['user'] as int;
      expect(
        a
            .recommend(uid, m, k: 50)
            .every((r) => !a.base.history[uid]!.containsKey(r.movie)),
        isTrue,
      );
    }
  });
  test('Six methods both cohorts exact frozen scorecards and K5 prefixes', () {
    for (final m in [...factorMethods, 'popularity', 'user_cf']) {
      for (final warm in [true, false]) {
        final s = recommendationScorecard(
              a.data['rows'],
              m,
              warmOnly: warm,
              catalogSize: a.items.length,
            ),
            r = a.data['scorecards'][m][warm ? 'warm' : 'all'];
        for (final k in s.keys) {
          expect(s[k], closeTo(r[k], 1e-12));
        }
        final k5 = recommendationScorecard(
          a.data['rows'],
          m,
          k: 5,
          warmOnly: warm,
          catalogSize: a.items.length,
        );
        expect(k5['users'], s['users']);
        expect(k5['recall'], lessThanOrEqualTo(s['recall']! + 1e-12));
      }
    }
  });
  test('Actual Recall/NDCG tradeoff and latent orthogonal rotation fixture remain explicit', () {
    final s = a.data['scorecards'];
    expect(
      s['explicit_als']['warm']['recall'],
      greaterThan(s['user_cf']['warm']['recall']),
    );
    expect(
      s['explicit_als']['warm']['ndcg'],
      lessThan(s['user_cf']['warm']['ndcg']),
    );
    final p = a.weights['explicit_als']!.p.first,
        q = a.weights['explicit_als']!.q.first,
        pr = [-p[1], p[0], ...p.skip(2)],
        qr = [-q[1], q[0], ...q.skip(2)];
    expect(factorDot(pr, qr), closeTo(factorDot(p, q), 1e-12));
    expect(
      math.sqrt(factorDot(pr, pr)),
      closeTo(math.sqrt(factorDot(p, p)), 1e-12),
    );
  });
}
