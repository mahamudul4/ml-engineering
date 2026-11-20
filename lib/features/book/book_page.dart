import 'package:flutter/material.dart';

import '../../models/book_part.dart';
import '../../models/curriculum.dart';
import '../../state/learning_controller.dart';
import '../../ui/theme.dart';
import '../coding/coding_arena_page.dart';
import '../viva/hot_questions_page.dart';

/// Offline multi-book library, book-scoped reading paths and full-text search.
class BookDestination {
  final String chapterId;
  final String? lessonId;
  const BookDestination(this.chapterId, [this.lessonId]);
}

class BookPage extends StatefulWidget {
  final LearningController controller;
  const BookPage({super.key, required this.controller});

  @override
  State<BookPage> createState() => _BookPageState();
}

class _BookPageState extends State<BookPage> {
  String query = '';
  bool showTopics = false;
  BookPart? selectedTopic;
  late final Map<String, String> chapterIndex;
  late final Map<String, String> lessonIndex;

  @override
  void initState() {
    super.initState();
    selectedTopic = widget.controller.currentBook;
    lessonIndex = {
      for (final chapter in widget.controller.chapters)
        for (final lesson in chapter.lessons)
          lesson.id: [
            lesson.title,
            lesson.subtitle,
            ...lesson.blocks.map((b) => b.body),
          ].join(' ').toLowerCase(),
    };
    chapterIndex = {
      for (final chapter in widget.controller.chapters)
        chapter.id: [
          chapter.title,
          chapter.label,
          chapter.fullLabel,
          chapter.bookVolume.title,
          chapter.bookVolume.shortTitle,
          chapter.book.part,
          ...chapter.book.outcomes,
          ...chapter.lessons.map((lesson) => lessonIndex[lesson.id]!),
        ].join(' ').toLowerCase(),
    };
  }

  List<Lesson> matchingLessons(Curriculum chapter, String term) => term.isEmpty
      ? []
      : chapter.lessons
            .where((lesson) => lessonIndex[lesson.id]!.contains(term))
            .toList();

  Future<void> _openBook(BookPart part) async {
    final saved = await widget.controller.repository.setting(
      'selected_chapter:${part.id}',
    );
    if (!mounted) return;
    final candidates = widget.controller.chaptersForBook(part);
    final target = candidates.firstWhere(
      (item) => item.id == saved,
      orElse: () => candidates.first,
    );
    Navigator.pop(context, BookDestination(target.id));
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.controller.readingPath;
    final normalized = query.trim().toLowerCase();
    final browsingTopics = showTopics && normalized.isEmpty;
    final matches = path
        .where(
          (chapter) => browsingTopics
              ? selectedTopic?.containsStep(chapter.book.order) ?? false
              : chapterIndex[chapter.id]!.contains(normalized),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('বইসমূহ ও Reading Path')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'শুরু থেকে একটি ধারাবাহিক পথ · ৬টি স্বতন্ত্র বই',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              const Text(
                'পুরো কারিকুলামটি ৬টি স্বতন্ত্র বইয়ে সাজানো—প্রতিটি বই তার নিজস্ব Chapter 1 থেকে শুরু হয়েছে। '
                'নতুন শুরু করলে Book 1 (ML Foundations) থেকে এগোন, অথবা সরাসরি Classical ML, Deep Learning, LLMs কিংবা Recommender Systems বইটি খুলুন।',
                style: TextStyle(height: 1.9),
              ),
              const SizedBox(height: 18),
              TextField(
                key: const ValueKey('book-search'),
                onChanged: (value) => setState(() => query = value),
                decoration: const InputDecoration(
                  labelText: 'সব বই ও অধ্যায়ে Concept বা Code খুঁজুন',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 20),
              if (normalized.isEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('সব বই (Library)'),
                      selected: !showTopics,
                      onSelected: (_) => setState(() => showTopics = false),
                    ),
                    ChoiceChip(
                      label: const Text('Topic Index'),
                      selected: showTopics,
                      onSelected: (_) => setState(() => showTopics = true),
                    ),
                    ActionChip(
                      key: const ValueKey('book-open-coding-arena'),
                      avatar: const Icon(Icons.terminal_rounded, size: 16),
                      label: Text(
                        'Coding Arena (${widget.controller.codingProblems.length})',
                      ),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              CodingArenaPage(controller: widget.controller),
                        ),
                      ),
                    ),
                    ActionChip(
                      key: const ValueKey('book-open-hot-questions'),
                      avatar: const Icon(
                        Icons.local_fire_department_outlined,
                        size: 16,
                      ),
                      label: Text(
                        'FAANG Hot Qs (${widget.controller.hotQuestions.length})',
                      ),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              HotQuestionsPage(controller: widget.controller),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (!browsingTopics) ...[
                  _BookshelfGrid(
                    controller: widget.controller,
                    onOpenBook: _openBook,
                    onInspectBook: (book) => setState(() {
                      showTopics = true;
                      selectedTopic = book;
                    }),
                  ),
                  const SizedBox(height: 22),
                ],
                if (browsingTopics) ...[
                  const SizedBox(height: 4),
                  const Text('যে বইটি বিস্তারিত দেখতে চান, সেটি বেছে নিন:'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final part in BookPart.values)
                        ChoiceChip(
                          label: Text('Book ${part.number} · ${part.shortTitle}'),
                          selected: selectedTopic == part,
                          onSelected: (_) =>
                              setState(() => selectedTopic = part),
                        ),
                    ],
                  ),
                ],
              ],
              if (normalized.isNotEmpty && matches.isEmpty)
                const Text('কোনো অধ্যায় মেলেনি। অন্য Term লিখে খুঁজুন।'),
              for (final part in BookPart.values)
                if (matches.any(
                  (chapter) => part.containsStep(chapter.book.order),
                )) ...[
                  _PartHeading(
                    part: part,
                    showOverview: normalized.isEmpty,
                    onOpenBook: () => _openBook(part),
                  ),
                  for (final chapter in matches.where(
                    (chapter) => part.containsStep(chapter.book.order),
                  ))
                    _chapterCard(context, chapter, part, path, normalized),
                ],
              const SizedBox(height: 20),
              const _NotationGuide(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chapterCard(
    BuildContext context,
    Curriculum chapter,
    BookPart part,
    List<Curriculum> path,
    String normalized,
  ) {
    final lessons = matchingLessons(chapter, normalized);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        key: ValueKey('book-${chapter.id}'),
        title: Text('${part.serialFor(chapter.book.order)} · ${chapter.title}'),
        subtitle: Text(
          '${part.shortTitle} · ${chapter.lessons.length} lessons · ~${chapter.minutes} min',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (lessons.isNotEmpty) ...[
            const Text(
              'মিলে যাওয়া Lessons',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            for (final lesson in lessons)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(lesson.title),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () => Navigator.pop(
                  context,
                  BookDestination(chapter.id, lesson.id),
                ),
              ),
          ],
          Text(chapter.book.purpose, style: const TextStyle(height: 1.9)),
          const SizedBox(height: 12),
          const Text(
            'আগে যা জানা দরকার (Prerequisites)',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          if (chapter.book.prerequisites.isEmpty)
            const Text(
              'শুধু সাধারণ Arithmetic জানলেই হবে—এখান থেকেই শুরু করুন।',
            ),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final id in chapter.book.prerequisites)
                Builder(
                  builder: (context) {
                    final prereq = path.firstWhere((item) => item.id == id);
                    final label = prereq.bookVolume == part
                        ? prereq.label
                        : prereq.fullLabel;
                    return ActionChip(
                      label: Text(label),
                      onPressed: () =>
                          Navigator.pop(context, BookDestination(id)),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          for (final outcome in chapter.book.outcomes)
            Text('• $outcome', style: const TextStyle(height: 1.9)),
          const SizedBox(height: 10),
          const Text(
            'বই বন্ধ করে নিজেকে যাচাই করুন',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          for (final question in chapter.book.recall)
            Text('• $question', style: const TextStyle(height: 1.9)),
          const SizedBox(height: 10),
          Text(chapter.book.bridge, style: const TextStyle(height: 1.9)),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, BookDestination(chapter.id)),
            child: const Text('এই অধ্যায় খুলুন'),
          ),
        ],
      ),
    );
  }
}

class _BookshelfGrid extends StatelessWidget {
  final LearningController controller;
  final ValueChanged<BookPart> onOpenBook;
  final ValueChanged<BookPart> onInspectBook;

  const _BookshelfGrid({
    required this.controller,
    required this.onOpenBook,
    required this.onInspectBook,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumn = constraints.maxWidth >= 640;
        final cards = [
          for (final book in BookPart.values) _buildCard(context, book),
        ];
        if (!twoColumn) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final card in cards)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: card,
                ),
            ],
          );
        }
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final card in cards)
              SizedBox(width: (constraints.maxWidth - 14) / 2, child: card),
          ],
        );
      },
    );
  }

  Widget _buildCard(BuildContext context, BookPart book) {
    final active = controller.currentBook == book;
    final doneLessons = controller.completedLessonsForBook(book);
    final totalLessons = controller.totalLessonsForBook(book);
    final ratio = totalLessons == 0 ? 0.0 : doneLessons / totalLessons;
    return Card(
      key: ValueKey('shelf-${book.id}'),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: active
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).dividerColor,
          width: active ? 1.6 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Tag('BOOK ${book.number} · CH 1–${book.chapterCount}'),
                if (active) const Tag('বর্তমান বই', icon: Icons.check_circle),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              book.title,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              book.subtitle,
              style: const TextStyle(fontSize: 12, height: 1.8),
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: ratio, minHeight: 4),
            ),
            const SizedBox(height: 8),
            Text(
              '${book.chapterCount} chapters · $doneLessons / $totalLessons lessons সম্পন্ন',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  key: ValueKey('open-shelf-${book.id}'),
                  onPressed: () => onOpenBook(book),
                  child: Text(doneLessons > 0 ? 'পড়া চালিয়ে যান' : 'বইটি খুলুন'),
                ),
                TextButton(
                  onPressed: () => onInspectBook(book),
                  child: const Text('অধ্যায় তালিকা'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PartHeading extends StatelessWidget {
  const _PartHeading({
    required this.part,
    required this.showOverview,
    required this.onOpenBook,
  });

  final BookPart part;
  final bool showOverview;
  final VoidCallback onOpenBook;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '${part.label} (Chapters 1–${part.chapterCount})',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            TextButton.icon(
              onPressed: onOpenBook,
              icon: const Icon(Icons.menu_book_outlined, size: 16),
              label: const Text('Chapter 1 থেকে খুলুন'),
            ),
          ],
        ),
        if (showOverview) ...[
          const SizedBox(height: 6),
          Text(part.learn, style: const TextStyle(height: 1.7)),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('আগে কী পড়বেন, শেষে কী করবেন'),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'আগে: ${part.prerequisites}',
                style: const TextStyle(height: 1.7),
              ),
              const SizedBox(height: 8),
              Text(
                'শেষে: ${part.checkpoint}',
                style: const TextStyle(height: 1.7),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}

class ChapterReadingCard extends StatelessWidget {
  final LearningController controller;
  final VoidCallback onOpenBook;
  const ChapterReadingCard({
    super.key,
    required this.controller,
    required this.onOpenBook,
  });

  @override
  Widget build(BuildContext context) {
    final chapter = controller.chapter;
    final bookPart = chapter.bookVolume;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${bookPart.label} · Chapter ${chapter.bookChapterNumber} of ${bookPart.chapterCount}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            chapter.book.purpose,
            style: const TextStyle(height: 1.8, fontSize: 12),
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            key: const ValueKey('open-book'),
            onPressed: onOpenBook,
            icon: const Icon(Icons.library_books_outlined),
            label: const Text('সব বই (Library) ও Prerequisites দেখুন'),
          ),
        ],
      ),
    );
  }
}

class _NotationGuide extends StatelessWidget {
  const _NotationGuide();

  @override
  Widget build(BuildContext context) => const ExpansionTile(
    title: Text('Notation ও শেখার নিয়ম'),
    expandedCrossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'n = sample count, d = feature count; X(n,d) = rows হিসেবে samples; '
        'xᵢ = একটি sample, xⱼ = প্রসঙ্গ অনুযায়ী feature coordinate; w(d) = weights; '
        'ŷ = prediction, y = observed target, θ = সব parameters। '
        'Σ = যোগফল, ∏ = গুণফল, ∂ = partial derivative, ∇ = gradient, '
        '||x||₂ = Euclidean norm, Aᵀ = transpose।\n\n'
        'P(A|B) = B জানা থাকলে A-এর probability; E[X] = expectation; '
        'Var(X) = variance; iid = independent ও একই distribution থেকে sampled। '
        'log = natural logarithm, যদি আলাদা base উল্লেখ করা না থাকে। '
        'একই symbol ভিন্ন বই বা অধ্যায়ে ভিন্ন অর্থ নিতে পারে—প্রথম সংজ্ঞা ও shape দেখে নিন।\n\n'
        'প্রতিটি runnable code snippet-এর input, expected output ও assumptions পড়ুন। '
        'এই অ্যাপ সরাসরি Python execute করে না; তবে code scratchpad ও numeric answer যাচাই করার ব্যবস্থা দেয়। '
        'মূল real-data workflows ও license ফাইলগুলো অফলাইনেই bundled আছে।\n\n'
        'পাঁচটি Mastery ধাপ: ধারণা নিজের ভাষায় ব্যাখ্যা করা, formula derive করা, '
        'solution না দেখে code লেখা, edge case পরীক্ষা করা এবং evidence-এর সীমা বোঝানো।',
        style: TextStyle(height: 1.9),
      ),
      SizedBox(height: 20),
    ],
  );
}
