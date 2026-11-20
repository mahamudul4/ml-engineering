import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/features/llm/llm_model.dart';

void main() {
  final raw = jsonDecode(
        File('assets/datasets/alice/llm_lab.json').readAsStringSync(),
      ) as Map<String, dynamic>,
      a = LLMAssets.fromJson(raw);
  Map<String, dynamic> fresh() =>
      jsonDecode(jsonEncode(raw)) as Map<String, dynamic>;
  void near(dynamic got, dynamic expected, {double tolerance = 1e-9}) {
    if (got is List) {
      expect(got.length, (expected as List).length);
      for (var i = 0; i < got.length; i++) {
        near(got[i], expected[i], tolerance: tolerance);
      }
    } else {
      expect(
        (got as num).toDouble(),
        closeTo((expected as num).toDouble(), tolerance),
      );
    }
  }

  test('Actual source tokenization and Unicode preserve exact byte/BPE round-trips', () {
    for (final e in raw['examples'] as List) {
      expect(a.tokenizer.encode(e['text']), e['bytes']);
      expect(a.tokenizer.encode(e['text'], bpe: true), e['bpe_ids']);
    }
    for (final text in [
      '',
      ...a.examples,
      'বাংলা ’',
      '\u00e9',
      'e\u0301',
      '😀',
    ]) {
      for (final bpe in [false, true]) {
        final ids = a.tokenizer.encode(text, bpe: bpe);
        expect(a.tokenizer.decode(ids), text);
        expect(a.tokenizer.decodeBytes(ids), utf8.encode(text));
      }
    }
    expect(a.tokenizer.encode('’').length, 3);
    expect(a.tokenizer.encode('\u00e9'), isNot(a.tokenizer.encode('e\u0301')));
    expect(() => a.tokenizer.decodeBytes([lmBos]), throwsArgumentError);
    expect(() => a.tokenizer.encode('a' * 4097), throwsArgumentError);
  });
  test('All six actual causal/full decoder traces match PyTorch at every intermediate', () {
    for (var i = 0; i < 3; i++) {
      for (final r in raw['samples'][i]['references'] as List) {
        final trace = a.model.run(a.samples[i].ids, causal: r['causal']);
        for (final key in trace.matrices.keys) {
          near(trace.matrices[key], r['trace'][key]);
        }
        near(trace.weights, r['trace']['weights']);
      }
    }
  });
  test('Causal prefix invariance PAD keys and single-block last-query equivalence hold', () {
    final ids = a.samples.first.ids,
        changed = [...ids.take(5), ...ids.skip(5).toList().reversed],
        base = a.model.run(ids),
        future = a.model.run(changed);
    near(
      base.matrices['logits']!.take(5).toList(),
      future.matrices['logits']!.take(5).toList(),
    );
    final full = a.model.run(ids, causal: false);
    near(base.matrices['logits']!.last, full.matrices['logits']!.last);
    final padded = a.model.run([...ids, lmPad, lmPad]);
    near(
      base.matrices['logits'],
      padded.matrices['logits']!.take(ids.length).toList(),
    );
    for (var h = 0; h < 2; h++) {
      for (var i = 0; i < ids.length; i++) {
        expect(base.weights[h][i].reduce((x, y) => x + y), closeTo(1, 1e-12));
        for (var j = i + 1; j < ids.length; j++) {
          expect(base.weights[h][i][j], 0);
        }
      }
    }
    expect(padded.matrices['logits']!.length, ids.length + 2);
  });
  test('Nine complete continuations match Python and greedy survives positive-temperature filters', () {
    for (var i = 0; i < 3; i++) {
      for (final r in raw['samples'][i]['generation'] as List) {
        expect(
          a.model.generate(
            a.samples[i].ids,
            mode: r['mode'],
            temperature: (r['temperature'] as num).toDouble(),
            topK: r['top_k'],
            topP: (r['top_p'] as num).toDouble(),
          ),
          r['ids'],
        );
      }
    }
    final ids = a.samples.first.ids, before = [...ids];
    expect(
      a.model.generate(
        ids,
        mode: 'greedy',
        temperature: .7,
        topK: 20,
        topP: .9,
      ),
      a.model.generate(ids, mode: 'greedy'),
    );
    expect(a.model.generate(ids), a.model.generate(ids));
    expect(ids, before);
    final forced = fresh();
    forced['weights']['head.bias'] = List.filled(259, -10000.0);
    forced['weights']['head.bias'][lmEos] = 10000.0;
    expect(LLMAssets.fromJson(forced).model.generate(ids), [lmEos]);
    expect(
      a.model.generate(ids).any((id) => id == lmPad || id == lmBos),
      isFalse,
    );
  });
  test('Stable distribution masks classes tie-breaks top-k and retains nucleus crossing', () {
    final equal = List.filled(259, 1000.0)
      ..[lmPad] = 1e9
      ..[lmBos] = 1e9;
    final all = lmDistribution(equal);
    expect(all[lmPad] + all[lmBos], 0);
    expect(all.reduce((x, y) => x + y), closeTo(1, 1e-12));
    expect(all[0], closeTo(1 / 257, 1e-12));
    final k = lmDistribution(equal, topK: 5);
    expect(
      [
        for (var i = 0; i < 259; i++)
          if (k[i] > 0) i,
      ],
      [0, 1, 2, 3, 4],
    );
    final nucleus = lmDistribution(equal, topK: 5, topP: .6);
    expect(nucleus.where((v) => v > 0).length, 3);
    final p = List.filled(259, 0.0)
      ..[0] = .2
      ..[1] = .3
      ..[2] = .5;
    expect(lmChoose(p, 0), 0);
    expect(lmChoose(p, .2), 1);
    expect(lmChoose(p, .5), 2);
    expect(lmChoose(p, .999999), 2);
    expect(lmUniforms(), lmUniforms());
    expect(lmUniforms().every((v) => v > 0 && v < 1), isTrue);
  });
  test('Source identities shifted labels and all returned model/token arrays are immutable', () {
    expect(a.samples.map((s) => s.sourceChapter), [1, 3, 9]);
    expect(a.samples.map((s) => s.role), ['fit', 'fit', 'validation']);
    for (final s in a.samples) {
      expect(s.ids.first, lmBos);
      expect(s.targets.take(s.targets.length - 1), s.ids.skip(1));
    }
    final trace = a.model.run(a.samples.first.ids);
    expect(() => trace.matrices.clear(), throwsUnsupportedError);
    expect(() => trace.weights[0][0][0] = 1, throwsUnsupportedError);
    expect(() => a.samples.first.ids[0] = 0, throwsUnsupportedError);
    expect(
      () => a.model.matrices['embedding.weight']![0][0] = 0,
      throwsUnsupportedError,
    );
    expect(() => a.tokenizer.pieces[0]![0] = 1, throwsUnsupportedError);
    expect(() => a.tokenizer.encode('abc')[0] = 1, throwsUnsupportedError);
    expect((raw['history'] as List).length, 11);
    expect(
      raw['history'].last['train_nll'],
      lessThan(raw['history'].first['train_nll']),
    );
  });
  test('Empty contexts incompatible BPE IDs invalid sampling and nonfinite logits fail', () {
    for (final ids in <List<int>>[
      [],
      [lmPad],
      [259],
      [-1],
      List.filled(33, 65),
    ]) {
      expect(() => a.model.run(ids), throwsArgumentError);
    }
    expect(() => a.model.generate(List.filled(25, 65)), throwsArgumentError);
    expect(() => a.model.generate([lmBos], mode: 'beam'), throwsArgumentError);
    final scores = List.filled(259, 0.0);
    for (final t in [0.0, -1.0, double.nan, double.infinity]) {
      expect(() => lmDistribution(scores, temperature: t), throwsArgumentError);
    }
    for (final p in [0.0, 1.1, double.nan]) {
      expect(() => lmDistribution(scores, topP: p), throwsArgumentError);
    }
    expect(() => lmDistribution(scores, topK: 1), throwsArgumentError);
    expect(
      () => lmDistribution(List.filled(259, double.nan)),
      throwsArgumentError,
    );
    for (final u in [-.1, 1.0, double.nan]) {
      expect(() => lmChoose(lmDistribution(scores), u), throwsArgumentError);
    }
  });
  test('Corrupt vocabulary merge ranks PAD embeddings source roles and positions reject', () {
    for (final change in <void Function(Map<String, dynamic>)>[
      (j) => j['vocab'] = 275,
      (j) => j['special_ids']['pad'] = 0,
      (j) => j['parameters'] = 1000,
      (j) => j['merges'][0]['pair'][0] = lmBos,
      (j) => j['merges'][0]['id'] = 270,
      (j) => j['weights']['head.weight'][0] = [0, 1],
      (j) => j['weights']['position'][0][0] = 1,
      (j) => j['weights']['embedding.weight'][256][0] = 1,
      (j) => j['samples'][0]['role'] = 'test',
      (j) => j['samples'][0]['targets'][0] = lmBos,
      (j) => j['examples'][0]['bpe_ids'] = [999],
    ]) {
      final j = fresh();
      change(j);
      expect(() => LLMAssets.fromJson(j), throwsA(anything));
    }
  });
}
