import 'package:flutter/material.dart';

import '../models/book_part.dart';
import '../models/curriculum.dart';
import '../state/learning_controller.dart';
import 'search_ranking.dart';
import 'theme.dart';

/// Unified destination returned by [showQuickNavigatorSheet].
sealed class QuickNavResult {
  const QuickNavResult();
}

class QuickNavChapter extends QuickNavResult {
  final String chapterId;
  final String? lessonId;
  const QuickNavChapter(this.chapterId, [this.lessonId]);
}

class QuickNavSection extends QuickNavResult {
  /// 0=Learn, 1=Lab, 2=Practice, 3=Notebook, 4=Bookmarks
  final int section;
  const QuickNavSection(this.section);
}

class QuickNavHub extends QuickNavResult {
  /// 'library', 'coding', 'viva'
  final String target;
  const QuickNavHub(this.target);
}

/// Opens the universal Books / Chapters / Lessons / Components navigator sheet.
Future<QuickNavResult?> showQuickNavigatorSheet(
  BuildContext context, {
  required LearningController controller,
  int? activeSection,
}) {
  final wide = MediaQuery.sizeOf(context).width >= 820;
  if (wide) {
    return showDialog<QuickNavResult>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780, maxHeight: 720),
          child: _QuickNavigatorBody(
            controller: controller,
            activeSection: activeSection,
          ),
        ),
      ),
    );
  }
  return showModalBottomSheet<QuickNavResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.90,
      child: _QuickNavigatorBody(
        controller: controller,
        activeSection: activeSection,
      ),
    ),
  );
}

class _QuickNavigatorBody extends StatefulWidget {
  final LearningController controller;
  final int? activeSection;
  const _QuickNavigatorBody({
    required this.controller,
    this.activeSection,
  });

  @override
  State<_QuickNavigatorBody> createState() => _QuickNavigatorBodyState();
}

class _QuickNavigatorBodyState extends State<_QuickNavigatorBody> {
  late BookPart _previewBook;
  String? _expandedChapterId;
  String _query = '';
  final TextEditingController _searchCtrl = TextEditingController();

  LearningController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _previewBook = c.currentBook;
    _expandedChapterId = c.chapter.id;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<(Curriculum, Lesson?)> _searchMatches(String q) {
    final ranked = CurriculumSearch(q).searchCatalog(c.readingPath, limit: 40);
    return [for (final hit in ranked) (hit.chapter, hit.lesson)];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final divider = Theme.of(context).dividerColor;
    final searching = _query.trim().isNotEmpty;
    final results = searching ? _searchMatches(_query) : const <(Curriculum, Lesson?)>[];
    final previewChapters = c.chaptersForBook(_previewBook);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 14, 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: forest.withValues(alpha: isDark ? .26 : .10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.explore_outlined, size: 19, color: primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quick Navigator · দ্রুত যেকোনো জায়গায় যান',
                      style: TextStyle(
                        fontFamilyFallback: ['NotoSansBengali'],
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '৬টি বই · ৫১ অধ্যায় · ৮৯০ Lesson · ৩২৩ Viva · ১২০ Coding',
                      style: TextStyle(
                        fontFamilyFallback: const ['NotoSansBengali'],
                        fontSize: 11,
                        color: muted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close navigator',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: TextField(
            key: const ValueKey('quick-nav-search'),
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'যেকোনো বই, অধ্যায় বা Lesson খুঁজুন (যেমন RSI, XGBoost, RAG, Bellman)…',
              hintStyle: const TextStyle(
                fontFamilyFallback: ['NotoSansBengali'],
                fontSize: 12,
              ),
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: searching
                  ? IconButton(
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.clear_rounded, size: 18),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
            ),
          ),
        ),
        Divider(height: 1, color: divider),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            children: [
              if (searching) ...[
                Eyebrow('SEARCH RESULTS (${results.length})'),
                const SizedBox(height: 10),
                if (results.isEmpty)
                  Panel(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'কোনো শিরোনাম মেলেনি। পুরো কনটেন্ট ও ৫,০৬৯টি Interview Q&A খুঁজতে All Books Library সার্চ ব্যবহার করুন।',
                          style: TextStyle(
                            fontFamilyFallback: ['NotoSansBengali'],
                            fontSize: 12.5,
                            height: 1.8,
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () =>
                              Navigator.pop(context, const QuickNavHub('library')),
                          icon: const Icon(Icons.library_books_outlined, size: 16),
                          label: const Text('All Books Full-Text Search খুলুন'),
                        ),
                      ],
                    ),
                  )
                else
                  for (final hit in results)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: .025),
                        borderRadius: BorderRadius.circular(12),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: divider),
                          ),
                          leading: Icon(
                            hit.$2 == null
                                ? Icons.menu_book_rounded
                                : Icons.article_outlined,
                            size: 20,
                            color: primary,
                          ),
                          title: Text(
                            hit.$2 == null ? hit.$1.title : hit.$2!.title,
                            style: const TextStyle(
                              fontFamilyFallback: ['NotoSansBengali'],
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            hit.$2 == null
                                ? '${hit.$1.bookVolume.label} · ${hit.$1.label} (${hit.$1.lessons.length} lessons)'
                                : '${hit.$1.bookVolume.shortTitle} · ${hit.$1.label} · ${hit.$1.shortTitle}',
                            style: TextStyle(
                              fontFamilyFallback: const ['NotoSansBengali'],
                              fontSize: 11,
                              color: muted,
                            ),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                          onTap: () => Navigator.pop(
                            context,
                            QuickNavChapter(hit.$1.id, hit.$2?.id),
                          ),
                        ),
                      ),
                    ),
              ] else ...[
                const Eyebrow('APP COMPONENTS · দ্রুত টুলে যান'),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _hubPill(
                        context,
                        key: const ValueKey('qnav-hub-library'),
                        icon: Icons.library_books_outlined,
                        label: 'All Books (6)',
                        accent: forest,
                        onTap: () => Navigator.pop(
                          context,
                          const QuickNavHub('library'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _hubPill(
                        context,
                        key: const ValueKey('qnav-hub-coding'),
                        icon: Icons.terminal_rounded,
                        label: 'Coding Arena (${c.codingProblems.length})',
                        accent: const Color(0xFF2D6A8E),
                        onTap: () => Navigator.pop(
                          context,
                          const QuickNavHub('coding'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _hubPill(
                        context,
                        key: const ValueKey('qnav-hub-viva'),
                        icon: Icons.local_fire_department_outlined,
                        label: 'FAANG Hot Qs (${c.hotQuestions.length})',
                        accent: const Color(0xFFB44C3B),
                        onTap: () => Navigator.pop(
                          context,
                          const QuickNavHub('viva'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _hubPill(
                        context,
                        key: const ValueKey('qnav-sec-lab'),
                        icon: Icons.science_outlined,
                        label: 'Interactive Lab',
                        accent: forest,
                        selected: widget.activeSection == 1,
                        onTap: () =>
                            Navigator.pop(context, const QuickNavSection(1)),
                      ),
                      const SizedBox(width: 8),
                      _hubPill(
                        context,
                        key: const ValueKey('qnav-sec-practice'),
                        icon: Icons.quiz_outlined,
                        label: 'Practice & Quiz',
                        accent: const Color(0xFF9C7139),
                        selected: widget.activeSection == 2,
                        onTap: () =>
                            Navigator.pop(context, const QuickNavSection(2)),
                      ),
                      const SizedBox(width: 8),
                      _hubPill(
                        context,
                        key: const ValueKey('qnav-sec-notebook'),
                        icon: Icons.edit_note_rounded,
                        label: 'Notebook',
                        accent: forest,
                        selected: widget.activeSection == 3,
                        onTap: () =>
                            Navigator.pop(context, const QuickNavSection(3)),
                      ),
                      const SizedBox(width: 8),
                      _hubPill(
                        context,
                        key: const ValueKey('qnav-sec-bookmarks'),
                        icon: Icons.bookmark_border_rounded,
                        label: 'Bookmarks',
                        accent: const Color(0xFF9C7139),
                        selected: widget.activeSection == 4,
                        onTap: () =>
                            Navigator.pop(context, const QuickNavSection(4)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Eyebrow('STEP 1 · বই বেছে নিন (৬টি বই)'),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final book in BookPart.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _bookPill(context, book, isDark, divider),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Eyebrow(
                        'STEP 2 · ${_previewBook.label.toUpperCase()} (${previewChapters.length} CHAPTERS)',
                      ),
                    ),
                    Text(
                      '${c.completedLessonsForBook(_previewBook)}/${c.totalLessonsForBook(_previewBook)} done',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final ch in previewChapters)
                  _chapterAccordion(context, ch, isDark, divider, primary, muted),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _hubPill(
    BuildContext context, {
    Key? key,
    required IconData icon,
    required String label,
    required Color accent,
    bool selected = false,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      key: key,
      color: selected
          ? accent.withValues(alpha: isDark ? .28 : .16)
          : accent.withValues(alpha: isDark ? .14 : .08),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? accent
                  : accent.withValues(alpha: isDark ? .35 : .22),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: accent),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bookPill(
    BuildContext context,
    BookPart book,
    bool isDark,
    Color divider,
  ) {
    final active = _previewBook == book;
    final current = c.currentBook == book;
    final done = c.completedLessonsForBook(book);
    final total = c.totalLessonsForBook(book);
    return Material(
      key: ValueKey('qnav-book-${book.id}'),
      color: active
          ? forest.withValues(alpha: isDark ? .28 : .14)
          : Theme.of(context).colorScheme.onSurface.withValues(alpha: .03),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            _previewBook = book;
            final list = c.chaptersForBook(book);
            _expandedChapterId = current
                ? c.chapter.id
                : (list.isNotEmpty ? list.first.id : null);
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? forest : divider),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: active
                      ? forest
                      : forest.withValues(alpha: isDark ? .22 : .10),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'B${book.number}',
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: active ? Colors.white : Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    book.shortTitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${book.chapterCount} ch · $done/$total',
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chapterAccordion(
    BuildContext context,
    Curriculum ch,
    bool isDark,
    Color divider,
    Color primary,
    Color muted,
  ) {
    final isCurrent = c.chapter.id == ch.id;
    final isOpen = _expandedChapterId == ch.id;
    final doneCount = ch.lessons.where((l) => c.completed(l.id)).length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: isCurrent
              ? forest.withValues(alpha: isDark ? .16 : .06)
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: .02),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isCurrent ? forest.withValues(alpha: .6) : divider),
        ),
        child: Column(
          children: [
            InkWell(
              key: ValueKey('qnav-chapter-${ch.id}'),
              borderRadius: BorderRadius.circular(14),
              onTap: () => setState(
                () => _expandedChapterId = isOpen ? null : ch.id,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? forest
                            : forest.withValues(alpha: isDark ? .22 : .10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        ch.bookChapterNumber.toString().padLeft(2, '0'),
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: isCurrent ? Colors.white : primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ch.title,
                            style: const TextStyle(
                              fontFamilyFallback: ['NotoSansBengali'],
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${ch.lessons.length} lessons · $doneCount done${isCurrent ? ' · Current' : ''}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isCurrent ? primary : muted,
                              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      key: ValueKey('qnav-open-${ch.id}'),
                      onPressed: () =>
                          Navigator.pop(context, QuickNavChapter(ch.id)),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      child: const Text('Open', style: TextStyle(fontSize: 11.5)),
                    ),
                    Icon(
                      isOpen
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: muted,
                    ),
                  ],
                ),
              ),
            ),
            if (isOpen) ...[
              Divider(height: 1, color: divider),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
                child: Column(
                  children: [
                    for (var i = 0; i < ch.lessons.length; i++)
                      _lessonRow(context, ch, ch.lessons[i], i, primary, muted),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _lessonRow(
    BuildContext context,
    Curriculum ch,
    Lesson l,
    int idx,
    Color primary,
    Color muted,
  ) {
    final done = c.completed(l.id);
    final marked = c.bookmarked(l.id);
    return InkWell(
      key: ValueKey('qnav-lesson-${l.id}'),
      borderRadius: BorderRadius.circular(8),
      onTap: () => Navigator.pop(context, QuickNavChapter(ch.id, l.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            Icon(
              done ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 16,
              color: done ? forest : muted.withValues(alpha: .6),
            ),
            const SizedBox(width: 9),
            Text(
              '${idx + 1}.',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: muted,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l.title,
                style: const TextStyle(
                  fontFamilyFallback: ['NotoSansBengali'],
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (marked)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(Icons.bookmark_rounded, size: 15, color: primary),
              ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 16, color: muted),
          ],
        ),
      ),
    );
  }
}

