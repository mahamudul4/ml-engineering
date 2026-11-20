import 'dart:math';

/// Small row-major arrays for a broadcasting visualization, not a Python engine.
class ShapeArray {
  final List<int> shape;
  final List<double> values;
  ShapeArray(List<int> dimensions, List<double> data)
    : shape = List.unmodifiable(dimensions),
      values = List.unmodifiable(data) {
    if (dimensions.length > 4 ||
        dimensions.any((d) => d < 0 || d > 100) ||
        elements(dimensions) > 4096 ||
        data.length != elements(dimensions) ||
        data.any((x) => !x.isFinite)) {
      throw ArgumentError(
        'Use matching finite data and small nonnegative shapes.',
      );
    }
  }
  static int elements(List<int> shape) => shape.fold(1, (a, b) => a * b);
  static String label(List<int> shape) => shape.isEmpty
      ? '()'
      : '(${shape.join(', ')}${shape.length == 1 ? ',' : ''})';
  static List<int> broadcastShape(List<int> a, List<int> b) {
    if ([...a, ...b].any((d) => d < 0 || d > 100) ||
        a.length > 4 ||
        b.length > 4) {
      throw ArgumentError('Unsupported dimensions');
    }
    final result = <int>[];
    for (var i = 1; i <= max(a.length, b.length); i++) {
      final x = i <= a.length ? a[a.length - i] : 1;
      final y = i <= b.length ? b[b.length - i] : 1;
      if (x != y && x != 1 && y != 1) {
        throw ArgumentError('Trailing dimensions $x and $y do not broadcast.');
      }
      result.insert(0, x == 1 ? y : x);
    }
    if (elements(result) > 4096) {
      throw ArgumentError('Output too large for this lab.');
    }
    return List.unmodifiable(result);
  }

  ShapeArray add(ShapeArray other) {
    final output = broadcastShape(shape, other.shape);
    double at(ShapeArray source, List<int> coordinates) {
      var index = 0;
      final offset = output.length - source.shape.length;
      for (var j = 0; j < source.shape.length; j++) {
        index =
            index * source.shape[j] +
            (source.shape[j] == 1 ? 0 : coordinates[offset + j]);
      }
      return source.values[index];
    }

    final data = <double>[];
    for (var i = 0; i < elements(output); i++) {
      var remaining = i;
      final coordinates = List<int>.filled(output.length, 0);
      for (var j = output.length - 1; j >= 0; j--) {
        coordinates[j] = remaining % output[j];
        remaining ~/= output[j];
      }
      final value = at(this, coordinates) + at(other, coordinates);
      if (!value.isFinite) throw ArgumentError('Non-finite arithmetic result.');
      data.add(value);
    }
    return ShapeArray(output, data);
  }
}

/// One-pass illustrative source of IDs 1..total; no retained batch history.
class BatchCursor {
  final int total, batchSize;
  final bool dropLast;
  int _position = 0, _emitted = 0, _dropped = 0;
  BatchCursor({
    required this.total,
    required this.batchSize,
    this.dropLast = false,
  }) {
    if (total < 0 || total > 10000 || batchSize <= 0 || batchSize > 10000) {
      throw ArgumentError(
        'Use nonnegative total and positive bounded batch size.',
      );
    }
  }
  int get scanned => _position;
  int get emitted => _emitted;
  int get dropped => _dropped;
  bool get exhausted => _position == total;
  List<int>? next() {
    if (exhausted) return null;
    final remaining = total - _position;
    if (dropLast && remaining < batchSize) {
      _dropped += remaining;
      _position = total;
      return null;
    }
    final count = min(batchSize, remaining);
    final batch = [for (var i = 1; i <= count; i++) _position + i];
    _position += count;
    _emitted += count;
    return List.unmodifiable(batch);
  }
}
