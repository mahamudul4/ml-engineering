import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import 'llm_model.dart';

const _gap = SizedBox(height: 16),
    _bn = TextStyle(fontFamily: 'NotoSansBengali', height: 1.85),
    _title = TextStyle(fontSize: 24, fontWeight: FontWeight.w800);
Widget _asset(
  Future<LLMAssets> f,
  Widget Function(LLMAssets) build,
) => FutureBuilder<LLMAssets>(
  future: f,
  builder: (c, s) {
    if (s.hasError) {
      return const Panel(
        child: Text(
          'Bundled language-model evidence could not be read. Reopen the lab.',
        ),
      );
    }
    if (!s.hasData) {
      return const Center(child: CircularProgressIndicator());
    }
    return build(s.data!);
  },
);
Widget _source() => const Text(
  'Alice’s Adventures in Wonderland · Lewis Carroll · Project Gutenberg ebook11। Original source/notices bundled; public domain in the USA। Empirical corpus English; Bangla explanations do not imply Bangla model competence। This5019-parameter decoder is a mechanics model,not a large pretrained LLM। App training নয়,Dart forward চালায়।',
  style: _bn,
);
String _vector(List<double> x) =>
    '[${x.map((v) => v.toStringAsFixed(4)).join(', ')}]';
String _token(int id) => id == lmEos
    ? '<EOS>'
    : id == lmBos
    ? '<BOS>'
    : id == lmPad
    ? '<PAD>'
    : id == 32
    ? 'space'
    : id == 10
    ? 'newline'
    : id >= 33 && id <= 126
    ? String.fromCharCode(id)
    : '0x${id.toRadixString(16).padLeft(2, '0').toUpperCase()}';
Widget _prefixPicker(
  LLMAssets a,
  int sample,
  void Function(int) change,
  String key,
) => DropdownButtonFormField<int>(
  key: ValueKey('$key-$sample'),
  initialValue: sample,
  isExpanded: true,
  decoration: const InputDecoration(labelText: 'Actual source prefix'),
  items: [
    for (var i = 0; i < 3; i++)
      DropdownMenuItem(
        value: i,
        child: Text(
          'Book chapter ${a.samples[i].sourceChapter} · ${a.samples[i].role}',
        ),
      ),
  ],
  onChanged: (v) {
    if (v != null) {
      change(v);
    }
  },
);

class TokenizerLab extends StatefulWidget {
  const TokenizerLab({super.key});
  @override
  State<TokenizerLab> createState() => _TokenizerLabState();
}

class _TokenizerLabState extends State<TokenizerLab> {
  final data = LLMAssets.load(), text = TextEditingController();
  bool bpe = false, initialized = false;
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    if (!initialized) {
      text.text = a.examples.first;
      initialized = true;
    }
    final bytes = utf8.encode(text.text),
        within = bytes.length <= 512,
        ids = within ? a.tokenizer.encode(text.text, bpe: bpe) : <int>[];
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'LLMS & GENAI · CHAPTER 01 · TOKENIZATION',
            icon: Icons.text_fields_outlined,
          ),
          _gap,
          const Text('Text is bytes. Tokens are a choice.', style: _title),
          _gap,
          const Text(
            'Actual source excerpt দিয়ে শুরু। Unicode code points,UTF8 bytes এবং tokenizer IDs এক জিনিস নয়। Byte mode neural model-এর tokenizer; BPE mode আলাদা16-merge demonstration,শুধু fit chapters-এর bounded snippets থেকে শেখা। BPE IDs model-এ পাঠানো হয় না।',
            style: _bn,
          ),
          _gap,
          TextField(
            key: const Key('llm-token-text'),
            controller: text,
            maxLines: 3,
            maxLength: 128,
            decoration: const InputDecoration(
              labelText: 'Inspect text · edit to try Unicode',
              helperText:
                  'Up to512 UTF8 bytes; source default is actual book text',
            ),
            onChanged: (_) => setState(() {}),
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Tag(bpe ? 'Tokenizer: BPE' : 'Tokenizer: bytes'),
              Tag('Code points: ${text.text.runes.length}'),
              Tag('UTF8 bytes: ${bytes.length}'),
              Tag('Tokens: ${ids.length}'),
            ],
          ),
          _gap,
          if (!within)
            const Text('Use text within512 UTF8 bytes to inspect tokens.')
          else ...[
            Text(
              'Round-trip: ${a.tokenizer.decode(ids) == text.text ? 'exact' : 'mismatch'}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 8,
              children: [
                for (final id in ids.take(48))
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: forest.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$id\n${a.tokenizer.pieces[id]!.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
                      style: const TextStyle(fontSize: 11, height: 1.6),
                    ),
                  ),
              ],
            ),
            if (ids.length > 48)
              const Text(
                'First48 tokens shown; counts and round-trip use every token.',
              ),
          ],
          _gap,
          const Text(
            'প্রতিটি token fragment নিজে valid Unicode হওয়া বাধ্যতামূলক নয়। Pieces-এর bytes concatenate করে পুরো string decode করলে original text ফেরে। UTF16 code units/code points/grapheme clusters আলাদা counts। User-entered Bangla এখানে encoding demonstration,model training evidence নয়।',
            style: _bn,
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                key: const Key('llm-bpe'),
                onPressed: () => setState(() => bpe = true),
                child: const Text('Inspect learned BPE merges'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  bpe = false;
                  text.text = a.examples.first;
                }),
                child: const Text('Reset tokenizer'),
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

class LanguageObjectiveLab extends StatefulWidget {
  const LanguageObjectiveLab({super.key});
  @override
  State<LanguageObjectiveLab> createState() => _LanguageObjectiveLabState();
}

class _LanguageObjectiveLabState extends State<LanguageObjectiveLab> {
  final data = LLMAssets.load();
  int sample = 0, position = 0;
  bool causal = true;
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final s = a.samples[sample],
        trace = a.model.run(s.ids, causal: causal),
        p = lmDistribution(trace.matrices['logits']![position]),
        target = s.targets[position],
        nll = -math.log(p[target]);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'LLMS & GENAI · CHAPTER 01 · NEXT-TOKEN OBJECTIVE',
            icon: Icons.arrow_forward_outlined,
          ),
          _gap,
          const Text('Shift the target. Guard the prefix.', style: _title),
          _gap,
          const Text(
            'Input[BOS]+actual prefix bytes; labels এক position shifted,next actual source byte পর্যন্ত। প্রতিটি position কেবল নিজের allowed prefix দেখবে। Full-visibility intervention earlier positions-এ target-containing future inputs expose করে;lower loss হওয়া guarantee নয়,কারণ model causal training পেয়েছে।',
            style: _bn,
          ),
          _gap,
          _prefixPicker(
            a,
            sample,
            (v) => setState(() {
              sample = v;
              position = 0;
            }),
            'objective-source',
          ),
          _gap,
          Text(
            'Actual prefix: ${jsonEncode(s.text)}',
            style: const TextStyle(height: 1.8),
          ),
          _gap,
          SwitchListTile(
            key: const Key('llm-causal'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Causal prefix visibility'),
            value: causal,
            onChanged: (v) => setState(() => causal = v),
          ),
          Slider(
            key: const Key('llm-position'),
            value: position.toDouble(),
            min: 0,
            max: (s.ids.length - 1).toDouble(),
            divisions: s.ids.length - 1,
            label: '${position + 1}',
            onChanged: (v) => setState(() => position = v.round()),
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Tag(causal ? 'Visibility: causal' : 'Visibility: full'),
              Tag('Position: ${position + 1} / ${s.ids.length}'),
              const Tag('Vocabulary: 259'),
            ],
          ),
          _gap,
          Wrap(
            spacing: 5,
            runSpacing: 7,
            children: [
              for (var i = 0; i < s.ids.length; i++)
                Container(
                  width: 58,
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: (i == position ? Colors.deepOrange : forest)
                        .withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    '${i + 1}\n${_token(s.ids[i])}\n→${_token(s.targets[i])}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 10, height: 1.6),
                  ),
                ),
            ],
          ),
          _gap,
          Text(
            'Input ID: ${s.ids[position]} · ${_token(s.ids[position])}\nTarget ID: $target · ${_token(target)}\nP(target | allowed prefix): ${p[target].toStringAsFixed(7)}\nSelected target NLL: ${nll.toStringAsFixed(6)} nats\nNormalized hidden:\n${_vector(trace.matrices['normalized']![position])}',
            style: const TextStyle(height: 1.9),
          ),
          _gap,
          const Text(
            'Head1 key weights at selected position',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 90,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var j = 0; j < s.ids.length; j++)
                  Expanded(
                    child: Container(
                      height: 4 + trace.weights[0][position][j] * 86,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color:
                            (Theme.of(context).brightness == Brightness.dark
                                    ? lime
                                    : forest)
                                .withValues(
                                  alpha: j > position && causal ? .15 : .8,
                                ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _gap,
          const Text(
            'PAD256 labels ignored; BOS257 কখনো target নয়। ignore_index নিজে PAD/BOS output classes বাদ দেয় না—এই model সেগুলোর logits আলাদাভাবে block করে। EOS258 legal output। Single block-এর last query causal/full-এ একই keys দেখে;earlier query logits আলাদা হতে পারে।',
            style: _bn,
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                key: const Key('llm-unmask'),
                onPressed: () => setState(() => causal = false),
                child: const Text('Inspect full visibility'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  sample = 0;
                  position = 0;
                  causal = true;
                }),
                child: const Text('Reset objective'),
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

class LLMDecodingLab extends StatefulWidget {
  const LLMDecodingLab({super.key});
  @override
  State<LLMDecodingLab> createState() => _LLMDecodingLabState();
}

class _LLMDecodingLabState extends State<LLMDecodingLab> {
  final data = LLMAssets.load();
  int sample = 0, topK = 0;
  double temperature = 1, topP = 1, u = .3;
  String mode = 'greedy';
  @override
  Widget build(BuildContext context) => _asset(data, (a) {
    final s = a.samples[sample],
        trace = a.model.run(s.ids),
        p = lmDistribution(
          trace.matrices['logits']!.last,
          temperature: temperature,
          topK: topK,
          topP: topP,
        ),
        rank =
            [
              for (var i = 0; i < 259; i++)
                if (p[i] > 0) i,
            ]..sort((x, y) {
              final c = p[y].compareTo(p[x]);
              return c == 0 ? x.compareTo(y) : c;
            });
    final chosen = lmChoose(p, u),
        continuation = a.model.generate(
          s.ids,
          mode: mode,
          temperature: temperature,
          topK: topK,
          topP: topP,
        ),
        bytes = continuation.takeWhile((id) => id != lmEos).toList();
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag('LLMS & GENAI · CHAPTER 01 · DECODING', icon: Icons.auto_awesome_outlined),
          _gap,
          const Text(
            'Reshape the distribution. Inspect the continuation.',
            style: _title,
          ),
          _gap,
          const Text(
            'Temperature→top-k→renormalize→top-p crossing token retained→renormalize। Same logits different decoding policies দেয়;accuracy/factuality guarantee নয়। Generated bytes model output,original source quotation নয়। এই ক্ষুদ্র model nonsense বা invalid UTF8 তৈরি করতে পারে।',
            style: _bn,
          ),
          _gap,
          _prefixPicker(
            a,
            sample,
            (v) => setState(() => sample = v),
            'decode-source',
          ),
          _gap,
          Text(
            'Actual prefix: ${jsonEncode(s.text)}',
            style: const TextStyle(height: 1.8),
          ),
          _gap,
          Text('Temperature: ${temperature.toStringAsFixed(2)}'),
          Slider(
            key: const Key('llm-temperature'),
            value: temperature,
            min: .5,
            max: 2,
            divisions: 15,
            onChanged: (v) => setState(() => temperature = v),
          ),
          DropdownButtonFormField<int>(
            key: ValueKey('decode-k-$topK'),
            initialValue: topK,
            decoration: const InputDecoration(
              labelText: 'Top-k allowed outputs',
            ),
            items: const [
              DropdownMenuItem(value: 0, child: Text('All257 legal outputs')),
              DropdownMenuItem(value: 5, child: Text('Top5')),
              DropdownMenuItem(value: 20, child: Text('Top20')),
            ],
            onChanged: (v) {
              if (v != null) {
                setState(() => topK = v);
              }
            },
          ),
          SwitchListTile(
            key: const Key('llm-nucleus'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Nucleus top-p .90'),
            value: topP < 1,
            onChanged: (v) => setState(() => topP = v ? .9 : 1),
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Tag('Decoding: $mode'),
              Tag('Surviving IDs: ${rank.length}'),
              Tag('Top-p: ${topP.toStringAsFixed(2)}'),
            ],
          ),
          _gap,
          for (final id in rank.take(8))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 92,
                    child: Text(
                      '$id · ${_token(id)}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: p[id],
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    p[id].toStringAsFixed(5),
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
          _gap,
          Text('Manual uniform draw u: ${u.toStringAsFixed(3)}'),
          Slider(
            key: const Key('llm-uniform'),
            value: u,
            min: 0,
            max: .999,
            divisions: 100,
            onChanged: (v) => setState(() => u = v),
          ),
          Text(
            'Inverse-CDF choice (ascending ID order): $chosen · ${_token(chosen)}',
            style: const TextStyle(height: 1.8),
          ),
          _gap,
          Text(
            'Generated continuation IDs: $continuation\nEscaped UTF8 display (malformed→replacement):\n${jsonEncode(utf8.decode(bytes, allowMalformed: true))}',
            style: const TextStyle(height: 1.9, fontWeight: FontWeight.w700),
          ),
          _gap,
          const Text(
            'Up to8 new tokens,stop on EOS;prefix≤24 plus8 stays within context32। Seeded sampling uses a declared32-bit LCG stream shared by Dart/Python,not backend RNG equality or secure randomness। Greedy is deterministic argmax of filtered distribution;sampling output quality is not a factual-answer evaluation।',
            style: _bn,
          ),
          _gap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                key: const Key('llm-sample'),
                onPressed: () => setState(() => mode = 'sample'),
                child: const Text('Inspect seeded sampling'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  sample = 0;
                  topK = 0;
                  temperature = 1;
                  topP = 1;
                  u = .3;
                  mode = 'greedy';
                }),
                child: const Text('Reset decoding'),
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
