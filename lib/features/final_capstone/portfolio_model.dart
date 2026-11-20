import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

import '../../data/learning_repository.dart';

const portfolioProjects = ['classical', 'deep', 'recommendation', 'rag'];
const portfolioSlices = ['all', 'first5', 'last5'];
const portfolioFaults = [
  'none',
  'source_mismatch',
  'license_missing',
  'production_claim',
];
const mockRoles = [
  'ml_engineer',
  'data_scientist',
  'recs_engineer',
  'llm_engineer',
];
const mockRounds = ['project', 'coding', 'statistics', 'systems'];
const mockChecks = [
  'contract',
  'source',
  'baseline',
  'validation',
  'failure',
  'limits',
];

Map<String, dynamic> portfolioSummary(
  String project,
  List<dynamic> source, {
  String scope = 'all',
}) {
  if (!portfolioProjects.contains(project) ||
      !portfolioSlices.contains(scope)) {
    throw ArgumentError('Unknown project/slice');
  }
  final rows = scope == 'all'
      ? source
      : scope == 'first5'
      ? source.take(5).toList()
      : source.skip(math.max(0, source.length - 5)).toList();
  final n = rows.length;
  if (project == 'classical' || project == 'deep') {
    final threshold = project == 'classical' ? .3 : .25;
    var tp = 0, fp = 0, fn = 0, tn = 0;
    for (final r in rows) {
      final p = r['probability'] as num, y = r['positive'];
      if (!p.isFinite || p < 0 || p > 1 || (y != 0 && y != 1)) {
        throw ArgumentError('Invalid evidence row');
      }
      if (p >= threshold) {
        if (y == 1) {
          tp++;
        } else {
          fp++;
        }
      } else {
        if (y == 1) {
          fn++;
        } else {
          tn++;
        }
      }
    }
    return {
      'n': n,
      'threshold': threshold,
      'tp': tp,
      'fp': fp,
      'tn': tn,
      'fn': fn,
      'accuracy': n > 0 ? (tp + tn) / n : null,
      'precision': tp + fp > 0 ? tp / (tp + fp) : null,
      'recall': tp + fn > 0 ? tp / (tp + fn) : null,
      'mean_cost': n > 0 ? (fp + 4 * fn) / n : null,
    };
  }
  if (project == 'recommendation') {
    final eligible = rows
        .where((r) => (r['eligible'] as List).isNotEmpty)
        .toList();
    var precision = 0.0, recall = 0.0, ndcg = 0.0, hitsTotal = 0;
    for (final r in eligible) {
      final gold = (r['eligible'] as List).toSet(),
          ranked = (r['rankings']['rrf_cf'] as List).take(10).toList();
      if (ranked.toSet().length != ranked.length) {
        throw ArgumentError('Duplicate ranked IDs');
      }
      var hits = 0, dcg = 0.0, idcg = 0.0;
      for (var j = 0; j < ranked.length; j++) {
        if (gold.contains(ranked[j])) {
          hits++;
          dcg += 1 / (math.log(j + 2) / math.ln2);
        }
      }
      for (var j = 0; j < math.min(10, gold.length); j++) {
        idcg += 1 / (math.log(j + 2) / math.ln2);
      }
      hitsTotal += hits;
      precision += hits / 10;
      recall += hits / gold.length;
      ndcg += dcg / idcg;
    }
    return {
      'n': n,
      'eligible_users': eligible.length,
      'excluded_users': n - eligible.length,
      'hits': hitsTotal,
      'precision': eligible.isNotEmpty ? precision / eligible.length : null,
      'recall': eligible.isNotEmpty ? recall / eligible.length : null,
      'ndcg': eligible.isNotEmpty ? ndcg / eligible.length : null,
    };
  }
  return {
    'n': n,
    'format_valid': rows.where((r) => r['format_valid'] == true).length,
    'exact_packs': rows.where((r) => r['exact'] == true).length,
    'emitted': rows.where((r) => r['emitted'] == true).length,
    'verified_answers': 0,
    'truth_accuracy': null,
  };
}

Map<String, dynamic> portfolioAudit(
  Map<String, dynamic> card, {
  String fault = 'none',
}) {
  if (!portfolioFaults.contains(fault)) {
    throw ArgumentError('Unknown audit fixture');
  }
  final expected = Map<String, dynamic>.from(card['contract']),
      loaded = {...expected};
  if (fault == 'source_mismatch') {
    loaded['source_sha256'] = 'authored wrong source identity';
  }
  if (fault == 'license_missing') loaded['license'] = '';
  if (fault == 'production_claim') loaded['production_measured'] = true;
  final issues = [
    for (final key in expected.keys)
      if (loaded[key] != expected[key]) key,
  ];
  return {'passed': issues.isEmpty, 'issues': issues, 'loaded': loaded};
}

class PortfolioAssets {
  final Map<String, dynamic> data;
  PortfolioAssets(this.data);
  static PortfolioAssets? _cached;
  static Future<PortfolioAssets>? _pending;
  static Future<PortfolioAssets> load() async =>
      _cached ??= await (_pending ??= _load());
  static Future<PortfolioAssets> _load() async => PortfolioAssets(
    jsonDecode(
      await rootBundle.loadString(
        'assets/datasets/final_capstone/portfolio_lab.json',
      ),
    ),
  );
  Map<String, dynamic> summary(String project, {String scope = 'all'}) =>
      portfolioSummary(project, data['records'][project], scope: scope);
}

class MockDraft {
  final String text;
  final Set<String> checked;
  MockDraft(this.text, Set<String> checked)
    : checked = Set.unmodifiable(checked) {
    if (text.length > 8000 || checked.any((v) => !mockChecks.contains(v))) {
      throw const FormatException('Invalid mock draft');
    }
  }
  factory MockDraft.empty() => MockDraft('', {});
  Map<String, dynamic> toJson() => {
    'version': 1,
    'text': text,
    'checked': mockChecks.where(checked.contains).toList(),
  };
  factory MockDraft.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1 ||
        json['text'] is! String ||
        json['checked'] is! List ||
        (json['checked'] as List).any((v) => v is! String)) {
      throw const FormatException('Invalid mock draft schema');
    }
    return MockDraft(json['text'], Set<String>.from(json['checked']));
  }
}

class MockDraftStore {
  final LearningRepository repository;
  MockDraftStore(this.repository);
  static String key(String role, String round) {
    if (!mockRoles.contains(role) || !mockRounds.contains(round)) {
      throw ArgumentError('Unknown mock role/round');
    }
    return 'ch40:mock:$role:$round';
  }

  Future<MockDraft> load(String role, String round) async {
    final value = await repository.setting(key(role, round));
    return value == null
        ? MockDraft.empty()
        : MockDraft.fromJson(jsonDecode(value));
  }

  Future<void> save(String role, String round, MockDraft draft) =>
      repository.setSetting(key(role, round), jsonEncode(draft.toJson()));
}
