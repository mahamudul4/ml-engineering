import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/features/llm/advanced_llm_labs.dart';
import 'package:ml_path/features/llm/llm_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('pass@k agrees with explicit enumeration of all two-draw subsets', () {
    const outcomes = [true, false, false, true, false];
    var success = 0;
    var total = 0;
    for (var first = 0; first < outcomes.length; first++) {
      for (var next = first + 1; next < outcomes.length; next++) {
        total++;
        if (outcomes[first] || outcomes[next]) success++;
      }
    }
    expect(
      passAtK(samples: 5, correct: 2, picks: 2),
      closeTo(success / total, 1e-12),
    );
    expect(passAtK(samples: 5, correct: 0, picks: 5), 0);
    expect(passAtK(samples: 5, correct: 1, picks: 5), 1);
    expect(
      () => passAtK(samples: 5, correct: 2, picks: 6),
      throwsFormatException,
    );
  });

  testWidgets(
    'patch controls replay the bundled suffix and change the measured gap',
    (tester) async {
      await tester.runAsync(LLMAssets.load);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: ActivationPatchLab()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Logit gap H − d: -2.803345'), findsOneWidget);
      await tester.tap(find.text('Patch receiver'));
      await tester.pumpAndSettle();
      expect(find.text('Residual: source 3 · FFN: source 1'), findsOneWidget);
      expect(find.text('Logit gap H − d: -2.548836'), findsOneWidget);
      await tester.tap(find.text('Reverse patch'));
      await tester.pumpAndSettle();
      expect(find.text('Logit gap H − d: -2.781296'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
