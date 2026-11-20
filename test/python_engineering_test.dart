import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/features/python/python_model.dart';

void main() {
  test('column plus vector produces the NumPy pairwise grid, aligned columns pair rows', () {
    final a = ShapeArray([3, 1], [1, 2, 3]);
    final grid = a.add(ShapeArray([3], [10, 20, 30]));
    expect(grid.shape, [3, 3]);
    expect(grid.values, [11, 21, 31, 12, 22, 32, 13, 23, 33]);
    final aligned = a.add(ShapeArray([3, 1], [10, 20, 30]));
    expect(aligned.shape, [3, 1]);
    expect(aligned.values, [11, 22, 33]);
  });
  test(
    'scalar, zero-axis and incompatible dimensions follow broadcasting rules',
    () {
      final empty = ShapeArray([0, 3], []).add(ShapeArray([1, 3], [1, 2, 3]));
      expect(empty.shape, [0, 3]);
      expect(empty.values, isEmpty);
      expect(ShapeArray([], [2]).add(ShapeArray([], [3])).values, [5]);
      expect(ShapeArray([], [2]).add(ShapeArray([2], [3, 4])).values, [5, 6]);
      expect(() => ShapeArray.broadcastShape([3], [2]), throwsArgumentError);
      expect(ShapeArray.label([]), '()');
      expect(ShapeArray.label([3]), '(3,)');
    },
  );
  test('multidimensional indexing uses correct trailing-axis strides', () {
    final a = ShapeArray([2, 1, 2], [1, 2, 3, 4]);
    final b = ShapeArray([1, 3, 1], [10, 20, 30]);
    final result = a.add(b);
    expect(result.shape, [2, 3, 2]);
    expect(result.values, [11, 12, 21, 22, 31, 32, 13, 14, 23, 24, 33, 34]);
    expect(b.add(a).values, result.values);
  });
  test(
    'array boundary copies inputs and rejects invalid or oversized contracts',
    () {
      final shape = [2], data = [1.0, 2.0];
      final a = ShapeArray(shape, data);
      shape[0] = 1;
      data[0] = 99;
      expect(a.shape, [2]);
      expect(a.values, [1, 2]);
      expect(() => a.values.add(4), throwsUnsupportedError);
      expect(() => ShapeArray([-1], []), throwsArgumentError);
      expect(() => ShapeArray([2], [1]), throwsArgumentError);
      expect(
        () => ShapeArray.broadcastShape([100, 1], [1, 100]),
        throwsArgumentError,
      );
      expect(
        () => ShapeArray.broadcastShape([1, 1, 1, 1, 1], []),
        throwsArgumentError,
      );
    },
  );
  test('nonfinite input and arithmetic overflow fail explicitly', () {
    expect(() => ShapeArray([1], [double.nan]), throwsArgumentError);
    expect(() => ShapeArray([1], [double.infinity]), throwsArgumentError);
    expect(
      () => ShapeArray([], [1e308]).add(ShapeArray([], [1e308])),
      throwsArgumentError,
    );
  });
  test('one-pass batches retain the final partial and remain exhausted', () {
    final cursor = BatchCursor(total: 10, batchSize: 3);
    expect(cursor.next(), [1, 2, 3]);
    expect(cursor.next(), [4, 5, 6]);
    expect(cursor.next(), [7, 8, 9]);
    expect(cursor.next(), [10]);
    expect(cursor.emitted, 10);
    expect(cursor.scanned, 10);
    expect(cursor.dropped, 0);
    expect(cursor.exhausted, isTrue);
    expect(cursor.next(), isNull);
    expect(cursor.next(), isNull);
  });
  test(
    'drop-last is explicit, including empty and smaller-than-batch sources',
    () {
      final c = BatchCursor(total: 10, batchSize: 3, dropLast: true);
      c.next();
      c.next();
      c.next();
      expect(c.exhausted, isFalse);
      expect(c.next(), isNull);
      expect(c.emitted, 9);
      expect(c.scanned, 10);
      expect(c.dropped, 1);
      expect(BatchCursor(total: 0, batchSize: 3).next(), isNull);
      final small = BatchCursor(total: 2, batchSize: 3, dropLast: true);
      expect(small.next(), isNull);
      expect(small.dropped, 2);
      expect(BatchCursor(total: 2, batchSize: 3).next(), [1, 2]);
    },
  );
  test(
    'batch state rejects invalid settings and emitted values are immutable',
    () {
      expect(() => BatchCursor(total: -1, batchSize: 3), throwsArgumentError);
      expect(() => BatchCursor(total: 10, batchSize: 0), throwsArgumentError);
      expect(
        () => BatchCursor(total: 10001, batchSize: 1),
        throwsArgumentError,
      );
      final first = BatchCursor(total: 3, batchSize: 2).next()!;
      expect(() => first.add(8), throwsUnsupportedError);
    },
  );
}
