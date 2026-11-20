import 'package:flutter/material.dart';

import '../../state/learning_controller.dart';
import '../../ui/theme.dart';

class QuizPage extends StatefulWidget {
  final LearningController controller;
  const QuizPage({super.key, required this.controller});
  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  late int index;
  bool saving = false, summary = false;
  final scroll = ScrollController();
  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  void showQuestion(int question) {
    setState(() {
      index = question;
      summary = false;
    });
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  @override
  void initState() {
    super.initState();
    final first = widget.controller.chapter.quizzes.indexWhere(
      (q) => !widget.controller.answers.containsKey(q.id),
    );
    index = first < 0 ? 0 : first;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller,
        q = c.chapter.quizzes[index],
        chosen = c.answers[q.id];
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${c.chapter.label} · Knowledge check',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(22, 30, 22, 50),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: summary
                ? _summary()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Eyebrow(
                            'QUESTION ${index + 1} OF ${c.chapter.quizzes.length}',
                          ),
                          Text(
                            '${c.score} correct · ${c.answers.length} answered',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      LinearProgressIndicator(
                        value: (index + 1) / c.chapter.quizzes.length,
                        minHeight: 5,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      const SizedBox(height: 30),
                      Text(
                        q.question,
                        style: const TextStyle(
                          fontFamily: 'NotoSansBengali',
                          fontSize: 22,
                          height: 1.9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 26),
                      for (int i = 0; i < q.options.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              alignment: Alignment.centerLeft,
                              backgroundColor: chosen != null && i == q.answer
                                  ? forest.withValues(alpha: .1)
                                  : chosen == i
                                  ? const Color(0xFFB46744)
                                        .withValues(alpha: .10)
                                  : Theme.of(context).colorScheme.surface,
                              side: BorderSide(
                                color: chosen != null && i == q.answer
                                    ? forest
                                    : Theme.of(context).dividerColor,
                              ),
                            ),
                            onPressed: chosen != null || saving
                                ? null
                                : () async {
                                    setState(() => saving = true);
                                    try {
                                      await c.answer(q.id, i);
                                    } catch (e) {
                                      if (context.mounted) {
                                        showFailure(context, e);
                                      }
                                    }
                                    if (mounted) setState(() => saving = false);
                                  },
                            child: Row(
                              children: [
                                Text(
                                  String.fromCharCode(65 + i),
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 17),
                                Expanded(
                                  child: Text(
                                    q.options[i],
                                    style: TextStyle(
                                      fontFamily: 'NotoSansBengali',
                                      fontSize: 13,
                                      height: 1.9,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                  ),
                                ),
                                if (chosen != null && i == q.answer)
                                  const Icon(
                                    Icons.check_circle,
                                    size: 18,
                                    color: forest,
                                  )
                                else if (chosen == i)
                                  const Icon(
                                    Icons.cancel_outlined,
                                    size: 18,
                                    color: Color(0xFFB46744),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      if (chosen != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Panel(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  chosen == q.answer
                                      ? 'Exactly. You’ve got it!'
                                      : 'A useful mistake. Let’s unpack it.',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  q.explanation,
                                  style: const TextStyle(
                                    fontFamily: 'NotoSansBengali',
                                    height: 2,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 26),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: 12,
                        runSpacing: 10,
                        children: [
                          TextButton(
                            onPressed: index == 0
                                ? null
                                : () => showQuestion(index - 1),
                            child: const Text('← Previous'),
                          ),
                          FilledButton(
                            onPressed: chosen == null
                                ? null
                                : () {
                                    if (index == c.chapter.quizzes.length - 1) {
                                      setState(() => summary = true);
                                      if (scroll.hasClients) scroll.jumpTo(0);
                                    } else {
                                      showQuestion(index + 1);
                                    }
                                  },
                            child: Text(
                              index == c.chapter.quizzes.length - 1
                                  ? 'See results'
                                  : 'Next question →',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Answers save immediately. You can leave and resume anytime.',
                        style: TextStyle(fontSize: 10, height: 1.8),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _summary() {
    final c = widget.controller;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.workspace_premium_outlined, size: 48, color: forest),
          const SizedBox(height: 22),
          const Eyebrow('KNOWLEDGE CHECK COMPLETE'),
          const SizedBox(height: 16),
          Text(
            '${c.score} / ${c.chapter.quizzes.length}',
            style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Text(
            c.score >= (c.chapter.quizzes.length * .8).ceil()
                ? 'Your foundation is taking shape.'
                : 'Every attempt is a step forward.',
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          const Text(
            'ভুলগুলো আবার দেখুন। ব্যাখ্যা পড়ে নিজের ভাষায় ধারণাগুলো বলুন।',
            style: TextStyle(
              fontFamily: 'NotoSansBengali',
              height: 2,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton(
                onPressed: () => showQuestion(0),
                child: const Text('Review answers'),
              ),
              OutlinedButton(
                onPressed: saving
                    ? null
                    : () async {
                        setState(() => saving = true);
                        try {
                          await c.resetQuiz();
                          if (mounted) {
                            showQuestion(0);
                          }
                        } catch (e) {
                          if (mounted) showFailure(context, e);
                        }
                        if (mounted) setState(() => saving = false);
                      },
                child: const Text('Try again'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back to practice'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
