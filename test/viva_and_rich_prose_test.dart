import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ml_path/data/learning_repository.dart';
import 'package:ml_path/features/viva/hot_question_detail_page.dart';
import 'package:ml_path/features/viva/hot_questions_page.dart';
import 'package:ml_path/models/hot_question.dart';
import 'package:ml_path/state/learning_controller.dart';
import 'package:ml_path/ui/rich_prose.dart';
import 'package:ml_path/ui/theme.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

List<HotQuestion> _sampleDeck() => const [
  HotQuestion(
    id: 'viva_sample_root_d',
    number: 1,
    title: 'Scaled Dot-Product Attention-এ sqrt(d_k) দিয়ে ভাগ করা হয় কেন?',
    category: 'transformers_attention',
    categoryLabel: 'Transformers & Attention',
    frequency: 'Must-Know',
    chapterRef: 'chapter_25',
    tags: ['Attention', 'Softmax', 'Gradient'],
    elevatorAnswer:
        '**Dot product** `q · k`-এর variance `d_k`-এর সাথে linear ভাবে বাড়ে; `sqrt(d_k)` দিয়ে ভাগ না করলে **Softmax** saturate হয়ে **Vanishing Gradient** তৈরি করে।',
    coreBreakdown:
        '- **Variance growth:** `q` ও `k`-এর প্রতিটি element independent ও variance `1` হলে `Var(q · k) = d_k`।\n'
        '- **Softmax saturation:** বড় logits-এ Softmax প্রায় one-hot হয়ে যায় এবং Jacobian প্রায় শূন্য হয়।\n'
        '- **Gradient stability:** `1 / sqrt(d_k)` দিয়ে scale করলে variance আবার `1`-এ ফিরে আসে।',
    concreteExample:
        '> **উদাহরণ:** `d_k = 512` হলে unscaled dot product-এর standard deviation প্রায় `22.6`। `softmax([22.6, 0])` প্রায় `[1.0, 0.0]` দেয়, ফলে gradient প্রায় `0` হয়ে যায়।',
    mathFormula:
        r'\mathrm{Attention}(Q,K,V)=\mathrm{softmax}\left(\frac{QK^{\top}}{\sqrt{d_k}}\right)V',
    codeSnippet:
        'import math\n'
        'd_k = 512\n'
        'unscaled_std = math.sqrt(d_k)\n'
        'scaled_std = unscaled_std / math.sqrt(d_k)\n'
        'assert round(scaled_std, 6) == 1.0\n',
    comparisonTable:
        '| Method | Logit Std (d_k=512) | Softmax Behavior |\n'
        '| --- | --- | --- |\n'
        '| Unscaled `QK^T` | `22.6` | Saturates, tiny gradient |\n'
        '| Scaled `QK^T / sqrt(d_k)` | `1.0` | Smooth weights, healthy gradient |',
    followUpQuestion:
        'যদি `q` ও `k`-এর elements correlated হয় বা LayerNorm না থাকে, তাহলে `sqrt(d_k)` কি যথেষ্ট?',
    followUpAnswer:
        '- **না:** correlation থাকলে dot-product variance `O(d_k^2)` পর্যন্ত বাড়তে পারে।\n'
        '- **Production fix:** আধুনিক LLM-এ **QK-Norm** (Query ও Key-তে RMSNorm/LayerNorm) ও **logit soft-capping** ব্যবহার করা হয়।',
  ),
  HotQuestion(
    id: 'viva_sample_l1_l2',
    number: 2,
    title: 'L1 (Lasso) বনাম L2 (Ridge) Regularization-এর মূল পার্থক্য কী?',
    category: 'classical_ml',
    categoryLabel: 'Classical ML',
    frequency: 'Must-Know',
    chapterRef: 'chapter_06',
    tags: ['Regularization', 'Sparsity', 'L1', 'L2'],
    elevatorAnswer:
        '**L1** weight-গুলোকে ঠিক `0` বানিয়ে **Feature Selection** করে, আর **L2** correlated feature-গুলোর weight সমানভাবে ছোট করে stability বাড়ায়।',
    coreBreakdown:
        '- **Geometry:** L1 ball-এর diamond corners axis-এর ওপর থাকে, তাই optimum প্রায়ই `w_i = 0` হয়।\n'
        '- **Gradient:** L1-এর subgradient constant (`±λ`), আর L2-এর gradient `2λw` যা `0`-এর কাছে দুর্বল হয়।',
    concreteExample:
        '> **উদাহরণ:** `100` feature-এর মধ্যে মাত্র `5`টি signal হলে **L1** বাকি `95`টিকে `0` করে দিতে পারে।',
    mathFormula: r'J(w) = \mathrm{MSE}(w) + \lambda_1 \|w\|_1 + \lambda_2 \|w\|_2^2',
    codeSnippet:
        'w = [0.5, -0.2, 0.0]\n'
        'l1 = sum(abs(x) for x in w)\n'
        'l2 = sum(x * x for x in w)\n'
        'assert round(l1, 4) == 0.7 and round(l2, 4) == 0.29\n',
    comparisonTable:
        '| Aspect | L1 (Lasso) | L2 (Ridge) |\n'
        '| --- | --- | --- |\n'
        '| Sparsity | Exact zeros | Shrinks near zero |\n'
        '| Correlated Features | Picks one arbitrarily | Shares weight smoothly |',
    followUpQuestion: 'দুটি feature হুবহু identical হলে L1 ও L2 কী করে?',
    followUpAnswer:
        '- **L1:** arbitrary ভাবে যেকোনো একটি বা convex combination বেছে নেয়।\n'
        '- **L2:** উভয়কে সমান অর্ধেক weight দেয় (`w/2` করে), তাই variance কমে।',
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUpAll(() async {
    for (final family in [
      'Manrope',
      'NotoSansBengali',
      'NotoSansMath',
      'NotoSans',
    ]) {
      await (FontLoader(
        family,
      )..addFont(rootBundle.load('assets/fonts/$family.ttf'))).load();
    }
  });

  late LearningController c;

  setUp(() async {
    final repo = await LearningRepository.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    c = LearningController(repo);
    await c.load();
  });

  tearDown(() async {
    await c.repository.close();
    c.dispose();
  });

  testWidgets(
    'RichProse renders plain text, bold/inline-code, bullets, callouts, fenced code and tables cleanly without narrow overflow',
    (tester) async {
      const sampleRich = r'''**Bias-Variance Tradeoff** ($\mathbb{E}[(y - \hat{f}(x))^2]$) বোঝা FAANG Viva-র মূল ভিত্তি।

$$
\mathrm{MSE}(\hat{f}) = \mathrm{Bias}(\hat{f})^2 + \mathrm{Var}(\hat{f}) + \sigma^2
$$

- **High Bias:** `underfitting` ঘটে, train ও validation উভয় loss বেশি ($\hat{y} = f_\theta(x)$), এবং $\mathrm{pass@}2 = 1 - \frac{\binom{3}{2}}{\binom{5}{2}} = 0.7$।
- **High Variance:** `overfitting` ঘটে, খরচ `$100` থেকে `$200` বাড়ে না কিন্তু test loss বাড়ে।
1. প্রথমে baseline model বানান।
2. তারপর learning curve দেখে সিদ্ধান্ত নিন।

> **উদাহরণ:** Degree-15 polynomial মাত্র 10টি data point-এ fit করলে $\mathrm{Var}(\hat{f})$ আকাশছোঁয়া হয়।

```python
bias_sq, var, noise = 0.04, 0.16, 0.05
print(round(bias_sq + var + noise, 2))
```

| Symptom | Formula | Fix |
| --- | --- | --- |
| High Train Error | $\mathrm{Bias}^2 \gg 0$ | Bigger model / more features |
| Train-Val Gap | $\mathrm{Var}(\hat{f}) \gg 0$ | Regularization / more data |''';

      for (final width in [320.0, 390.0]) {
        for (final scale in [1.0, 1.6, 2.0]) {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          await tester.pumpWidget(
            MaterialApp(
              theme: appTheme(scale == 1.6 ? Brightness.dark : Brightness.light),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const Scaffold(
                body: SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichProse('Plain legacy sentence with no markdown.'),
                      SizedBox(height: 12),
                      RichProse(sampleRich),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.text('Plain legacy sentence with no markdown.'),
            findsOneWidget,
          );
          expect(find.text('PYTHON'), findsOneWidget);
          expect(tester.takeException(), isNull, reason: 'w=$width s=$scale');
          await tester.pumpWidget(const SizedBox());
        }
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );

  testWidgets(
    'HotQuestionDetailPage supports Viva Flashcard Drill mode, follow-up reveal, and confidence/review/star tracking',
    (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final deck = _sampleDeck();
      c.hotQuestions = deck;

      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: HotQuestionDetailPage(
            controller: c,
            deck: deck,
            initialIndex: 0,
            startHidden: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Drill gate hides answer initially
      expect(find.byKey(const ValueKey('viva-flashcard-gate')), findsOneWidget);
      expect(find.byKey(const ValueKey('viva-elevator-panel')), findsNothing);

      // Reveal full answer
      await tester.tap(find.byKey(const ValueKey('viva-reveal-answer-btn')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('viva-elevator-panel')), findsOneWidget);

      // Reveal follow-up trap answer
      final followUpBtn = find.byKey(const ValueKey('viva-show-followup'));
      await tester.ensureVisible(followUpBtn);
      await tester.pumpAndSettle();
      await tester.tap(followUpBtn);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('viva-show-followup')), findsNothing);

      // Mark Confident
      final confidentBtn = find.byKey(const ValueKey('viva-confident-btn'));
      await tester.ensureVisible(confidentBtn);
      await tester.pumpAndSettle();
      await tester.tap(confidentBtn);
      for (var i = 0; i < 50 && !c.isVivaConfident(deck[0].id); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(c.isVivaConfident(deck[0].id), isTrue);

      // Move to Next question — drill gate resets to hidden!
      final nextBtn = find.byKey(const ValueKey('viva-next-btn'));
      await tester.ensureVisible(nextBtn);
      await tester.pumpAndSettle();
      await tester.tap(nextBtn);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('viva-flashcard-gate')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'HotQuestionsPage searches, filters and renders cleanly across narrow mobile widths',
    (tester) async {
      final deck = c.hotQuestions.isNotEmpty ? c.hotQuestions : _sampleDeck();
      if (c.hotQuestions.isEmpty) {
        c.hotQuestions = deck;
      }

      for (final width in [320.0, 390.0]) {
        for (final scale in [1.0, 1.6]) {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          await tester.pumpWidget(
            MaterialApp(
              theme: appTheme(scale == 1.6 ? Brightness.dark : Brightness.light),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: HotQuestionsPage(controller: c),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'w=$width s=$scale');
          await tester.pumpWidget(const SizedBox());
        }
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );

  test(
    'Viva confident, review-again and starred flags survive JSON backup and restore',
    () async {
      await c.toggleVivaConfident('viva_q_001');
      await c.toggleVivaReview('viva_q_002');
      await c.toggleVivaStar('viva_q_001');

      final exported = await c.exportBackup();
      final temp = await Directory.systemTemp.createTemp('ml_viva_backup_');
      addTearDown(() => temp.delete(recursive: true));
      final freshRepo = await LearningRepository.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/fresh.db',
      );
      final fresh = LearningController(freshRepo);
      addTearDown(freshRepo.close);
      addTearDown(fresh.dispose);
      await fresh.load();

      expect(fresh.isVivaConfident('viva_q_001'), isFalse);
      await fresh.importBackup(exported);
      expect(fresh.isVivaConfident('viva_q_001'), isTrue);
      expect(fresh.isVivaReview('viva_q_002'), isTrue);
      expect(fresh.isVivaStarred('viva_q_001'), isTrue);
    },
  );

  test(
    'full 320-question FAANG Viva Bank catalog is complete, unique and hot-topic heavy when wired',
    () async {
      if (c.hotQuestions.isEmpty) return;
      expect(c.hotQuestions.length, 320);
      expect(c.hotQuestions.map((q) => q.id).toSet().length, 320);
      expect(
        c.hotQuestions.map((q) => q.number).toList(),
        List.generate(320, (i) => i + 1),
      );
      final chapterIds = c.chapters.map((ch) => ch.id).toSet();
      var snippetCount = 0;
      var hotCoreCount = 0;
      const hotCategories = {
        'classical_ml',
        'deep_learning',
        'transformers',
        'llm_genai',
      };
      for (final q in c.hotQuestions) {
        expect(chapterIds, contains(q.chapterRef), reason: q.id);
        expect(q.elevatorAnswer.trim(), isNotEmpty, reason: q.id);
        expect(q.coreBreakdown.trim(), isNotEmpty, reason: q.id);
        expect(q.concreteExample.trim(), isNotEmpty, reason: q.id);
        expect(q.followUpQuestion.trim(), isNotEmpty, reason: q.id);
        expect(q.followUpAnswer.trim(), isNotEmpty, reason: q.id);
        if (q.codeSnippet.trim().isNotEmpty) snippetCount++;
        if (hotCategories.contains(q.category)) hotCoreCount++;
      }
      // Classical ML (60) + DL (60) + Transformers (40) + LLMs (60) = 220
      expect(hotCoreCount, greaterThanOrEqualTo(220));
      // At least 70% include executable Python snippets
      expect(snippetCount, greaterThanOrEqualTo(224));
    },
  );
}
