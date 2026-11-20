import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import 'python_model.dart';

class BroadcastingLab extends StatefulWidget {
  const BroadcastingLab({super.key});
  @override
  State<BroadcastingLab> createState() => _BroadcastingLabState();
}

class _BroadcastingLabState extends State<BroadcastingLab> {
  static const options = <String, List<int>>{
    '(3, 1)': [3, 1],
    '(3,)': [3],
    '(1, 3)': [1, 3],
    '(2, 3)': [2, 3],
    '(2,)': [2],
    '()': [],
    '(0, 3)': [0, 3],
  };
  String left = '(3, 1)', right = '(3,)';
  @override
  Widget build(BuildContext context) {
    ShapeArray array(String key, double step) {
      final shape = options[key]!;
      return ShapeArray(shape, [
        for (var i = 0; i < ShapeArray.elements(shape); i++) (i + 1) * step,
      ]);
    }

    final a = array(left, 1), b = array(right, 10);
    ShapeArray? result;
    try {
      result = a.add(b);
    } on ArgumentError {
      result = null;
    }
    String values(ShapeArray x) =>
        '[${x.values.map((v) => v.toStringAsFixed(0)).join(', ')}]';
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag('ML FOUNDATIONS · CHAPTER 02 · ARRAY SHAPES', icon: Icons.grid_on_outlined),
          const SizedBox(height: 18),
          const Text(
            'A valid operation can be the wrong one.',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          const Text(
            'Trailing dimensions মিলিয়ে A + B করুন। (3,1) ও (3,) error দেয় না—তিনটি aligned pair-এর বদলে নয়টি combination হয়।',
            style: TextStyle(fontFamily: 'NotoSansBengali', height: 2),
          ),
          const SizedBox(height: 18),
          for (final isLeft in [true, false])
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: DropdownButtonFormField<String>(
                key: ValueKey(
                  '${isLeft ? 'py-left' : 'py-right'}-${isLeft ? left : right}',
                ),
                initialValue: isLeft ? left : right,
                decoration: InputDecoration(
                  labelText: isLeft
                      ? 'A shape · values 1, 2, …'
                      : 'B shape · values 10, 20, …',
                ),
                items: [
                  for (final entry in options.keys)
                    DropdownMenuItem(value: entry, child: Text(entry)),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      if (isLeft) {
                        left = v;
                      } else {
                        right = v;
                      }
                    });
                  }
                },
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Tag('A $left ${values(a)}'),
              Tag('B $right ${values(b)}'),
            ],
          ),
          const SizedBox(height: 18),
          if (result == null)
            const Tag(
              'Incompatible trailing dimensions',
              color: Color(0xFFB36D28),
            )
          else ...[
            Text(
              'Output shape: ${ShapeArray.label(result.shape)}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Tag(
              '${result.values.length} output elements · ${result.values.length * 8} bytes float64 payload',
            ),
            const SizedBox(height: 16),
            _arrayCells(result),
            const SizedBox(height: 12),
            Text(
              'Row-major flat output: ${values(result)}',
              style: const TextStyle(fontSize: 12, height: 1.8),
            ),
            if (result.values.isEmpty)
              const Text(
                'Zero-length axis: compatible output, no elements to compute.',
              ),
          ],
          const SizedBox(height: 16),
          const Text(
            'Compatible মানে intended pairing ঠিক নয়। Prediction এবং target-এর shape explicitভাবে validate করুন। Scalar () একটি element; (0,3) empty। Broadcasting input tile না করলেও output/temporary arrays বড় হতে পারে।',
            style: TextStyle(
              fontFamily: 'NotoSansBengali',
              height: 2,
              fontSize: 12,
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                key: const Key('py-align'),
                onPressed: () => setState(() {
                  left = '(3, 1)';
                  right = '(3, 1)';
                }),
                child: const Text('Align both as columns'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  left = '(3, 1)';
                  right = '(3,)';
                }),
                child: const Text('Reset shapes'),
              ),
            ],
          ),
          const Text(
            'Illustrative values. Pure Dart simulation of selected NumPy addition rules; no Python runs here. Payload excludes object overhead, inputs and temporaries.',
            style: TextStyle(fontSize: 10, height: 1.8),
          ),
        ],
      ),
    );
  }

  Widget _arrayCells(ShapeArray array) {
    if (array.values.isEmpty) {
      return const SizedBox.shrink();
    }
    final columns = array.shape.length == 2
        ? array.shape.last
        : array.values.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var start = 0; start < array.values.length; start += columns)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var j = 0; j < columns; j++)
                  SizedBox(
                    width: 68,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: forest.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Text(
                              array.shape.isEmpty
                                  ? '[]'
                                  : array.shape.length == 2
                                  ? '[${start ~/ columns}, $j]'
                                  : '[$j]',
                              style: const TextStyle(fontSize: 10),
                            ),
                            Text(
                              array.values[start + j].toStringAsFixed(0),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class IteratorLab extends StatefulWidget {
  const IteratorLab({super.key});
  @override
  State<IteratorLab> createState() => _IteratorLabState();
}

class _IteratorLabState extends State<IteratorLab> {
  int batchSize = 3;
  bool dropLast = false;
  BatchCursor cursor = BatchCursor(total: 10, batchSize: 3);
  final history = <List<int>>[];
  void reset() {
    cursor = BatchCursor(total: 10, batchSize: batchSize, dropLast: dropLast);
    history.clear();
  }

  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Tag(
          'ML FOUNDATIONS · CHAPTER 02 · ITERATOR STATE',
          icon: Icons.view_stream_outlined,
        ),
        const SizedBox(height: 18),
        const Text(
          'One source. One pass.',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        const Text(
          'Illustrative source IDs 1..10 থেকে পরের batch নিন। Iterator এগিয়ে যায়; exhausted হলে একই object আবার শুরু হয় না। Reset নতুন iterator বোঝায়।',
          style: TextStyle(fontFamily: 'NotoSansBengali', height: 2),
        ),
        const SizedBox(height: 18),
        Text(
          'Batch size: $batchSize',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        Slider(
          key: const Key('py-batch-size'),
          value: batchSize.toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          label: '$batchSize',
          onChanged: (v) => setState(() {
            batchSize = v.round();
            reset();
          }),
        ),
        SwitchListTile.adaptive(
          key: const Key('py-drop-last'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Drop incomplete final batch'),
          subtitle: const Text(
            'An explicit policy, not an automatic generator rule.',
          ),
          value: dropLast,
          onChanged: (v) => setState(() {
            dropLast = v;
            reset();
          }),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Tag('Scanned: ${cursor.scanned}/10'),
            Tag('Emitted: ${cursor.emitted}'),
            Tag('Dropped: ${cursor.dropped}'),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            FilledButton(
              key: const Key('py-next-batch'),
              onPressed: cursor.exhausted
                  ? null
                  : () => setState(() {
                      final batch = cursor.next();
                      if (batch != null) history.add(batch);
                    }),
              child: Text(
                cursor.exhausted ? 'Iterator exhausted' : 'Next batch',
              ),
            ),
            OutlinedButton(
              onPressed: () => setState(reset),
              child: const Text('Reset iterator'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (history.isEmpty) const Text('No batch emitted yet.'),
        for (var i = 0; i < history.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'Batch ${i + 1}: [${history[i].join(', ')}]',
              style: const TextStyle(fontWeight: FontWeight.w700, height: 1.7),
            ),
          ),
        const SizedBox(height: 12),
        const Text(
          'StopIteration একটি normal completion signal। Last batch ছোট রেখে সব records process করা যায়; drop করলে কত বাদ গেল report করুন। Stream chunk ছোট হলেই পুরো program bounded-memory হয় না—history, concat বা list(generator) সব rows জমাতে পারে।',
          style: TextStyle(
            fontFamily: 'NotoSansBengali',
            fontSize: 12,
            height: 2,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'This small visualization retains history for inspection. It simulates iterator state; it is not a streaming-memory benchmark or Python execution. Chapter workflow reads real Adult CSV chunks locally.',
          style: TextStyle(fontSize: 10, height: 1.8),
        ),
      ],
    ),
  );
}
