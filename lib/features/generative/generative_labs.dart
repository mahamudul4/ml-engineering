import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import 'generative_model.dart';

const _gap = SizedBox(height: 16),
    _bn = TextStyle(fontFamily: 'NotoSansBengali', height: 1.8),
    _title = TextStyle(fontSize: 24, fontWeight: FontWeight.w800);
Widget _asset(
  Future<GenerativeAssets> future,
  Widget Function(GenerativeAssets) body,
) => FutureBuilder<GenerativeAssets>(
  future: future,
  builder: (c, s) {
    if (s.hasError) {
      return const Panel(
        child: Text('Bundled generative evidence could not be read.'),
      );
    }
    if (!s.hasData) return const Center(child: CircularProgressIndicator());
    return body(s.data!);
  },
);
const _source = Text(
  'বাস্তব UCI Digits · Alpaydin & Kaynak (1998), CC BY 4.0। Chapter 18-এর একই 1438 fit / 359 diagnostic rows; writer-independent বা নতুন blind test নয়। Labels training-এ নেই। Saved float64 weights দিয়ে Dart forward চলে; Python training local। 8×8 output-কে বড় image model-এর quality benchmark ভাববেন না।',
  style: _bn,
);
String _n(num v) => v.toStringAsFixed(4);

class DigitPixels extends StatelessWidget {
  final List<double> pixels;
  final String label;
  const DigitPixels({super.key, required this.pixels, required this.label});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 144,
    child: Column(
      children: [
        Semantics(
          label: label,
          child: AspectRatio(
            aspectRatio: 1,
            child: CustomPaint(painter: _Pixels(pixels)),
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
  final List<double> pixels;
  _Pixels(this.pixels);
  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 64; i++) {
      final value = (pixels[i].clamp(0, 1) * 255).round();
      canvas.drawRect(
        Rect.fromLTWH(
          (i % 8) * size.width / 8,
          (i ~/ 8) * size.height / 8,
          size.width / 8 + .1,
          size.height / 8 + .1,
        ),
        Paint()..color = Color.fromARGB(255, value, value, value),
      );
    }
  }

  @override
  bool shouldRepaint(_Pixels old) => old.pixels != pixels;
}

class VaeObjectiveLab extends StatefulWidget {
  const VaeObjectiveLab({super.key});
  @override
  State<VaeObjectiveLab> createState() => _VaeObjectiveLabState();
}

class _VaeObjectiveLabState extends State<VaeObjectiveLab> {
  final data = GenerativeAssets.load();
  double epsilon = 0, beta = 1;
  int image = 0;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final row = a.images[image];
    final x = GenerativeAssets.vector(row['pixels']);
    final (mu, lv) = a.encode(x);
    final z = reparameterize(mu, lv, [epsilon, -epsilon]);
    final logits = a.decodeLogits(z);
    final bce = reconstructionBCE(logits, x), kl = gaussianKL(mu, lv);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag('LLMS & GENAI · CHAPTER 08 · VAE OBJECTIVE', icon: Icons.blur_on),
          _gap,
          const Text('Encode uncertainty. Trace the objective.', style: _title),
          _gap,
          const Text(
            'Encoder থেকে μ ও log variance আসে। এখানে ε = [e, −e] একটি ঘোষিত controlled illustration; random sample বা Monte Carlo ELBO estimate নয়। β বদলালে শুধু বর্তমান Objective-এর হিসাব আবার হয়। Model আবার Train হয় না। β = 1 standard ELBO weighting; soft-target BCE grayscale likelihood নয়।',
            style: _bn,
          ),
          _gap,
          DropdownButtonFormField<int>(
            key: ValueKey('generative-image-$image'),
            initialValue: image,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Real diagnostic source image',
            ),
            items: [
              for (var i = 0; i < a.images.length; i++)
                DropdownMenuItem(
                  value: i,
                  child: Text(
                    'Digit ${a.images[i]['digit']} · source row ${a.images[i]['source_row_1based']}',
                  ),
                ),
            ],
            onChanged: (v) {
              if (v != null) setState(() => image = v);
            },
          ),
          _gap,
          Text(
            'μ: ${mu.map(_n).join(', ')} · log σ²: ${lv.map(_n).join(', ')}',
          ),
          _gap,
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              DigitPixels(
                pixels: x,
                label: 'Real source · digit ${row['digit']}',
              ),
              DigitPixels(
                pixels: logits.map(sigmoid).toList(),
                label: 'VAE decoder mean at z',
              ),
            ],
          ),
          _gap,
          Text('Epsilon control: ${epsilon.toStringAsFixed(1)}'),
          Slider(
            value: epsilon,
            min: -2,
            max: 2,
            divisions: 16,
            label: _n(epsilon),
            onChanged: (v) => setState(() => epsilon = v),
          ),
          Text('Beta: ${beta.toStringAsFixed(1)}'),
          Slider(
            value: beta,
            min: 0,
            max: 4,
            divisions: 16,
            label: _n(beta),
            onChanged: (v) => setState(() => beta = v),
          ),
          Text('BCE sum: ${_n(bce)} · KL sum: ${_n(kl)}'),
          Text('Weighted objective: ${_n(bce + beta * kl)}'),
          _gap,
          FilledButton.tonal(
            key: const Key('generative-epsilon'),
            onPressed: () => setState(() => epsilon = 1),
            child: const Text('Set epsilon to 1'),
          ),
          _gap,
          TextButton(
            onPressed: () => setState(() {
              epsilon = 0;
              beta = 1;
              image = 0;
            }),
            child: const Text('Reset VAE objective'),
          ),
          _gap,
          _source,
        ],
      ),
    );
  });
}

class LatentSpaceLab extends StatefulWidget {
  const LatentSpaceLab({super.key});
  @override
  State<LatentSpaceLab> createState() => _LatentSpaceLabState();
}

class _LatentSpaceLabState extends State<LatentSpaceLab> {
  final data = GenerativeAssets.load();
  double x = 0, y = 0;
  bool gan = false;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final z = [x, y];
    final output = gan ? a.generate(z) : a.decode(z);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag('LLMS & GENAI · CHAPTER 08 · LATENT SPACE', icon: Icons.grid_view),
          _gap,
          const Text(
            'Move in latent space. Inspect real outputs.',
            style: _title,
          ),
          _gap,
          const Text(
            'দুই dimension-এর latent coordinate বদলালে saved decoder বা generator-এর সম্পূর্ণ forward আবার চলে। এই grid একটি controlled coordinate sweep; Gaussian prior-এর representative random batch নয়। Semantic disentanglement বা smooth quality improvement নিশ্চিত নয়।',
            style: _bn,
          ),
          _gap,
          Tag(gan ? 'Decoder: GAN' : 'Decoder: VAE'),
          _gap,
          Text('z₁ = ${_n(x)}'),
          Slider(
            value: x,
            min: -3,
            max: 3,
            divisions: 24,
            onChanged: (v) => setState(() => x = v),
          ),
          Text('z₂ = ${_n(y)}'),
          Slider(
            value: y,
            min: -3,
            max: 3,
            divisions: 24,
            onChanged: (v) => setState(() => y = v),
          ),
          _gap,
          DigitPixels(
            pixels: output,
            label:
                'Actual ${gan ? 'GAN' : 'VAE'} forward · z = (${_n(x)}, ${_n(y)})',
          ),
          _gap,
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final point in [(-2.0, -2.0), (0.0, 0.0), (2.0, 2.0)])
                InkWell(
                  onTap: () => setState(() {
                    x = point.$1;
                    y = point.$2;
                  }),
                  child: DigitPixels(
                    pixels: gan
                        ? a.generate([point.$1, point.$2])
                        : a.decode([point.$1, point.$2]),
                    label: 'z = (${point.$1}, ${point.$2})',
                  ),
                ),
            ],
          ),
          _gap,
          FilledButton.tonal(
            key: const Key('generative-decoder'),
            onPressed: () => setState(() => gan = !gan),
            child: const Text('Switch VAE / GAN'),
          ),
          _gap,
          TextButton(
            onPressed: () => setState(() {
              x = 0;
              y = 0;
              gan = false;
            }),
            child: const Text('Reset latent space'),
          ),
          _gap,
          _source,
        ],
      ),
    );
  });
}

class GanGameLab extends StatefulWidget {
  const GanGameLab({super.key});
  @override
  State<GanGameLab> createState() => _GanGameLabState();
}

class _GanGameLabState extends State<GanGameLab> {
  final data = GenerativeAssets.load();
  int sample = 0;
  double logit = 0;
  bool details = false;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final row = a.samples[sample];
    final z = GenerativeAssets.vector(row['z']);
    final fake = a.generate(z);
    final score = a.discriminate(fake);
    final non = softplus(-logit), minimax = -softplus(logit);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'LLMS & GENAI · CHAPTER 08 · ADVERSARIAL GAME',
            icon: Icons.compare_arrows,
          ),
          _gap,
          const Text(
            'Two players. Audit gradients and diversity.',
            style: _title,
          ),
          _gap,
          const Text(
            'বাঁয়ে fixed seed 271-এর 16টি Gaussian draw-এর একটি genuine GAN output, cherry-picked best নয়। পাশে একই z-তে VAE mean। D(fake) শুধু এই training game-এর score, handwriting quality probability নয়। নিচের logit control আলাদা mathematical illustration; trained D পরিবর্তন করে না।',
            style: _bn,
          ),
          _gap,
          Text('Frozen sample: ${sample + 1} / 16'),
          Slider(
            value: sample.toDouble(),
            min: 0,
            max: 15,
            divisions: 15,
            onChanged: (v) => setState(() => sample = v.round()),
          ),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              DigitPixels(pixels: fake, label: 'Actual GAN sample'),
              DigitPixels(pixels: a.decode(z), label: 'VAE mean · same z'),
            ],
          ),
          _gap,
          Text('Frozen D(fake): ${_n(score)}'),
          Text('Nearest training pixel MSE: ${_n(row['nearest_mse'])}'),
          Text('Nearest source row: ${row['nearest_train_row_1based']}'),
          _gap,
          Text('Illustration logit: ${logit.toStringAsFixed(1)}'),
          Slider(
            value: logit,
            min: -10,
            max: 10,
            divisions: 40,
            onChanged: (v) => setState(() => logit = v),
          ),
          Text('D = ${_n(sigmoid(logit))} · non-saturating G loss ${_n(non)}'),
          Text('Minimax G loss ${_n(minimax)}'),
          Text(
            'dL/da: non-saturating ${_n(sigmoid(logit) - 1)} · minimax ${_n(-sigmoid(logit))}',
          ),
          _gap,
          const Text(
            'D(fake) ≈ 0 হলে minimax gradient ছোট হয়; non-saturating loss stronger signal দেয়। Generator output একই রকম হলে low loss দিয়ে diversity উদ্ধার হয় না। Nearest-pixel distance বড়/ছোট হওয়া quality, originality বা privacy certificate নয়।',
            style: _bn,
          ),
          _gap,
          FilledButton.tonal(
            key: const Key('generative-logit'),
            onPressed: () => setState(() => logit = -8),
            child: const Text('Inspect saturation'),
          ),
          _gap,
          FilledButton.tonal(
            key: const Key('generative-history'),
            onPressed: () => setState(() => details = !details),
            child: const Text('Show / hide training trace'),
          ),
          Text(details ? 'Trace: visible' : 'Trace: hidden'),
          if (details) ...[
            for (final key in ['vae_history', 'gan_history']) ...[
              _gap,
              Text(key),
              for (final r in (a.data[key] as List).where(
                (dynamic r) => [1, 20, 40, 60, 80].contains(r['epoch']),
              ))
                Text(r.toString()),
            ],
            _gap,
            Text(
              'Diagnostic VAE MSE: ${_n(a.report['vae_diagnostic']['mse'])} · train-mean baseline: ${_n(a.report['train_mean_baseline_mse'])}',
            ),
          ],
          _gap,
          TextButton(
            onPressed: () => setState(() {
              sample = 0;
              logit = 0;
              details = false;
            }),
            child: const Text('Reset adversarial game'),
          ),
          _gap,
          _source,
        ],
      ),
    );
  });
}
