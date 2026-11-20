import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import 'preparation_model.dart';

class PreprocessingLab extends StatefulWidget {
  const PreprocessingLab({super.key});
  @override
  State<PreprocessingLab> createState() => _PreprocessingLabState();
}

class _PreprocessingLabState extends State<PreprocessingLab> {
  static const training = <double?>[10, 20, null, 90];
  double heldout = 140;
  bool leak = false;
  FillStrategy strategy = FillStrategy.median;
  String n(double value) => value.toStringAsFixed(3);
  @override
  Widget build(BuildContext context) {
    final correct = NumericRecipe.fit(training, strategy: strategy);
    final current = NumericRecipe.fit([
      ...training,
      if (leak) heldout,
    ], strategy: strategy);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'ML FOUNDATIONS · CHAPTER 05 · FIT / TRANSFORM LAB',
            icon: Icons.account_tree_outlined,
          ),
          const SizedBox(height: 18),
          const Text(
            'Freeze the recipe. Move the holdout.',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Holdout বদলালেও training-fitted statistics একই থাকার কথা।',
            style: TextStyle(
              fontFamily: 'NotoSansBengali',
              fontSize: 13,
              height: 2,
            ),
          ),
          const SizedBox(height: 18),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Tag('Training: [10, 20, missing, 90]'),
              Tag('Recipe: impute → StandardScaler'),
            ],
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<FillStrategy>(
            key: ValueKey(strategy),
            initialValue: strategy,
            decoration: const InputDecoration(labelText: 'Imputation strategy'),
            items: const [
              DropdownMenuItem(
                value: FillStrategy.median,
                child: Text('Median'),
              ),
              DropdownMenuItem(value: FillStrategy.mean, child: Text('Mean')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => strategy = v);
            },
          ),
          const SizedBox(height: 18),
          Text(
            'Holdout value: ${heldout.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          Slider(
            key: const Key('holdout-slider'),
            value: heldout,
            min: 40,
            max: 200,
            divisions: 32,
            label: heldout.toStringAsFixed(0),
            semanticFormatterCallback: (v) => 'Holdout ${v.toStringAsFixed(0)}',
            onChanged: (v) => setState(() => heldout = v),
          ),
          SwitchListTile.adaptive(
            key: const Key('leakage-switch'),
            contentPadding: EdgeInsets.zero,
            value: leak,
            onChanged: (v) => setState(() => leak = v),
            title: const Text(
              'Include holdout during fit — leakage',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            subtitle: const Text(
              'Intentionally incorrect mode for comparison',
              style: TextStyle(fontSize: 10, height: 1.8),
            ),
          ),
          const SizedBox(height: 16),
          Tag(
            leak
                ? 'Leaked recipe · 5 fit rows'
                : 'Train-only recipe · 4 fit rows',
            color: leak ? const Color(0xFFB36D28) : null,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              Tag('Fill  ${n(current.fill)}'),
              Tag('Mean  ${n(current.mean)}'),
              Tag('Std  ${n(current.std)}'),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Training records through the current recipe',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < training.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Wrap(
                spacing: 10,
                runSpacing: 6,
                children: [
                  Tag('Raw ${training[i]?.toStringAsFixed(0) ?? 'missing'}'),
                  Tag('Imputed ${n(current.impute(training[i]))}'),
                  Tag('z ${n(current.transform(training[i]))}'),
                ],
              ),
            ),
          const SizedBox(height: 10),
          Text(
            'Holdout transformed z: ${n(current.transform(heldout))}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          const Text(
            'Correct train-only reference',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            'Fill ${n(correct.fill)} · mean ${n(correct.mean)} · std ${n(correct.std)}',
            style: const TextStyle(fontSize: 12, height: 1.9),
          ),
          const SizedBox(height: 10),
          Text(
            leak
                ? 'The held-out value entered fit. Reference statistics stay frozen; the selected recipe is contaminated.'
                : 'Move the holdout slider: fill, mean and std stay fixed. Only the transformed holdout changes.',
            style: const TextStyle(fontSize: 11, height: 1.9),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() {
              heldout = 140;
              leak = false;
              strategy = FillStrategy.median;
            }),
            child: const Text('Reset recipe'),
          ),
          const Text(
            'Worked mathematical values, not Adult observations. Std uses population variance after imputation. Constant std uses scale 1; all-missing training inputs require an explicit policy. This lab demonstrates fitted state, not predictive performance.',
            style: TextStyle(fontSize: 10, height: 1.9),
          ),
        ],
      ),
    );
  }
}

class EncodingLab extends StatefulWidget {
  const EncodingLab({super.key});
  @override
  State<EncodingLab> createState() => _EncodingLabState();
}

class _EncodingLabState extends State<EncodingLab> {
  int frequency = 1;
  String selected = 'D';
  UnknownPolicy policy = UnknownPolicy.ignore;
  String label(String raw) => raw == FrozenEncoder.missing
      ? 'Missing'
      : raw == FrozenEncoder.infrequent
      ? 'Infrequent'
      : raw;
  @override
  Widget build(BuildContext context) {
    final fitted = FrozenEncoder.fit([
      'A',
      'A',
      'B',
      'C',
      null,
    ], minFrequency: frequency);
    final value = selected == 'missing' ? null : selected;
    final vector = fitted.encode(value, policy: policy);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag(
            'ML FOUNDATIONS · CHAPTER 05 · FROZEN VOCABULARY',
            icon: Icons.view_column_outlined,
          ),
          const SizedBox(height: 18),
          const Text(
            'New category. Same feature columns.',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Training vocabulary ও unknown policy আলাদা করে দেখুন।',
            style: TextStyle(
              fontFamily: 'NotoSansBengali',
              fontSize: 13,
              height: 2,
            ),
          ),
          const SizedBox(height: 18),
          const Tag('Training: [A, A, B, C, missing]'),
          const SizedBox(height: 18),
          DropdownButtonFormField<int>(
            key: ValueKey(frequency),
            initialValue: frequency,
            decoration: const InputDecoration(
              labelText: 'Minimum training frequency',
            ),
            items: [
              for (final f in [1, 2, 3])
                DropdownMenuItem(value: f, child: Text('$f')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => frequency = v);
            },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<UnknownPolicy>(
            key: ValueKey(policy),
            initialValue: policy,
            decoration: const InputDecoration(
              labelText: 'Unknown category policy',
            ),
            items: const [
              DropdownMenuItem(
                value: UnknownPolicy.ignore,
                child: Text('Ignore → all zeros'),
              ),
              DropdownMenuItem(
                value: UnknownPolicy.infrequentIfExists,
                child: Text('Use infrequent bucket if fitted'),
              ),
            ],
            onChanged: (v) {
              if (v != null) setState(() => policy = v);
            },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            key: ValueKey(selected),
            initialValue: selected,
            decoration: const InputDecoration(labelText: 'Held-out category'),
            items: [
              for (final v in ['A', 'B', 'C', 'D', 'missing'])
                DropdownMenuItem(
                  value: v,
                  child: Text(v == 'D' ? 'D · unseen' : v),
                ),
            ],
            onChanged: (v) {
              if (v != null) setState(() => selected = v);
            },
          ),
          const SizedBox(height: 22),
          const Text(
            'Fitted output columns → encoded values',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < fitted.vocabulary.length; i++)
                Tag('${label(fitted.vocabulary[i])}: ${vector[i]}'),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Encoded vector: [${vector.join(', ')}]',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          Text(
            '${fitted.vocabulary.length} frozen columns · rare bucket ${fitted.hasRareBucket ? 'present' : 'absent'}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            fitted.hasRareBucket
                ? 'Rare training categories: ${fitted.rare.map(label).join(', ')}'
                : 'Every training category meets the minimum frequency.',
            style: const TextStyle(fontSize: 11, height: 1.9),
          ),
          const SizedBox(height: 12),
          const Text(
            'Selecting held-out D never adds a column. With infrequent-if-exists, D uses a fitted rare bucket; without such a bucket it is all zeros. Missing is a sentinel category and can itself be grouped as rare. This worked encoder uses drop=None.',
            style: TextStyle(fontSize: 11, height: 1.9),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() {
              frequency = 1;
              selected = 'D';
              policy = UnknownPolicy.ignore;
            }),
            child: const Text('Reset vocabulary'),
          ),
          const Text(
            'Illustrative A/B/C categories, not Adult records. This models selected one-hot semantics; it is not a complete replacement for scikit-learn OneHotEncoder.',
            style: TextStyle(fontSize: 10, height: 1.9),
          ),
        ],
      ),
    );
  }
}
