import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import 'diffusion_model.dart';

const _gap = SizedBox(height: 16),
    _bn = TextStyle(fontFamily: 'NotoSansBengali', height: 1.8),
    _title = TextStyle(fontSize: 24, fontWeight: FontWeight.w800);
const _source = Text(
  'বাস্তব UCI Digits · Alpaydin & Kaynak (1998), CC BY 4.0। আগের 1438 fit / 359 observed diagnostic rows; নতুন blind test বা writer-independent benchmark নয়। Tiny CPU float64 models; saved weights দিয়ে offline Dart forward। Class-name lookup baseline natural-language encoder, CLIP বা zero-shot transfer নয়। Source labels থেকে names দেওয়া; observed image captions নেই।',
  style: _bn,
);
String _n(num n) => n != 0 && n.abs() < .001
    ? n.toStringAsExponential(3)
    : n.toStringAsFixed(4);
Widget _asset(
  Future<DiffusionAssets> f,
  Widget Function(DiffusionAssets) body,
) => FutureBuilder<DiffusionAssets>(
  future: f,
  builder: (c, s) {
    if (s.hasError) {
      return const Panel(
        child: Text('Bundled diffusion evidence could not be read.'),
      );
    }
    if (!s.hasData) {
      return const Center(child: CircularProgressIndicator());
    }
    return body(s.data!);
  },
);

class DiffusionPixels extends StatelessWidget {
  final List<double> values;
  final String label;
  final bool signed;
  const DiffusionPixels({
    super.key,
    required this.values,
    required this.label,
    this.signed = true,
  });
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 144,
    child: Column(
      children: [
        Semantics(
          label: label,
          child: AspectRatio(
            aspectRatio: 1,
            child: CustomPaint(painter: _Pixels(values, signed)),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    ),
  );
}

class _Pixels extends CustomPainter {
  final List<double> values;
  final bool signed;
  _Pixels(this.values, this.signed);
  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 64; i++) {
      final value =
          ((signed ? (values[i] + 1) / 2 : values[i]).clamp(0, 1) * 255)
              .round();
      canvas.drawRect(
        Rect.fromLTWH(
          i % 8 * size.width / 8,
          i ~/ 8 * size.height / 8,
          size.width / 8 + .1,
          size.height / 8 + .1,
        ),
        Paint()..color = Color.fromARGB(255, value, value, value),
      );
    }
  }

  @override
  bool shouldRepaint(_Pixels old) =>
      old.values != values || old.signed != signed;
}

Widget _picker(
  int image,
  DiffusionAssets a,
  void Function(int) change,
  String prefix,
) => DropdownButtonFormField<int>(
  key: ValueKey('$prefix-$image'),
  initialValue: image,
  isExpanded: true,
  decoration: const InputDecoration(labelText: 'Real diagnostic source image'),
  items: [
    for (var i = 0; i < 10; i++)
      DropdownMenuItem(
        value: i,
        child: Text(
          'Digit $i · source row ${a.samples[i]['source_row_1based']}',
        ),
      ),
  ],
  onChanged: (v) {
    if (v != null) change(v);
  },
);

class ForwardNoiseLab extends StatefulWidget {
  const ForwardNoiseLab({super.key});
  @override
  State<ForwardNoiseLab> createState() => _ForwardNoiseLabState();
}

class _ForwardNoiseLabState extends State<ForwardNoiseLab> {
  final data = DiffusionAssets.load();
  int image = 0, t = 8;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final r = a.samples[image];
    final clean = DiffusionAssets.vector(r['unit_pixels'])
            .map((v) => 2 * v - 1)
            .toList(),
        eps = DiffusionAssets.vector(r['epsilon']);
    final bar = a.alphaBar[t];
    final noisy = noiseForward(clean, eps, bar);
    final estimate = t == 0
        ? clean
        : cleanEstimate(noisy, a.predict(noisy, t, image), bar);
    final snr = t == 0 ? 'infinite' : _n(bar / (1 - bar));
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag('LLMS & GENAI · CHAPTER 09 · FORWARD NOISE', icon: Icons.grain),
          _gap,
          const Text('Add noise. Track the signal.', style: _title),
          _gap,
          const Text(
            'একই fixed Gaussian ε দিয়ে বিভিন্ন t-এর marginal corruption তুলনা করি; এই controlled coupling Markov forward trajectory নয়। t=0 clean boundary; denoiser train হয়েছে t=1…32। Noise values unbounded, কিন্তু শুধু display [-1,1] clip করে। Predicted clean image আলাদা one-step estimate, reverse sampling নয়।',
            style: _bn,
          ),
          _gap,
          _picker(image, a, (v) => setState(() => image = v), 'noise-image'),
          _gap,
          Text('Timestep: $t / 32'),
          Slider(
            value: t.toDouble(),
            min: 0,
            max: 32,
            divisions: 32,
            onChanged: (v) => setState(() => t = v.round()),
          ),
          Text('Alpha bar: ${_n(bar)} · SNR: $snr'),
          Text(
            'Raw values outside [-1,1]: ${noisy.where((v) => v.abs() > 1).length} / 64',
          ),
          for (final metric in (a.report['diagnostic'] as List).where(
            (dynamic m) => m['t'] == t,
          )) ...[
            _gap,
            Text('359-row diagnostic noise MSE: ${_n(metric['noise_mse'])}'),
            Text(
              'Identity noise baseline: ${(metric['identity_noise_baseline'] as num).toStringAsExponential(3)}',
            ),
            Text('Zero noise baseline: ${_n(metric['zero_noise_baseline'])}'),
            Text(
              'Clipped clean unit MSE: ${_n(metric['clipped_x0_unit_mse'])}',
            ),
            const Text(
              'Known source-class condition দিয়ে one-step diagnostic। Terminal noise-এ identity baseline এই trained model-এর চেয়ে ভালো; noise loss বা clipping generation quality নিশ্চিত করে না।',
              style: _bn,
            ),
          ],
          _gap,
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              DiffusionPixels(
                values: clean,
                label: 'Real source · digit $image',
              ),
              DiffusionPixels(values: noisy, label: 'Noisy x at t = $t'),
              DiffusionPixels(
                values: estimate,
                label: 'Clipped clean estimate',
              ),
            ],
          ),
          _gap,
          FilledButton.tonal(
            key: const Key('diffusion-noise'),
            onPressed: () => setState(() => t = 32),
            child: const Text('Inspect terminal noise'),
          ),
          _gap,
          TextButton(
            onPressed: () => setState(() {
              image = 0;
              t = 8;
            }),
            child: const Text('Reset forward noise'),
          ),
          _gap,
          _source,
        ],
      ),
    );
  });
}

class ReverseSamplingLab extends StatefulWidget {
  const ReverseSamplingLab({super.key});
  @override
  State<ReverseSamplingLab> createState() => _ReverseSamplingLabState();
}

class _ReverseSamplingLabState extends State<ReverseSamplingLab> {
  final data = DiffusionAssets.load();
  int label = 3, steps = 8, frame = 8;
  double guidance = 1;
  List<DiffusionFrame>? trace;
  void _change(VoidCallback change) => setState(() {
    change();
    trace = null;
    frame = steps;
  });
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final frames = trace ??= a.sample(
      label: label,
      guidance: guidance,
      steps: steps,
    );
    final f = frames[frame];
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag('LLMS & GENAI · CHAPTER 09 · REVERSE SAMPLING', icon: Icons.auto_awesome),
          _gap,
          const Text('Denoise step by step. Inspect guidance.', style: _title),
          _gap,
          const Text(
            'Fixed seed 281-এর একই initial Gaussian noise থেকে সম্পূর্ণ Dart DDIM forward চলে। η=0; x₀ estimate clip হয়, direction term-এ original guided ε থাকে। Requested digit obey করা বা সুন্দর sample নিশ্চিত নয়। Guidance 0=null, 1=conditional; 2 stronger extrapolation। এটি class-conditioned MLP, text-to-image model নয়।',
            style: _bn,
          ),
          _gap,
          DropdownButtonFormField<int>(
            key: ValueKey('sample-label-$label'),
            initialValue: label,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Requested known digit class',
            ),
            items: [
              for (var i = 0; i < 10; i++)
                DropdownMenuItem(value: i, child: Text('Digit $i')),
            ],
            onChanged: (v) {
              if (v != null) _change(() => label = v);
            },
          ),
          _gap,
          Tag('Guidance: ${guidance.toStringAsFixed(1)}'),
          _gap,
          Tag('Steps: $steps'),
          _gap,
          Text('Frame: $frame / $steps · t = ${f.t}'),
          Slider(
            value: frame.toDouble(),
            min: 0,
            max: steps.toDouble(),
            divisions: steps,
            onChanged: (v) => setState(() => frame = v.round()),
          ),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              DiffusionPixels(
                values: frames.first.pixels,
                label: 'Initial Gaussian x₃₂',
              ),
              DiffusionPixels(
                values: f.pixels,
                label: 'Actual DDIM frame · t = ${f.t}',
              ),
              DiffusionPixels(
                values: frames.last.pixels,
                label: 'Final sample · requested $label',
              ),
            ],
          ),
          _gap,
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.tonal(
                key: const Key('diffusion-guidance'),
                onPressed: () =>
                    _change(() => guidance = guidance == 1 ? 2 : 1),
                child: const Text('Switch guidance 1 / 2'),
              ),
              FilledButton.tonal(
                key: const Key('diffusion-steps'),
                onPressed: () => _change(() => steps = steps == 8 ? 32 : 8),
                child: const Text('Switch 8 / 32 steps'),
              ),
              OutlinedButton(
                onPressed: () => _change(() => guidance = 0),
                child: const Text('Use null condition'),
              ),
            ],
          ),
          _gap,
          Text(
            'Denoiser evaluations: ${steps * 2} (conditional + null, no guidance shortcut)',
          ),
          _gap,
          TextButton(
            onPressed: () => _change(() {
              label = 3;
              steps = 8;
              guidance = 1;
            }),
            child: const Text('Reset reverse sampling'),
          ),
          _gap,
          _source,
        ],
      ),
    );
  });
}

class MultimodalAlignmentLab extends StatefulWidget {
  const MultimodalAlignmentLab({super.key});
  @override
  State<MultimodalAlignmentLab> createState() => _MultimodalAlignmentLabState();
}

class _MultimodalAlignmentLabState extends State<MultimodalAlignmentLab> {
  final data = DiffusionAssets.load();
  int image = 0;
  double tau = .1;
  bool audit = false;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final r = a.samples[image],
        pixels = DiffusionAssets.vector(a.samples[image]['unit_pixels']);
    final scores = a.similarities(pixels), p = probabilities(scores, tau);
    final best = scores.indexOf(scores.reduce((x, y) => x > y ? x : y));
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'LLMS & GENAI · CHAPTER 09 · IMAGE / LABEL ALIGNMENT',
            icon: Icons.compare_arrows,
          ),
          _gap,
          const Text(
            'Align representations. Audit the shortcut.',
            style: _title,
          ),
          _gap,
          const Text(
            'Image encoder ও learned class-name lookup vectors-এর cosine similarity। Names source digit labels-এর authored aliases; caption observations বা text encoder নেই। তাই এটি supervised known-class retrieval proxy, CLIP বা language understanding নয়। Temperature confidence বদলায়; positive temperature-এ ranking একই থাকে।',
            style: _bn,
          ),
          _gap,
          _picker(
            image,
            a,
            (v) => setState(() => image = v),
            'alignment-image',
          ),
          _gap,
          DiffusionPixels(
            values: pixels,
            label: 'Real digit ${r['digit']} · row ${r['source_row_1based']}',
            signed: false,
          ),
          _gap,
          Text('Temperature: ${tau.toStringAsFixed(2)}'),
          Slider(
            value: tau,
            min: .05,
            max: 1,
            divisions: 19,
            onChanged: (v) => setState(() => tau = v),
          ),
          Text('Top name: ${a.names[best]} · source label: $image'),
          _gap,
          for (var i = 0; i < 10; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${a.names[i]} · cosine ${_n(scores[i])} · p ${_n(p[i])}',
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(value: p[i], minHeight: 6),
                ],
              ),
            ),
          _gap,
          FilledButton.tonal(
            key: const Key('diffusion-temperature'),
            onPressed: () => setState(() => tau = .5),
            child: const Text('Inspect warmer scores'),
          ),
          _gap,
          FilledButton.tonal(
            key: const Key('diffusion-audit'),
            onPressed: () => setState(() => audit = !audit),
            child: const Text('Show / hide scope audit'),
          ),
          Text(audit ? 'Scope audit: visible' : 'Scope audit: hidden'),
          if (audit) ...[
            _gap,
            Text(
              'Observed diagnostic rows: ${a.report['diagnostic_count']} · known-name top1 ${_n(a.report['alignment_top1'])}',
            ),
            Text(
              'Diagnostic majority baseline: ${_n(a.report['majority_baseline'])}',
            ),
            const Text(
              'Same-class repeated pairs are multiple positives; symmetric masked log-sum-exp objective uses source labels। No natural captions, unseen classes, free-form prompt encoder or zero-shot test। Probability here is a temperature softmax over ten names, not calibrated truth confidence।',
              style: _bn,
            ),
          ],
          _gap,
          TextButton(
            onPressed: () => setState(() {
              image = 0;
              tau = .1;
              audit = false;
            }),
            child: const Text('Reset alignment audit'),
          ),
          _gap,
          _source,
        ],
      ),
    );
  });
}
