import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../../models/curriculum.dart';
import '../../models/hot_question.dart';
import '../../state/learning_controller.dart';
import '../../ui/rich_prose.dart';
import '../../ui/theme.dart';
import '../lessons/horizontal_reading_view.dart';
import '../lessons/lesson_page.dart';

Color frequencyColor(String frequency) => switch (frequency) {
  'Must-Know' => const Color(0xFFB44C3B),
  'High Frequency' => const Color(0xFF9C7139),
  _ => forest,
};

class HotQuestionDetailPage extends StatefulWidget {
  final LearningController controller;
  final List<HotQuestion> deck;
  final int initialIndex;
  final bool startHidden;

  const HotQuestionDetailPage({
    super.key,
    required this.controller,
    required this.deck,
    this.initialIndex = 0,
    this.startHidden = false,
  });

  @override
  State<HotQuestionDetailPage> createState() => _HotQuestionDetailPageState();
}

class _HotQuestionDetailPageState extends State<HotQuestionDetailPage> {
  late int _index = widget.initialIndex.clamp(0, widget.deck.length - 1);
  late bool _revealed = !widget.startHidden;
  bool _showFollowUp = false;
  final ScrollController _scroll = ScrollController();

  LearningController get c => widget.controller;
  HotQuestion get q => widget.deck[_index];

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _goTo(int nextIndex) {
    setState(() {
      _index = nextIndex;
      _revealed = !widget.startHidden;
      _showFollowUp = false;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Curriculum? _linkedChapter() {
    for (final ch in c.chapters) {
      if (ch.id == q.chapterRef) return ch;
    }
    return null;
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  Future<void> _openChapter(Curriculum target) async {
    if (target.lessons.isEmpty) return;
    try {
      await c.visit(target.lessons.first.id);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              LessonPage(controller: c, lesson: target.lessons.first),
        ),
      );
    } catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final confident = c.isVivaConfident(q.id);
      final review = c.isVivaReview(q.id);
      final starred = c.isVivaStarred(q.id);
      final linked = _linkedChapter();

      return Scaffold(
        appBar: AppBar(
          title: Text(
            '${q.badge} · ${_index + 1} / ${widget.deck.length}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          actions: [
            IconButton(
              key: const ValueKey('viva-toggle-reveal'),
              tooltip: _revealed ? 'Hide answer (Viva Drill)' : 'Reveal answer',
              onPressed: () => setState(() => _revealed = !_revealed),
              icon: Icon(
                _revealed
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
            IconButton(
              key: const ValueKey('viva-star-btn'),
              tooltip: starred ? 'Remove star' : 'Star question',
              onPressed: () => _run(() => c.toggleVivaStar(q.id)),
              icon: Icon(
                starred ? Icons.star_rounded : Icons.star_border_rounded,
                color: starred ? const Color(0xFF9C7139) : null,
              ),
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: SingleChildScrollView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Tag(q.frequency, color: frequencyColor(q.frequency)),
                      Tag(q.categoryLabel),
                      if (confident)
                        const Tag('Confident', icon: Icons.check_circle),
                      if (review)
                        const Tag(
                          'Review Again',
                          icon: Icons.replay_rounded,
                          color: Color(0xFF9C7139),
                        ),
                      if (linked != null)
                        ActionChip(
                          avatar: const Icon(
                            Icons.menu_book_outlined,
                            size: 15,
                          ),
                          label: Text(
                            linked.fullLabel,
                            style: const TextStyle(fontSize: 11),
                          ),
                          onPressed: () => _openChapter(linked),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    q.title,
                    style: const TextStyle(
                      fontFamilyFallback: ['NotoSansBengali'],
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      height: 1.4,
                      letterSpacing: -.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final tag in q.tags)
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(
                            tag,
                            style: const TextStyle(fontSize: 10.5),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  if (!_revealed)
                    Panel(
                      key: const ValueKey('viva-flashcard-gate'),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.record_voice_over_outlined,
                            size: 36,
                            color: forest,
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Viva Drill Mode · আগে মুখে মুখে উত্তর দিন!',
                            style: TextStyle(
                              fontFamilyFallback: ['NotoSansBengali'],
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'নিজেকে ৩টি প্রশ্ন করুন: (১) ৩০ সেকেন্ডের মূল উত্তর কী? (২) একটি সংখ্যাগত উদাহরণ বা Formula কী? (৩) কখন এটি ব্যবহার করবেন বা ব্যর্থ হবে?',
                            style: TextStyle(
                              fontFamilyFallback: ['NotoSansBengali'],
                              fontSize: 13,
                              height: 1.9,
                            ),
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            key: const ValueKey('viva-reveal-answer-btn'),
                            onPressed: () => setState(() => _revealed = true),
                            icon: const Icon(
                              Icons.visibility_outlined,
                              size: 18,
                            ),
                            label: const Text('Reveal Complete Viva Answer'),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    // 1. 30-Second Elevator Answer
                    Panel(
                      key: const ValueKey('viva-elevator-panel'),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Tag(
                            '30-SECOND VIVA ANSWER · এক নজরে উত্তর',
                            icon: Icons.bolt_rounded,
                          ),
                          const SizedBox(height: 14),
                          RichProse(q.elevatorAnswer),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    // 2. Core Breakdown
                    const Eyebrow('CORE BREAKDOWN · পয়েন্ট-বাই-পয়েন্ট ব্যাখ্যা'),
                    const SizedBox(height: 10),
                    Panel(
                      padding: const EdgeInsets.all(20),
                      child: RichProse(q.coreBreakdown),
                    ),
                    const SizedBox(height: 18),
                    // 3. Concrete Worked Example
                    const Eyebrow('CONCRETE EXAMPLE · বাস্তব উদাহরণ'),
                    const SizedBox(height: 10),
                    Panel(
                      padding: const EdgeInsets.all(20),
                      child: RichProse(q.concreteExample),
                    ),
                    // 4. Math Formula
                    if (q.mathFormula.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      const Eyebrow('CORE EQUATION'),
                      const SizedBox(height: 10),
                      Panel(
                        padding: const EdgeInsets.all(18),
                        child: HorizontalReadingView(
                          hint: 'সমীকরণের বাকি অংশ দেখতে ডানে-বাঁয়ে সরান।',
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Math.tex(
                              q.mathFormula,
                              textStyle: TextStyle(
                                fontSize: 16,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    // 5. Short Runnable Code Snippet
                    if (q.codeSnippet.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      const Eyebrow('SHORT PYTHON EXAMPLE'),
                      const SizedBox(height: 10),
                      CodeBlock(
                        title: 'Verified Python Snippet',
                        code: q.codeSnippet,
                      ),
                    ],
                    // 6. Comparison / When to Use What Table
                    if (q.comparisonTable.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      const Eyebrow('COMPARISON · কখন কোনটি ব্যবহার করবেন'),
                      const SizedBox(height: 10),
                      RichProse(q.comparisonTable),
                    ],
                    // 7. Interviewer Follow-up Trap
                    const SizedBox(height: 18),
                    Panel(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Tag(
                            'FAANG FOLLOW-UP TRAP',
                            icon: Icons.psychology_outlined,
                            color: Color(0xFF9C7139),
                          ),
                          const SizedBox(height: 12),
                          RichProse(
                            '**Follow-up:** ${q.followUpQuestion}',
                            style: const TextStyle(
                              fontFamilyFallback: ['NotoSansBengali'],
                              fontSize: 14,
                              height: 1.9,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (!_showFollowUp)
                            OutlinedButton.icon(
                              key: const ValueKey('viva-show-followup'),
                              onPressed: () =>
                                  setState(() => _showFollowUp = true),
                              icon: const Icon(
                                Icons.lightbulb_outline,
                                size: 16,
                              ),
                              label: const Text('Follow-up উত্তর দেখুন'),
                            )
                          else
                            RichProse(q.followUpAnswer),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        key: const ValueKey('viva-confident-btn'),
                        onPressed: () =>
                            _run(() => c.toggleVivaConfident(q.id)),
                        icon: Icon(
                          confident
                              ? Icons.check_circle
                              : Icons.check_circle_outline,
                          size: 18,
                        ),
                        label: Text(confident ? 'Confident' : 'Mark Confident'),
                      ),
                      OutlinedButton.icon(
                        key: const ValueKey('viva-review-btn'),
                        onPressed: () => _run(() => c.toggleVivaReview(q.id)),
                        icon: const Icon(Icons.replay_rounded, size: 17),
                        label: Text(review ? 'In Review Queue' : 'Review Again'),
                      ),
                      if (_index > 0)
                        OutlinedButton.icon(
                          key: const ValueKey('viva-prev-btn'),
                          onPressed: () => _goTo(_index - 1),
                          icon: const Icon(Icons.arrow_back, size: 16),
                          label: const Text('Prev'),
                        ),
                      if (_index + 1 < widget.deck.length)
                        OutlinedButton.icon(
                          key: const ValueKey('viva-next-btn'),
                          onPressed: () => _goTo(_index + 1),
                          icon: const Icon(Icons.arrow_forward, size: 16),
                          iconAlignment: IconAlignment.end,
                          label: Text('Next (${widget.deck[_index + 1].badge})'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
