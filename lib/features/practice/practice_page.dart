import 'package:flutter/material.dart';

import '../../state/learning_controller.dart';
import '../../ui/rich_prose.dart';
import '../../ui/theme.dart';
import '../../models/curriculum.dart';
import '../coding/coding_arena_page.dart';
import '../lessons/lesson_page.dart';
import '../viva/hot_questions_page.dart';
import 'quiz_page.dart';

class PracticePage extends StatefulWidget {
  final LearningController controller;
  const PracticePage({super.key, required this.controller});
  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> {
  int tab = 0;
  bool revisionAllBooks = true;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final revisionCount =
          widget.controller.wrongQuizzes(allBooks: true).length +
          widget.controller.starredInterviewItems(allBooks: true).length;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow('${widget.controller.chapter.badge} / PRACTICE STUDIO'),
          const SizedBox(height: 15),
          const Text(
            'Turn knowledge into intuition.',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'A safe place to make mistakes, think out loud, and get better.',
            style: TextStyle(fontSize: 12, height: 1.9),
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final item in [
                (0, 'Knowledge check', Icons.fact_check_outlined),
                (1, 'Coding exercises', Icons.code),
                (2, 'Interview practice', Icons.chat_bubble_outline),
                (
                  3,
                  revisionCount > 0
                      ? 'Revision deck ($revisionCount)'
                      : 'Revision deck',
                  Icons.auto_fix_high_outlined,
                ),
              ])
                ChoiceChip(
                  key: ValueKey('practice-tab-${item.$1}'),
                  avatar: Icon(item.$3, size: 16),
                  label: Text(item.$2, style: const TextStyle(fontSize: 11)),
                  selected: tab == item.$1,
                  onSelected: (_) => setState(() => tab = item.$1),
                ),
            ],
          ),
          const SizedBox(height: 25),
          if (tab == 0) _quiz(),
          if (tab == 1) ...[
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Eyebrow('DEEP-ML STYLE FULL CODEBASE ARENA'),
                  const SizedBox(height: 8),
                  Text(
                    'ML Coding Arena (${widget.controller.codingProblems.length} Problems · 8 Domains)',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const RichProse(
                    'Decision Tree, Attention, KV Cache, LoRA, DCN-v2 সহ পূর্ণাঙ্গ Codebase-এর `# TODO` ফাংশন নিয়ে আগে ভাবুন—তারপর আলাদা Solution ট্যাবে সমাধান মিলিয়ে নিন।',
                    selectable: false,
                    style: TextStyle(
                      fontFamilyFallback: ['NotoSansBengali'],
                      fontSize: 12,
                      height: 1.9,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    key: const ValueKey('practice-open-coding-arena'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            CodingArenaPage(controller: widget.controller),
                      ),
                    ),
                    icon: const Icon(Icons.terminal_rounded, size: 17),
                    label: const Text('Open ML Coding Arena'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Panel(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: forest),
                  SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Write Python in the saved scratchpad, then submit the expected numeric output. This prototype checks your answer; it does not execute Python. Reference solutions are included.',
                      style: TextStyle(fontSize: 12, height: 1.9),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            for (final exercise in widget.controller.chapter.exercises)
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: ExerciseCard(
                  key: ValueKey(exercise.id),
                  controller: widget.controller,
                  exercise: exercise,
                ),
              ),
          ],
          if (tab == 2) ...[
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Eyebrow('HIGH-FREQUENCY FAANG VIVA BANK'),
                  const SizedBox(height: 8),
                  Text(
                    'FAANG Viva Hot Questions (${widget.controller.hotQuestions.length} Questions)',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const RichProse(
                    r'Attention $\sqrt{d_k}$, Bias-Variance, L1 vs L2, XGBoost, Activations, LLM Interpretability সহ সবচেয়ে বেশি আসা প্রশ্নগুলোর পয়েন্ট-বাই-পয়েন্ট উত্তর ও Flashcard Drill।',
                    selectable: false,
                    style: TextStyle(
                      fontFamilyFallback: ['NotoSansBengali'],
                      fontSize: 12,
                      height: 1.9,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    key: const ValueKey('practice-open-hot-questions'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            HotQuestionsPage(controller: widget.controller),
                      ),
                    ),
                    icon: const Icon(
                      Icons.local_fire_department_outlined,
                      size: 17,
                    ),
                    label: const Text('Open FAANG Hot Qs'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Think first. Then compare your approach.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 9),
            const Text(
              'Original FAANG-style practice prompts, not questions attributed to a specific company.',
              style: TextStyle(fontSize: 11, height: 1.9),
            ),
            const SizedBox(height: 20),
            for (
              int i = 0;
              i < widget.controller.chapter.interviews.length;
              i++
            )
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _interview(widget.controller.chapter.interviews[i], i),
              ),
          ],
          if (tab == 3) _revisionDeck(),
        ],
      );
    },
  );
  Widget _quiz() {
    final c = widget.controller;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Tag('${c.chapter.quizzes.length} QUESTIONS · TAKE YOUR TIME'),
          const SizedBox(height: 22),
          const Text(
            'How much has clicked?',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w800,
              letterSpacing: -.6,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'এই chapter-এর ধারণাগুলো যাচাই করুন—প্রতিটি উত্তরের পরে ব্যাখ্যা পাবেন।\nYour answers are saved, so you can pause and come back.',
            style: TextStyle(
              fontFamilyFallback: ['NotoSansBengali'],
              fontSize: 13,
              height: 2,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '${c.answers.length} of ${c.chapter.quizzes.length} answered · ${c.score} correct',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: c.answers.length / c.chapter.quizzes.length,
            borderRadius: BorderRadius.circular(4),
            minHeight: 5,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => QuizPage(controller: c)),
            ),
            icon: const Icon(Icons.arrow_forward, size: 17),
            iconAlignment: IconAlignment.end,
            label: Text(
              c.answers.isEmpty
                  ? 'Start knowledge check'
                  : c.answers.length == c.chapter.quizzes.length
                  ? 'Review your answers'
                  : 'Continue knowledge check',
            ),
          ),
        ],
      ),
    );
  }

  Widget _interview(InterviewQuestion q, int index) =>
      _interviewCard(widget.controller.chapter, q, index);

  Widget _interviewCard(
    Curriculum owner,
    InterviewQuestion q,
    int index, {
    bool showChapterLabel = false,
  }) {
    final starred = widget.controller.isInterviewStarred(owner.id, index);
    return Panel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Tag(
                    showChapterLabel
                        ? '${owner.fullLabel} · ${q.tag}'
                        : '${index + 1} / ${owner.interviews.length} · ${q.tag}',
                  ),
                ),
              ),
              IconButton(
                key: ValueKey('star-interview-${owner.id}-$index'),
                visualDensity: VisualDensity.compact,
                tooltip: starred
                    ? 'Remove from revision deck'
                    : 'Save to revision deck',
                onPressed: () => widget.controller
                    .toggleInterviewStar(owner.id, index)
                    .catchError((Object e) {
                      if (mounted) showFailure(context, e);
                    }),
                icon: Icon(
                  starred ? Icons.star_rounded : Icons.star_border_rounded,
                  size: 21,
                  color: starred ? const Color(0xFF9C7139) : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            q.title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          RichProse(
            q.prompt,
            style: const TextStyle(
              fontFamily: 'NotoSansBengali',
              fontFamilyFallback: ['Manrope', 'NotoSansMath', 'NotoSans'],
              fontSize: 13,
              height: 2,
            ),
          ),
          if (q.prerequisiteLessons.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'আগে এই পাঠগুলো পড়ে নিতে পারেন',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final id in q.prerequisiteLessons) _prerequisiteButton(id),
              ],
            ),
          ],
          const SizedBox(height: 15),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 12),
            title: const Text(
              'Explore an answer & follow-up',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: RichProse(
                  q.answer,
                  style: const TextStyle(
                    fontFamily: 'NotoSansBengali',
                    fontFamilyFallback: ['Manrope', 'NotoSansMath', 'NotoSans'],
                    fontSize: 13,
                    height: 2.0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _revisionDeck() {
    final c = widget.controller;
    final mistakes = c.wrongQuizzes(allBooks: revisionAllBooks);
    final starred = c.starredInterviewItems(allBooks: revisionAllBooks);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'FAANG Mistake & Interview Revision Deck',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          'ভুল হওয়া quiz প্রশ্নগুলো এবং star দিয়ে রাখা FAANG interview prompt-গুলো এক জায়গায় ঝালাই করে নিন।',
          style: TextStyle(
            fontFamilyFallback: ['NotoSansBengali'],
            fontSize: 12,
            height: 1.9,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            ChoiceChip(
              key: const ValueKey('revision-scope-all'),
              label: const Text(
                'সব বই (All Books)',
                style: TextStyle(fontSize: 11),
              ),
              selected: revisionAllBooks,
              onSelected: (_) => setState(() => revisionAllBooks = true),
            ),
            ChoiceChip(
              key: const ValueKey('revision-scope-chapter'),
              label: const Text('এই অধ্যায়', style: TextStyle(fontSize: 11)),
              selected: !revisionAllBooks,
              onSelected: (_) => setState(() => revisionAllBooks = false),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (mistakes.isEmpty && starred.isEmpty)
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.verified_outlined,
                  color: forest,
                  size: 36,
                ),
                const SizedBox(height: 14),
                const Text(
                  'Revision queue একদম পরিষ্কার।',
                  style: TextStyle(
                    fontFamilyFallback: ['NotoSansBengali'],
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'কোনো quiz-এ ভুল উত্তর দিলে সেটি স্বয়ংক্রিয়ভাবে এখানে জমা হবে। আর Interview practice-এ যেকোনো প্রশ্নের পাশে star আইকন চাপলে তা এখানে সেভ থাকবে।',
                  style: TextStyle(
                    fontFamilyFallback: ['NotoSansBengali'],
                    fontSize: 12,
                    height: 1.9,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton(
                      onPressed: () => setState(() => tab = 0),
                      child: const Text('Go to knowledge check'),
                    ),
                    OutlinedButton(
                      onPressed: () => setState(() => tab = 2),
                      child: const Text('Browse interviews'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        if (mistakes.isNotEmpty) ...[
          Text(
            'Missed Quiz Queue (${mistakes.length})',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          for (final entry in mistakes)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Panel(
                key: ValueKey('revision-quiz-${entry.$2.id}'),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Tag(
                      '${entry.$1.fullLabel} · NEEDS REVIEW',
                      color: const Color(0xFF9C7139),
                    ),
                    const SizedBox(height: 14),
                    RichProse(
                      entry.$2.question,
                      selectable: false,
                      style: const TextStyle(
                        fontFamilyFallback: ['NotoSansBengali'],
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1.7,
                      ),
                    ),
                    const SizedBox(height: 14),
                    for (var opt = 0; opt < entry.$2.options.length; opt++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            key: ValueKey(
                              'revision-option-${entry.$2.id}-$opt',
                            ),
                            style: OutlinedButton.styleFrom(
                              alignment: Alignment.centerLeft,
                              side: opt == entry.$3
                                  ? const BorderSide(
                                      color: Color(0xFF9C7139),
                                      width: 1.4,
                                    )
                                  : null,
                            ),
                            onPressed: () => c
                                .answer(entry.$2.id, opt)
                                .catchError((Object e) {
                                  if (mounted) showFailure(context, e);
                                }),
                            child: Text(
                              entry.$2.options[opt],
                              style: const TextStyle(
                                fontFamilyFallback: ['NotoSansBengali'],
                                fontSize: 12,
                                height: 1.7,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text(
                        'Why that tripped you up · ব্যাখ্যা দেখুন',
                        style: TextStyle(
                          fontFamilyFallback: ['NotoSansBengali'],
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      children: [
                        Text(
                          entry.$2.explanation,
                          style: const TextStyle(
                            fontFamilyFallback: ['NotoSansBengali'],
                            fontSize: 12,
                            height: 1.9,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
        if (starred.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'Starred FAANG Interviews (${starred.length})',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          for (final item in starred)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _interviewCard(
                item.$1,
                item.$2,
                item.$3,
                showChapterLabel: true,
              ),
            ),
        ],
      ],
    );
  }

  Widget _prerequisiteButton(String id) {
    final c = widget.controller;
    final chapter = c.chapters.firstWhere(
      (value) => value.lessons.any((lesson) => lesson.id == id),
    );
    final lesson = chapter.lessons.firstWhere((value) => value.id == id);
    return OutlinedButton(
      key: ValueKey('interview-prerequisite-$id'),
      onPressed: () async {
        try {
          await c.visit(id);
          if (!mounted) return;
          await Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => LessonPage(controller: c, lesson: lesson),
            ),
          );
        } catch (error) {
          if (mounted) showFailure(context, error);
        }
      },
      child: Text(
        '${chapter.bookVolume == c.currentBook ? chapter.label : chapter.fullLabel} · ${lesson.title}',
        style: const TextStyle(fontSize: 11),
      ),
    );
  }
}

class ExerciseCard extends StatefulWidget {
  final LearningController controller;
  final Exercise exercise;
  const ExerciseCard({
    super.key,
    required this.controller,
    required this.exercise,
  });
  @override
  State<ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<ExerciseCard> {
  late final draft = TextEditingController(text: widget.exercise.starter);
  final output = TextEditingController();
  bool loaded = false, saving = false, solved = false;
  String? feedback;
  String savedDraft = '';
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final record = await widget.controller.repository.exercise(
        widget.exercise.id,
      );
      if (!mounted) return;
      setState(() {
        if (record != null) {
          draft.text = record['draft'] as String;
          solved = record['solved'] == 1;
        }
        savedDraft = draft.text;
        loaded = true;
      });
    } catch (e) {
      if (mounted) {
        setState(() => loaded = true);
        showFailure(context, e);
      }
    }
  }

  @override
  void dispose() {
    draft.dispose();
    output.dispose();
    super.dispose();
  }

  Future<void> _save({bool check = false}) async {
    final value = double.tryParse(output.text.trim());
    if (check && (value == null || !value.isFinite)) {
      setState(() => feedback = 'Enter a finite numeric output first.');
      return;
    }
    setState(() => saving = true);
    final correct = check && widget.exercise.acceptsResult(value!);
    try {
      await widget.controller.repository.saveExercise(
        widget.exercise.id,
        draft.text,
        solved || correct,
      );
      if (!mounted) return;
      setState(() {
        solved = solved || correct;
        savedDraft = draft.text;
        feedback = check
            ? correct
                  ? 'সংখ্যার ফল মিলেছে। ${widget.exercise.explanation}'
                  : 'ফল মেলেনি। ধাপে ধাপে আবার হিসাব করে দেখুন।'
            : 'Draft saved on this device.';
      });
    } catch (e) {
      if (mounted) showFailure(context, e);
    }
    if (mounted) setState(() => saving = false);
  }

  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.exercise.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (solved) const Tag('ফল মিলেছে', icon: Icons.check),
          ],
        ),
        const SizedBox(height: 15),
        RichProse(
          widget.exercise.prompt,
          style: const TextStyle(
            fontFamily: 'NotoSansBengali',
            fontFamilyFallback: ['Manrope', 'NotoSansMath', 'NotoSans'],
            fontSize: 13,
            height: 2,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'এখানে Python code চালানো হয় না। নিচের পরীক্ষায় শুধু সংখ্যার ফল মেলানো হয়।',
          style: TextStyle(fontSize: 12, height: 1.9),
        ),
        const SizedBox(height: 12),
        if (!loaded)
          const LinearProgressIndicator()
        else
          TextField(
            controller: draft,
            onChanged: (_) => setState(() {}),
            minLines: 7,
            maxLines: 16,
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              fontFamilyFallback: ['NotoSansBengali'],
              fontSize: 12,
              height: 1.8,
            ),
            decoration: const InputDecoration(
              labelText: 'Python code',
              alignLabelWithHint: true,
            ),
          ),
        const SizedBox(height: 10),
        Text(
          draft.text == savedDraft
              ? 'Draft saved'
              : 'Unsaved edits · tap Save draft before leaving',
          style: const TextStyle(fontSize: 10),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: 260,
          child: TextField(
            controller: output,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            decoration: InputDecoration(
              labelText: 'হিসাবের ফল',
              helperText:
                  'যথেষ্ট precision দিন। Tolerance: '
                  '${widget.exercise.absoluteTolerance.toStringAsExponential(0)} + '
                  '${widget.exercise.relativeTolerance.toStringAsExponential(0)} × |expected|।',
              helperMaxLines: 8,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            FilledButton(
              onPressed: saving || !loaded ? null : () => _save(check: true),
              child: const Text('Check answer'),
            ),
            OutlinedButton(
              onPressed: saving || !loaded ? null : _save,
              child: const Text('Save draft'),
            ),
          ],
        ),
        if (feedback != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: RichProse(
              feedback!,
              style: const TextStyle(
                fontFamilyFallback: ['NotoSansBengali'],
                height: 2,
                fontSize: 12,
              ),
            ),
          ),
        const SizedBox(height: 12),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text(
            'Reference solution & walkthrough',
            style: TextStyle(fontSize: 12),
          ),
          children: [
            CodeBlock(code: widget.exercise.solution),
            const SizedBox(height: 14),
            RichProse(
              widget.exercise.explanation,
              style: const TextStyle(
                fontFamily: 'NotoSansBengali',
                fontFamilyFallback: ['Manrope', 'NotoSansMath', 'NotoSans'],
                height: 2,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
