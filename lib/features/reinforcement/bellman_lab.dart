import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import 'bellman_model.dart';

class BellmanLab extends StatefulWidget {
  const BellmanLab({super.key});
  @override
  State<BellmanLab> createState() => _BellmanLabState();
}

class _BellmanLabState extends State<BellmanLab> {
  double discount = .9, probability = .7, delta = 0;
  int sweeps = 0;
  List<double> values = [0, 0, 0];
  BellmanModel get model =>
      BellmanModel(discount: discount, successProbability: probability);

  void reset() {
    values = [0, 0, 0];
    sweeps = 0;
    delta = 0;
  }

  void advance(int count) => setState(() {
    for (var i = 0; i < count; i++) {
      final next = model.sweep(values);
      delta = model.change(values, next);
      values = next;
      sweeps++;
    }
  });

  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('KNOWN MDP · OFFLINE PLANNING'),
        const SizedBox(height: 12),
        const Text(
          'Bellman value iteration',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        const Text(
          'Start-এ safe নিলে reward 1 পেয়ে থামে। Advance নিলে reward 0 পেয়ে Middle-এ যায়।\n\n'
          'Middle-এ safe নিলে reward 1 পেয়ে থামে। Try সফল হলে reward 4 পেয়ে শেষ হয়। '
          'ব্যর্থ হলে reward −1 পেয়ে Start-এ ফেরে। Terminal value 0।\n\n'
          'এই Environment-এর জানা Transition-গুলো ব্যবহার করে Planning করুন।',
          style: TextStyle(height: 1.9),
        ),
        const SizedBox(height: 18),
        Text('Discount γ = ${discount.toStringAsFixed(2)}'),
        Slider(
          key: const ValueKey('rl-discount'),
          value: discount,
          min: 0,
          max: .99,
          divisions: 99,
          label: discount.toStringAsFixed(2),
          onChanged: (value) => setState(() {
            discount = value;
            reset();
          }),
        ),
        Text('Try success probability p = ${probability.toStringAsFixed(2)}'),
        Slider(
          key: const ValueKey('rl-probability'),
          value: probability,
          divisions: 100,
          label: probability.toStringAsFixed(2),
          onChanged: (value) => setState(() {
            probability = value;
            reset();
          }),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton(
              onPressed: () => advance(1),
              child: const Text('Next Bellman sweep'),
            ),
            OutlinedButton(
              onPressed: () => advance(20),
              child: const Text('Run 20 sweeps'),
            ),
            TextButton(
              onPressed: () => setState(reset),
              child: const Text('Reset values'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          'Sweep $sweeps',
          key: const ValueKey('rl-sweep-count'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        for (var state = 0; state < 3; state++) ...[
          const SizedBox(height: 10),
          Text(
            '${['Start', 'Middle', 'Terminal'][state]} · V = ${values[state].toStringAsFixed(6)}',
            key: ValueKey('rl-value-$state'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (state < 2)
            Builder(
              builder: (_) {
                final q = model.actionValues(values, state);
                final action = q[0] >= q[1]
                    ? 'safe'
                    : (state == 0 ? 'advance' : 'try');
                return Text(
                  'পরের backup-এ Q(safe) = ${q[0].toStringAsFixed(6)}, '
                  'Q(${state == 0 ? 'advance' : 'try'}) = ${q[1].toStringAsFixed(6)} · greedy action $action',
                  style: const TextStyle(height: 1.8),
                );
              },
            ),
        ],
        const SizedBox(height: 16),
        Text(
          sweeps == 0
              ? 'প্রথম Sweep-এর আগে সব Value শূন্য। প্রতিটি নতুন Sweep আগের Sweep-এর স্থির Vector ব্যবহার করে।'
              : 'শেষ ধাপে পরিবর্তন = ${delta.toStringAsExponential(3)}। '
                    'exact-MDP error bound ≤ ${model.errorBound(delta).toStringAsExponential(3)}। '
                    'এই Bound দিয়ে নির্দিষ্ট Transition Model-এ হিসাব কতটা Converge করেছে, তা বোঝা যায়।',
          style: const TextStyle(height: 1.9),
        ),
        const SizedBox(height: 12),
        const Text(
          'এবার p = 0, তারপর p = 1 দিন। γ = 0 হলে immediate reward কীভাবে action নির্ধারণ করে ব্যাখ্যা করুন।',
          style: TextStyle(height: 1.9),
        ),
      ],
    ),
  );
}
