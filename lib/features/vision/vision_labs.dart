import 'dart:math';

import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import 'vision_model.dart';

const _gap = SizedBox(height: 16),
    _bn = TextStyle(fontFamily: 'NotoSansBengali', height: 1.85),
    _title = TextStyle(fontSize: 24, fontWeight: FontWeight.w800);
Color _accent(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? lime : forest;
Widget _asset(Future<VisionAssets> f, Widget Function(VisionAssets) build) =>
    FutureBuilder<VisionAssets>(
      future: f,
      builder: (c, s) {
        if (s.hasError) {
          return const Panel(
            child: Text(
              'Bundled image evidence could not be read. Reopen the lab.',
            ),
          );
        }
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        return build(s.data!);
      },
    );
Widget _source() => const Text(
  'UCI Optical Recognition of Handwritten Digits · Alpaydin & Kaynak (1998) · CC BY4.0 · sklearn-packaged 1797 historical test images repurposed for educational split। Writer IDs নেই; writer-independent বা original benchmark claim নয়। App Dart math/stored CPU PyTorch evidence ব্যবহার করে, Python train করে না।',
  style: _bn,
);
Widget _imageGrid(
  List<List<double>> x, {
  Set<int> highlighted = const {},
  void Function(int)? select,
  bool signed = false,
}) {
  final scale = max(1e-12, x.expand((r) => r).map((v) => v.abs()).reduce(max));
  return LayoutBuilder(
    builder: (c, box) {
      final side = min(320.0, box.maxWidth), width = side / x.first.length;
      return SizedBox(
        width: side,
        child: Column(
          children: [
            for (var i = 0; i < x.length; i++)
              Row(
                children: [
                  for (var j = 0; j < x[i].length; j++)
                    GestureDetector(
                      onTap: select == null
                          ? null
                          : () => select(i * x[i].length + j),
                      child: Semantics(
                        button: select != null,
                        label:
                            'Row $i column $j value ${x[i][j].toStringAsFixed(4)}',
                        child: Container(
                          width: width,
                          height: width,
                          decoration: BoxDecoration(
                            color: signed
                                ? (x[i][j] < 0
                                      ? Color.lerp(
                                          Colors.white,
                                          const Color(0xffad4d42),
                                          x[i][j].abs() / scale,
                                        )
                                      : Color.lerp(
                                          Colors.white,
                                          const Color(0xff176b4b),
                                          x[i][j].abs() / scale,
                                        ))
                                : Color.lerp(
                                    const Color(0xff121b17),
                                    const Color(0xffd9edaa),
                                    x[i][j].clamp(0, 1),
                                  ),
                            border: Border.all(
                              color: highlighted.contains(i * x[i].length + j)
                                  ? const Color(0xffffac42)
                                  : Colors.black.withValues(alpha: .12),
                              width: highlighted.contains(i * x[i].length + j)
                                  ? 2.5
                                  : .4,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: width >= 34
                              ? Text(
                                  x[i][j].toStringAsFixed(1),
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: signed
                                        ? Colors.black
                                        : (x[i][j] > .5
                                              ? Colors.black
                                              : Colors.white),
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      );
    },
  );
}

Widget _samplePicker(
  VisionAssets a,
  int sample,
  void Function(int) change,
  String key,
) => DropdownButtonFormField<int>(
  key: ValueKey('$key-$sample'),
  initialValue: sample,
  isExpanded: true,
  decoration: const InputDecoration(labelText: 'Actual target-training image'),
  items: [
    for (var i = 0; i < 3; i++)
      DropdownMenuItem(
        value: i,
        child: Text(
          'Digit ${a.samples[i].digit} · source #${a.samples[i].sourceRow}',
        ),
      ),
  ],
  onChanged: (v) {
    if (v != null) change(v);
  },
);

class ConvolutionLab extends StatefulWidget {
  const ConvolutionLab({super.key});
  @override
  State<ConvolutionLab> createState() => _ConvolutionLabState();
}

class _ConvolutionLabState extends State<ConvolutionLab> {
  final data = VisionAssets.load();
  int sample = 0, position = 0;
  String kernel = 'sobel';
  bool padded = false;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final image = a.samples[sample].normalized,
        k = a.kernels[kernel]!,
        stride = padded ? 2 : 1,
        padding = padded ? 1 : 0,
        out = CorrelationResult.compute(
          image,
          k,
          stride: stride,
          padding: padding,
        ).output,
        row = position ~/ out.first.length,
        col = position % out.first.length;
    final cells = <int>{};
    final terms = <String>[];
    var total = 0.0;
    for (var i = 0; i < 3; i++) {
      for (var j = 0; j < 3; j++) {
        final y = row * stride - padding + i,
            x = col * stride - padding + j,
            value = y >= 0 && y < 8 && x >= 0 && x < 8 ? image[y][x] : 0.0;
        if (y >= 0 && y < 8 && x >= 0 && x < 8) cells.add(y * 8 + x);
        total += value * k[i][j];
        terms.add(
          '${value.toStringAsFixed(3)} × ${k[i][j].toStringAsFixed(3)}',
        );
      }
    }
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'DEEP LEARNING & RL · CHAPTER 04 · CONVOLUTION WINDOW',
            icon: Icons.grid_on_outlined,
          ),
          _gap,
          const Text(
            'Slide the kernel. Account for every value.',
            style: _title,
          ),
          _gap,
          const Text(
            'বাস্তব 8×8 Digit Image-এর Pixel মান 16 দিয়ে ভাগ করা হয়েছে। এখানে Sobel আর Average Kernel দিয়ে Cross-correlation করা হয়। PyTorch Conv2d Kernel উল্টায় না। Input-এ কমলা রঙে বাছাই করা Output Window দেখা যায়। Padding-এর জায়গাগুলোর মান শূন্য। এই Filter-গুলোর Weight আগে থেকে দেওয়া। CNN এগুলো শেখেনি। Output Cell বেছে তার হিসাব দেখুন।',
            style: _bn,
          ),
          _gap,
          _samplePicker(
            a,
            sample,
            (v) => setState(() {
              sample = v;
              position = 0;
            }),
            'conv-image',
          ),
          _gap,
          DropdownButtonFormField<String>(
            key: ValueKey('conv-kernel-$kernel'),
            initialValue: kernel,
            decoration: const InputDecoration(labelText: 'Declared 3×3 kernel'),
            items: const [
              DropdownMenuItem(
                value: 'sobel',
                child: Text('Sobel horizontal difference'),
              ),
              DropdownMenuItem(
                value: 'average',
                child: Text('Mean filter · 1/9'),
              ),
            ],
            onChanged: (v) {
              if (v != null) setState(() => kernel = v);
            },
          ),
          _gap,
          SwitchListTile(
            key: const Key('conv-padding'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Stride 2 + zero padding 1'),
            value: padded,
            onChanged: (v) => setState(() {
              padded = v;
              position = 0;
            }),
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Tag('Output shape: [${out.length}, ${out.first.length}]'),
              Tag('Stride: $stride · padding: $padding'),
              Tag('Selected output: [$row, $col]'),
            ],
          ),
          _gap,
          _imageGrid(image, highlighted: cells),
          _gap,
          const Text('Output · tap a cell (green positive / red negative)'),
          const SizedBox(height: 8),
          _imageGrid(
            out,
            signed: true,
            highlighted: {position},
            select: (v) => setState(() => position = v),
          ),
          _gap,
          Text(
            'Kernel: ${k.map((r) => r.map((v) => v.toStringAsFixed(3)).join(', ')).join(' | ')}\n${terms.join(' + ')}\nWindow sum: ${total.toStringAsFixed(6)}\nReference output: ${out[row][col].toStringAsFixed(6)}',
            style: const TextStyle(height: 1.9),
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                key: const Key('conv-stride'),
                onPressed: () => setState(() {
                  padded = true;
                  position = 0;
                }),
                child: const Text('Inspect stride 2'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  sample = 0;
                  kernel = 'sobel';
                  padded = false;
                  position = 0;
                }),
                child: const Text('Reset convolution'),
              ),
            ],
          ),
          _gap,
          _source(),
        ],
      ),
    );
  });
}

class PoolingLab extends StatefulWidget {
  const PoolingLab({super.key});
  @override
  State<PoolingLab> createState() => _PoolingLabState();
}

class _PoolingLabState extends State<PoolingLab> {
  final data = VisionAssets.load();
  int sample = 0;
  bool shifted = false, average = false;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final original = a.samples[sample].normalized,
        image = shifted ? shiftRight(original) : original,
        result = pool2(image, average: average);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'DEEP LEARNING & RL · CHAPTER 04 · POOLING & TRANSLATION',
            icon: Icons.view_module_outlined,
          ),
          _gap,
          const Text(
            'Downsample the evidence, inspect the loss.',
            style: _title,
          ),
          _gap,
          const Text(
            'বাস্তব ছবিতে 2×2 Window আর Stride 2 দিয়ে Max Pooling ও Average Pooling-এর হিসাব দেখুন। এক Pixel ডানে সরালে ফাঁকা জায়গায় 0 বসে। torch.roll-এর মতো অন্য পাশ থেকে Pixel ফিরে আসে না। Pooling output পরিবর্তন হতে পারে—exact translation invariance নয়। Transformation label-preserving কি না task-specific; main training-এ augmentation নেই।',
            style: _bn,
          ),
          _gap,
          _samplePicker(
            a,
            sample,
            (v) => setState(() => sample = v),
            'pool-image',
          ),
          _gap,
          SwitchListTile(
            key: const Key('pool-average'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Average pooling instead of max'),
            value: average,
            onChanged: (v) => setState(() => average = v),
          ),
          SwitchListTile(
            key: const Key('pool-shift'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Shift right 1 pixel · zero fill'),
            value: shifted,
            onChanged: (v) => setState(() => shifted = v),
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Tag(average ? 'Pooling: average' : 'Pooling: max'),
              Tag(shifted ? 'Shift: right 1' : 'Shift: none'),
              const Tag('8×8 → 4×4'),
            ],
          ),
          _gap,
          _imageGrid(image),
          _gap,
          const Text('Pooled values'),
          const SizedBox(height: 8),
          _imageGrid(result),
          _gap,
          Text(
            'Top-left window: [${image[0][0]}, ${image[0][1]}, ${image[1][0]}, ${image[1][1]}]\nPooled [0,0]: ${result[0][0].toStringAsFixed(6)}\nInput pixels: 64 · output values: 16',
            style: const TextStyle(height: 1.9),
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                key: const Key('pool-inspect-shift'),
                onPressed: () => setState(() => shifted = true),
                child: const Text('Inspect one-pixel shift'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  sample = 0;
                  shifted = false;
                  average = false;
                }),
                child: const Text('Reset pooling'),
              ),
            ],
          ),
          _gap,
          _source(),
        ],
      ),
    );
  });
}

class TransferLab extends StatefulWidget {
  const TransferLab({super.key});
  @override
  State<TransferLab> createState() => _TransferLabState();
}

class _TransferLabState extends State<TransferLab> {
  final data = VisionAssets.load();
  int sample = 0;
  String branch = 'frozen';
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final p = a.branches[branch]!.predict(a.samples[sample].normalized);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'DEEP LEARNING & RL · CHAPTER 04 · LOCAL TRANSFER AUDIT',
            icon: Icons.swap_horiz_outlined,
          ),
          _gap,
          const Text('Reuse the features. Verify what changed.', style: _title),
          _gap,
          const Text(
            'Source Task-এ Digit 0–4, আর Target Task-এ Digit 5–9। Local source-pretrained CNN backbone ও same fresh target head থেকে frozen/fine-tune branches শুরু। এটি ImageNet weights নয়। CNN forward Dart-এ recompute হয়; app model train করে না। এখানে দেখানো তিনটি ছবি Target Training Data থেকে নেওয়া। এগুলো Unseen Data-র Prediction নয়।',
            style: _bn,
          ),
          _gap,
          _samplePicker(
            a,
            sample,
            (v) => setState(() => sample = v),
            'transfer-image',
          ),
          _gap,
          DropdownButtonFormField<String>(
            key: ValueKey('transfer-branch-$branch'),
            initialValue: branch,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Stored local model branch',
            ),
            items: const [
              DropdownMenuItem(
                value: 'initial',
                child: Text('Pretrained backbone + fresh head'),
              ),
              DropdownMenuItem(
                value: 'frozen',
                child: Text('Frozen backbone · trained head'),
              ),
              DropdownMenuItem(
                value: 'finetune',
                child: Text('Fine-tuned backbone + head'),
              ),
            ],
            onChanged: (v) {
              if (v != null) setState(() => branch = v);
            },
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Tag('Branch: $branch'),
              const Tag('Total parameters: 501'),
              Tag(
                branch == 'frozen'
                    ? 'Trainable: head 165'
                    : 'Trainable during target run: 501',
              ),
              Tag('Predicted digit: ${p.digit}'),
            ],
          ),
          _gap,
          _imageGrid(a.samples[sample].normalized),
          _gap,
          for (var i = 0; i < 5; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(width: 65, child: Text('Digit ${i + 5}')),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: p.probability[i],
                      minHeight: 8,
                      color: _accent(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 65,
                    child: Text(
                      '${(100 * p.probability[i]).toStringAsFixed(2)}%',
                    ),
                  ),
                ],
              ),
            ),
          _gap,
          Text(
            'Logits: [${p.logits.map((v) => v.toStringAsFixed(5)).join(', ')}]\nFeature tensor: [8,2,2] → 32 head inputs\nFrozen backbone max change: ${a.frozenChange}\nFine-tuned backbone max change: ${a.fineChange.toStringAsFixed(6)}',
            style: const TextStyle(height: 1.9),
          ),
          _gap,
          const Text(
            'requires_grad=False ও optimizer group exclusion দুটো audit করা হয়েছে। Frozen branch-এ backbone values unchanged; fine-tune-এ বদলেছে। BN থাকলে Buffer আর Mode কীভাবে সামলাবেন, সেটাও আলাদাভাবে ঠিক করতে হবে। Same-source diagnostic validation থেকে universal transfer benefit বা production OCR দাবি নয়।',
            style: _bn,
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                key: const Key('transfer-finetune'),
                onPressed: () => setState(() => branch = 'finetune'),
                child: const Text('Inspect fine-tuned branch'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  sample = 0;
                  branch = 'frozen';
                }),
                child: const Text('Reset transfer'),
              ),
            ],
          ),
          _gap,
          _source(),
        ],
      ),
    );
  });
}
