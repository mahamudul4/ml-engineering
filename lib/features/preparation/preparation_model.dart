import 'dart:math' as math;

enum FillStrategy { median, mean }

enum UnknownPolicy { ignore, infrequentIfExists }

class NumericRecipe {
  final double fill, mean, std;
  final int fitRows;
  double get scale => std == 0 ? 1 : std;
  const NumericRecipe._(this.fill, this.mean, this.std, this.fitRows);
  factory NumericRecipe.fit(
    List<double?> values, {
    FillStrategy strategy = FillStrategy.median,
  }) {
    if (values.isEmpty) throw ArgumentError('Training values required');
    final observed = values.whereType<double>().toList()..sort();
    if (observed.isEmpty || observed.any((v) => !v.isFinite)) {
      throw ArgumentError(
        'Finite observed training values required; define an explicit all-missing policy',
      );
    }
    final n = observed.length;
    final fill = strategy == FillStrategy.mean
        ? observed.reduce((a, b) => a + b) / n
        : n.isOdd
        ? observed[n ~/ 2]
        : (observed[n ~/ 2 - 1] + observed[n ~/ 2]) / 2;
    final imputed = values.map((v) => v ?? fill).toList();
    final mean = imputed.reduce((a, b) => a + b) / imputed.length;
    final variance =
        imputed.fold<double>(0, (s, x) => s + (x - mean) * (x - mean)) /
        imputed.length;
    if (!fill.isFinite || !mean.isFinite || !variance.isFinite) {
      throw ArgumentError('Numeric overflow in fitted statistics');
    }
    return NumericRecipe._(fill, mean, math.sqrt(variance), values.length);
  }
  double impute(double? value) {
    if (value != null && !value.isFinite) {
      throw ArgumentError('Finite value or null required');
    }
    return value ?? fill;
  }

  double transform(double? value) => (impute(value) - mean) / scale;
}

class FrozenEncoder {
  static const missing = '__MISSING__', infrequent = '__INFREQUENT__';
  final Map<String, int> counts;
  final List<String> vocabulary;
  final Set<String> rare;
  const FrozenEncoder._(this.counts, this.vocabulary, this.rare);
  bool get hasRareBucket => rare.isNotEmpty;
  static String _key(String? value) {
    if (value == missing || value == infrequent) {
      throw ArgumentError('Reserved category token');
    }
    return value ?? missing;
  }

  factory FrozenEncoder.fit(List<String?> values, {int minFrequency = 1}) {
    if (values.isEmpty || minFrequency < 1) {
      throw ArgumentError(
        'Non-empty train data and positive frequency required',
      );
    }
    final counts = <String, int>{};
    for (final value in values) {
      final key = _key(value);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final rare = counts.keys
        .where((key) => counts[key]! < minFrequency)
        .toSet();
    final vocabulary = counts.keys.where((key) => !rare.contains(key)).toList()
      ..sort();
    if (rare.isNotEmpty) vocabulary.add(infrequent);
    return FrozenEncoder._(
      Map.unmodifiable(counts),
      List.unmodifiable(vocabulary),
      Set.unmodifiable(rare),
    );
  }
  List<int> encode(
    String? value, {
    UnknownPolicy policy = UnknownPolicy.ignore,
  }) {
    final key = _key(value);
    String? mapped;
    if (counts.containsKey(key)) {
      mapped = rare.contains(key) ? infrequent : key;
    } else if (policy == UnknownPolicy.infrequentIfExists && hasRareBucket) {
      mapped = infrequent;
    }
    return [for (final category in vocabulary) category == mapped ? 1 : 0];
  }
}
