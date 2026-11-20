import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../../models/coding_problem.dart';
import '../../models/curriculum.dart';
import '../../state/learning_controller.dart';
import '../../ui/theme.dart';
import '../lessons/horizontal_reading_view.dart';
import '../lessons/lesson_page.dart';

Color difficultyColor(String difficulty) => switch (difficulty) {
  'Easy' => forest,
  'Medium' => const Color(0xFF9C7139),
  _ => const Color(0xFFB44C3B),
};

class CodingProblemPage extends StatefulWidget {
  final LearningController controller;
  final CodingProblem problem;

  const CodingProblemPage({
    super.key,
    required this.controller,
    required this.problem,
  });

  @override
  State<CodingProblemPage> createState() => _CodingProblemPageState();
}

class _CodingProblemPageState extends State<CodingProblemPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  late final TextEditingController _noteCtrl = TextEditingController(
    text: widget.controller.codingNote(widget.problem.id),
  );
  final Map<int, int> _selectedAnswers = {};
  bool _solutionRevealed = false;
  bool _savingNote = false;
  String? _noteStatus;

  LearningController get c => widget.controller;
  CodingProblem get p => widget.problem;

  @override
  void initState() {
    super.initState();
    _solutionRevealed = c.isCodingSolved(p.id);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Curriculum? _linkedChapter() {
    for (final ch in c.chapters) {
      if (ch.id == p.chapterRef) return ch;
    }
    return null;
  }

  CodingProblem? _nextProblem() {
    final idx = c.codingProblems.indexWhere((item) => item.id == p.id);
    if (idx < 0 || idx + 1 >= c.codingProblems.length) return null;
    return c.codingProblems[idx + 1];
  }

  Future<void> _saveNote() async {
    setState(() {
      _savingNote = true;
      _noteStatus = null;
    });
    try {
      await c.saveCodingNote(p.id, _noteCtrl.text);
      if (mounted) {
        setState(() => _noteStatus = 'নোট ও pseudocode ডিভাইসে সেভ হয়েছে।');
      }
    } catch (e) {
      if (mounted) showFailure(context, e);
    }
    if (mounted) setState(() => _savingNote = false);
  }

  Future<void> _openLinkedChapter(Curriculum target) async {
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
      final solved = c.isCodingSolved(p.id);
      final starred = c.isCodingStarred(p.id);
      return Scaffold(
        appBar: AppBar(
          title: Text(
            '${p.badge} · ${p.title}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          actions: [
            IconButton(
              key: const ValueKey('problem-star-btn'),
              tooltip: starred ? 'Remove star' : 'Star for revision',
              onPressed: () => c.toggleCodingStar(p.id).catchError((Object e) {
                if (context.mounted) showFailure(context, e);
              }),
              icon: Icon(
                starred ? Icons.star_rounded : Icons.star_border_rounded,
                color: starred ? const Color(0xFF9C7139) : null,
              ),
            ),
            IconButton(
              key: const ValueKey('problem-solved-btn'),
              tooltip: solved ? 'Mark as unsolved' : 'Mark as solved',
              onPressed: () =>
                  c.toggleCodingSolved(p.id).catchError((Object e) {
                    if (context.mounted) showFailure(context, e);
                  }),
              icon: Icon(
                solved
                    ? Icons.check_circle_rounded
                    : Icons.check_circle_outline_rounded,
                color: solved ? forest : null,
              ),
            ),
            const SizedBox(width: 6),
          ],
          bottom: TabBar(
            controller: _tabs,
            tabs: const [
              Tab(
                key: ValueKey('tab-problem-fragment'),
                icon: Icon(Icons.psychology_alt_outlined, size: 18),
                text: 'Problem & Think',
              ),
              Tab(
                key: ValueKey('tab-solution-fragment'),
                icon: Icon(Icons.code_rounded, size: 18),
                text: 'Solution',
              ),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabs,
          children: [_problemFragment(), _solutionFragment(solved, starred)],
        ),
      );
    },
  );

  Widget _problemFragment() {
    final linked = _linkedChapter();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 48),
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
                  Tag(p.categoryLabel),
                  Tag(p.difficulty, color: difficultyColor(p.difficulty)),
                  Tag(
                    p.targetFunction,
                    icon: Icons.functions_rounded,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  if (linked != null)
                    ActionChip(
                      key: const ValueKey('linked-chapter-chip'),
                      avatar: const Icon(Icons.menu_book_outlined, size: 15),
                      label: Text(
                        'Read ${linked.fullLabel}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      onPressed: () => _openLinkedChapter(linked),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                p.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.5,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                p.problemStatement,
                style: const TextStyle(
                  fontFamilyFallback: ['NotoSansBengali'],
                  fontSize: 14,
                  height: 2,
                ),
              ),
              if (p.mathFormula.isNotEmpty) ...[
                const SizedBox(height: 18),
                Panel(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Eyebrow('CORE EQUATION'),
                      const SizedBox(height: 12),
                      HorizontalReadingView(
                        hint: 'সমীকরণের বাকি অংশ দেখতে ডানে-বাঁয়ে সরান।',
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Math.tex(
                            p.mathFormula,
                            textStyle: TextStyle(
                              fontSize: 16,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              const Eyebrow('FULL CODEBASE CONTEXT · IMPLEMENT TARGET FUNCTION'),
              const SizedBox(height: 8),
              const Text(
                'আশেপাশের পুরো কোডবেসটি বুঝে নিন এবং `# TODO` চিহ্নিত ফাংশনটি কীভাবে ইমপ্লিমেন্ট করবেন তা আগে নিজে চিন্তা করুন।',
                style: TextStyle(
                  fontFamilyFallback: ['NotoSansBengali'],
                  fontSize: 12,
                  height: 1.9,
                ),
              ),
              const SizedBox(height: 12),
              CodeBlock(
                title: 'Codebase · TODO: ${p.targetFunction}',
                code: p.codebaseTemplate,
              ),
              const SizedBox(height: 24),
              const Eyebrow('WORKED EXAMPLES'),
              const SizedBox(height: 12),
              for (var i = 0; i < p.examples.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Panel(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Tag('Example ${i + 1}'),
                        const SizedBox(height: 10),
                        SelectableText(
                          'Input: ${p.examples[i].input}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            height: 1.7,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SelectableText(
                          'Output: ${p.examples[i].output}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            height: 1.7,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          p.examples[i].explanation,
                          style: const TextStyle(
                            fontFamilyFallback: ['NotoSansBengali'],
                            fontSize: 12,
                            height: 1.9,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              const Eyebrow('THINK FIRST · ফাংশনটি নিয়ে আগে ভাবুন'),
              const SizedBox(height: 8),
              const Text(
                'সমাধান দেখার আগে এই ফাংশনটির লজিক, শেপ ও Edge Case নিয়ে নিচের প্রশ্নগুলোর উত্তর দিয়ে নিজের ধারণা যাচাই করুন।',
                style: TextStyle(
                  fontFamilyFallback: ['NotoSansBengali'],
                  fontSize: 12,
                  height: 1.9,
                ),
              ),
              const SizedBox(height: 12),
              for (var qi = 0; qi < p.thinkQuestions.length; qi++)
                _thinkQuestionCard(qi, p.thinkQuestions[qi]),
              const SizedBox(height: 16),
              const Eyebrow('PROGRESSIVE HINTS'),
              const SizedBox(height: 10),
              Panel(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                child: Column(
                  children: [
                    for (var hi = 0; hi < p.hints.length; hi++)
                      ExpansionTile(
                        key: ValueKey('coding-hint-$hi'),
                        tilePadding: EdgeInsets.zero,
                        title: Text(
                          'Hint ${hi + 1} · ট্যাপ করে দেখুন',
                          style: const TextStyle(
                            fontFamilyFallback: ['NotoSansBengali'],
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                p.hints[hi],
                                style: const TextStyle(
                                  fontFamilyFallback: ['NotoSansBengali'],
                                  fontSize: 13,
                                  height: 1.9,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const Eyebrow('YOUR PSEUDOCODE & NOTES (OFFLINE)'),
              const SizedBox(height: 10),
              Panel(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      key: const ValueKey('coding-note-field'),
                      controller: _noteCtrl,
                      minLines: 4,
                      maxLines: 10,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontFamilyFallback: ['NotoSansBengali'],
                        fontSize: 12,
                        height: 1.7,
                      ),
                      decoration: const InputDecoration(
                        hintText:
                            'এখানে নিজের pseudocode, invariant বা মূল চিন্তা লিখে রাখুন…',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          key: const ValueKey('coding-note-save'),
                          onPressed: _savingNote ? null : _saveNote,
                          icon: const Icon(Icons.save_outlined, size: 16),
                          label: Text(_savingNote ? 'Saving…' : 'Save notes'),
                        ),
                        if (_noteStatus != null)
                          Text(
                            _noteStatus!,
                            style: const TextStyle(
                              fontFamilyFallback: ['NotoSansBengali'],
                              fontSize: 11,
                              color: forest,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    key: const ValueKey('go-to-solution-tab'),
                    onPressed: () => _tabs.animateTo(1),
                    icon: const Icon(Icons.arrow_forward, size: 17),
                    iconAlignment: IconAlignment.end,
                    label: const Text('Solution Fragment-এ যান'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thinkQuestionCard(int qi, ThinkQuestion q) {
    final chosen = _selectedAnswers[qi];
    final answered = chosen != null;
    final correct = chosen == q.answer;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Panel(
        key: ValueKey('think-q-$qi'),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Tag('Think Question ${qi + 1} / ${p.thinkQuestions.length}'),
            const SizedBox(height: 12),
            Text(
              q.question,
              style: const TextStyle(
                fontFamilyFallback: ['NotoSansBengali'],
                fontSize: 14,
                fontWeight: FontWeight.w800,
                height: 1.8,
              ),
            ),
            const SizedBox(height: 12),
            for (var opt = 0; opt < q.options.length; opt++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    key: ValueKey('think-q-$qi-opt-$opt'),
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      backgroundColor: answered && opt == q.answer
                          ? forest.withValues(alpha: .10)
                          : answered && opt == chosen
                          ? const Color(0xFFB46744).withValues(alpha: .10)
                          : null,
                      side: BorderSide(
                        color: answered && opt == q.answer
                            ? forest
                            : answered && opt == chosen
                            ? const Color(0xFFB46744)
                            : Theme.of(context).dividerColor,
                      ),
                    ),
                    onPressed: () =>
                        setState(() => _selectedAnswers[qi] = opt),
                    child: Text(
                      '${String.fromCharCode(65 + opt)}.  ${q.options[opt]}',
                      style: TextStyle(
                        fontFamilyFallback: const ['NotoSansBengali'],
                        fontSize: 12,
                        height: 1.8,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            if (answered) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: (correct ? forest : const Color(0xFF9C7139))
                      .withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      correct
                          ? 'একদম সঠিক চিন্তা!'
                          : 'ভালো চেষ্টা — মূল যুক্তিটি দেখুন:',
                      style: TextStyle(
                        fontFamilyFallback: const ['NotoSansBengali'],
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: correct ? forest : const Color(0xFF9C7139),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      q.explanation,
                      style: const TextStyle(
                        fontFamilyFallback: ['NotoSansBengali'],
                        fontSize: 12,
                        height: 1.9,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _solutionFragment(bool solved, bool starred) {
    final next = _nextProblem();
    if (!_solutionRevealed && !solved) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 48),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Panel(
              key: const ValueKey('solution-gate-panel'),
              padding: const EdgeInsets.all(26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lock_open_outlined,
                    size: 38,
                    color: forest,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'সমাধান দেখার আগে একটু ভেবে নিন!',
                    style: TextStyle(
                      fontFamilyFallback: ['NotoSansBengali'],
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Solution-টি ইচ্ছাকৃতভাবে আলাদা Fragment-এ রাখা হয়েছে যাতে `${p.targetFunction}` ফাংশনটি নিয়ে আগে নিজে চিন্তা করতে পারেন। আপনি এখন পর্যন্ত ${_selectedAnswers.length} / ${p.thinkQuestions.length}টি Think-First প্রশ্নের উত্তর দিয়েছেন।',
                    style: const TextStyle(
                      fontFamilyFallback: ['NotoSansBengali'],
                      fontSize: 13,
                      height: 1.9,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        key: const ValueKey('reveal-solution-btn'),
                        onPressed: () =>
                            setState(() => _solutionRevealed = true),
                        icon: const Icon(Icons.visibility_outlined, size: 17),
                        label: const Text('Reveal Verified Solution'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _tabs.animateTo(0),
                        icon: const Icon(Icons.arrow_back, size: 16),
                        label: const Text('Problem-এ ফিরে যান'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  const Tag('VERIFIED PYTHON SOLUTION', icon: Icons.verified),
                  Tag(
                    p.targetFunction,
                    icon: Icons.functions_rounded,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              CodeBlock(
                title: 'Full Verified Implementation & Assert Tests',
                code: p.solutionCode,
              ),
              const SizedBox(height: 24),
              const Eyebrow('LINE-BY-LINE WALKTHROUGH'),
              const SizedBox(height: 10),
              Panel(
                padding: const EdgeInsets.all(20),
                child: SelectableText(
                  p.walkthrough,
                  style: const TextStyle(
                    fontFamilyFallback: ['NotoSansBengali'],
                    fontSize: 13.5,
                    height: 2,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Eyebrow('COMPLEXITY ANALYSIS'),
              const SizedBox(height: 10),
              Panel(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Time Complexity: ${p.complexity.time}',
                      style: const TextStyle(
                        fontFamilyFallback: ['NotoSansBengali'],
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Space Complexity: ${p.complexity.space}',
                      style: const TextStyle(
                        fontFamilyFallback: ['NotoSansBengali'],
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Eyebrow('EDGE CASES & INTERVIEW PITFALLS'),
              const SizedBox(height: 10),
              Panel(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final edge in p.edgeCases)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Icon(
                                Icons.warning_amber_rounded,
                                size: 16,
                                color: Color(0xFF9C7139),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                edge,
                                style: const TextStyle(
                                  fontFamilyFallback: ['NotoSansBengali'],
                                  fontSize: 13,
                                  height: 1.9,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    key: const ValueKey('mark-coding-solved'),
                    onPressed: () =>
                        c.toggleCodingSolved(p.id).catchError((Object e) {
                          if (mounted) showFailure(context, e);
                        }),
                    icon: Icon(
                      solved ? Icons.check_circle : Icons.check_circle_outline,
                      size: 18,
                    ),
                    label: Text(
                      solved ? 'Mastered (Solved)' : 'Mark as Solved',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        c.toggleCodingStar(p.id).catchError((Object e) {
                          if (mounted) showFailure(context, e);
                        }),
                    icon: Icon(
                      starred ? Icons.star_rounded : Icons.star_border_rounded,
                      size: 18,
                      color: starred ? const Color(0xFF9C7139) : null,
                    ),
                    label: Text(starred ? 'Starred' : 'Star for Revision'),
                  ),
                  if (next != null)
                    OutlinedButton.icon(
                      key: const ValueKey('next-coding-problem'),
                      onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              CodingProblemPage(controller: c, problem: next),
                        ),
                      ),
                      icon: const Icon(Icons.arrow_forward, size: 16),
                      iconAlignment: IconAlignment.end,
                      label: Text('Next: ${next.badge}'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

