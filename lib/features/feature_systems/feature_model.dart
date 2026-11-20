import 'dart:convert';

import 'package:flutter/services.dart';

const featureFields = ['lag1', 'lag7', 'mean7', 'observed7', 'age_days'];
const featureScenarios = ['on_time', 'late_fixture'];
String featureDate(int day) => DateTime.utc(
  2011,
  1,
  1,
).add(Duration(days: day)).toIso8601String().substring(0, 10);
Map<String, num?> pointInTimeFeatures(
  List<dynamic> events,
  int target, {
  int? asof,
  bool latest = false,
}) {
  final known = events
          .where(
            (r) =>
                r['event_day'] < target &&
                (latest || r['available_day'] <= (asof ?? target)),
          )
          .toList(),
      window = known.where((r) => r['event_day'] >= target - 7).toList();
  int? lag(int offset) {
    for (final r in known) {
      if (r['event_day'] == target - offset) return r['cnt'] as int;
    }
    return null;
  }

  int? newest;
  for (final r in known) {
    if (newest == null || r['event_day'] > newest) {
      newest = r['event_day'] as int;
    }
  }
  return {
    'lag1': lag(1),
    'lag7': lag(7),
    'mean7': window.isEmpty
        ? null
        : window.fold<int>(0, (s, r) => s + (r['cnt'] as int)) / window.length,
    'observed7': window.length,
    'age_days': newest == null ? null : target - 1 - newest,
  };
}

List<String> featureDifference(
  Map<String, dynamic> a,
  Map<String, dynamic> b,
) => [
  for (final key in featureFields)
    if ((a[key] == null) != (b[key] == null) ||
        (a[key] != null &&
            b[key] != null &&
            ((a[key] as num) - (b[key] as num)).abs() > 1e-10))
      key,
];
List<String> featureContractErrors(
  Map<String, dynamic> expected,
  Map<String, dynamic> loaded,
) => [
  for (final key in [
    'feature_version',
    'definition_sha256',
    'source_sha256',
    'availability_rule',
    'entity_key',
  ])
    if (expected[key] != loaded[key]) key,
];
Map<String, num?>? guardedPointInTimeFeatures(
  List<dynamic> events,
  int target,
  Map<String, dynamic> expected,
  Map<String, dynamic> loaded, {
  bool latest = false,
}) {
  if (featureContractErrors(expected, loaded).isNotEmpty) return null;
  return pointInTimeFeatures(events, target, latest: latest);
}

List<String> validateFeatureEvent(Map<String, dynamic> row) {
  final errors = <String>[];
  for (final key in ['event_day', 'available_day', 'cnt', 'weekday']) {
    if (row[key] is! int) errors.add('type:$key');
  }
  for (final key in ['date', 'event_key']) {
    if (row[key] is! String) errors.add('type:$key');
  }
  if (errors.isNotEmpty) return errors;
  final day = row['event_day'] as int;
  if (row['cnt'] < 0) errors.add('negative_count');
  if (row['available_day'] < day + 1) {
    errors.add('availability_before_day_close');
  }
  if (row['date'] != featureDate(day)) errors.add('calendar_date');
  if (row['event_key'] != 'bike-global:${row['date'] ?? ''}') {
    errors.add('entity_key');
  }
  if (row['weekday'] !=
      DateTime.utc(2011, 1, 1).add(Duration(days: day)).weekday % 7) {
    errors.add('weekday');
  }
  return errors;
}

Map<String, int> featureReplay(
  List<dynamic> events, {
  bool duplicates = false,
  bool invalid = false,
  int chunk = 32,
}) {
  if (chunk < 1) throw ArgumentError('Chunk must be positive');
  final ordered = [for (final r in events) Map<String, dynamic>.from(r)]
    ..sort((a, b) {
      final c = (a['available_day'] as int).compareTo(b['available_day']);
      return c != 0 ? c : (a['event_day'] as int).compareTo(b['event_day']);
    });
  final rows = [
        ...ordered,
        if (duplicates) ...ordered,
        if (invalid) {...ordered.first, 'cnt': -1},
      ],
      store = <String, Map<String, dynamic>>{};
  var inserted = 0, dupes = 0, rejected = 0;
  for (var start = 0; start < rows.length; start += chunk) {
    for (final row in rows.skip(start).take(chunk)) {
      if (validateFeatureEvent(row).isNotEmpty) {
        rejected++;
        continue;
      }
      final key = row['event_key'] as String, old = store[key];
      if (old != null) {
        final same = [
          'event_day',
          'available_day',
          'cnt',
          'weekday',
          'date',
        ].every((k) => old[k] == row[k]);
        if (same) {
          dupes++;
        } else {
          rejected++;
        }
      } else {
        store[key] = row;
        inserted++;
      }
    }
  }
  return {
    'deliveries': rows.length,
    'inserted': inserted,
    'duplicates': dupes,
    'rejected': rejected,
    'batches': (rows.length / chunk).ceil(),
    'stored': store.length,
  };
}

class FeatureSystemAssets {
  final Map<String, dynamic> data;
  static FeatureSystemAssets? _cached;
  static Future<FeatureSystemAssets>? _pending;
  static Future<FeatureSystemAssets> load() async =>
      _cached ??= await (_pending ??= _load());
  static Future<FeatureSystemAssets> _load() async => FeatureSystemAssets(
    jsonDecode(
      await rootBundle.loadString(
        'assets/datasets/bike_sharing/pipeline_lab.json',
      ),
    ),
  );
  FeatureSystemAssets(this.data);
  List<dynamic> events(String scenario) => data['events'][scenario];
  Map<String, dynamic> manifest(String scenario) =>
      Map<String, dynamic>.from(data['manifests'][scenario]);
}
