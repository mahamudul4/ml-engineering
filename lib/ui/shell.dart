import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/learning_controller.dart';
import '../models/book_part.dart';
import '../models/curriculum.dart';
import 'rich_prose.dart';
import '../features/lessons/lesson_page.dart';
import '../features/book/book_page.dart';
import '../features/coding/coding_arena_page.dart';
import '../features/viva/hot_questions_page.dart';
import '../features/reinforcement/bellman_lab.dart';
import '../features/practice/practice_page.dart';
import '../features/regression/regression_lab.dart';
import '../features/regression/advanced_regression_labs.dart';
import '../features/regression/polynomial_lab.dart';
import '../features/classification/classification_labs.dart';
import '../features/preparation/preparation_labs.dart';
import '../features/evaluation/evaluation_labs.dart';
import '../features/python/python_labs.dart';
import '../features/mathematics/math_labs.dart';
import '../features/statistics/statistics_labs.dart';
import '../features/trees/tree_labs.dart';
import '../features/ensembles/ensemble_labs.dart';
import '../features/classical/classical_labs.dart';
import '../features/unsupervised/unsupervised_labs.dart';
import '../features/temporal/temporal_labs.dart';
import '../features/capstone/capstone_labs.dart';
import '../features/tensors/tensor_labs.dart';
import '../features/neural/neural_labs.dart';
import '../features/reliable/reliable_labs.dart';
import '../features/vision/vision_labs.dart';
import '../features/sequence/sequence_labs.dart';
import '../features/attention/attention_labs.dart';
import '../features/deep_capstone/deep_capstone_labs.dart';
import '../features/llm/advanced_llm_labs.dart';
import '../features/llm/llm_labs.dart';
import '../features/retrieval/retrieval_labs.dart';
import '../features/rag/rag_labs.dart';
import '../features/adaptation/adaptation_labs.dart';
import '../features/reliability/reliability_labs.dart';
import '../features/generative/generative_labs.dart';
import '../features/diffusion/diffusion_labs.dart';
import '../features/gen_capstone/gen_capstone_labs.dart';
import '../features/recommendation/recommendation_labs.dart';
import '../features/factorization/factor_labs.dart';
import '../features/deep_recommendation/deep_recommendation_labs.dart';
import '../features/recommendation_evaluation/evaluation_labs.dart';
import '../features/recommender_capstone/capstone_labs.dart';
import '../features/feature_systems/feature_labs.dart';
import '../features/mlops/mlops_labs.dart';
import '../features/experimentation/experiment_labs.dart';
import '../features/system_design/design_labs.dart';
import '../features/interview_practice/practice_labs.dart';
import '../features/final_capstone/portfolio_labs.dart';
import 'quick_navigator.dart';
import 'search_ranking.dart';
import 'theme.dart';

class LearningShell extends StatefulWidget {
  final LearningController controller;
  const LearningShell({super.key, required this.controller});
  @override
  State<LearningShell> createState() => _LearningShellState();
}

class _LearningShellState extends State<LearningShell> {
  int section = 0;
  String query = '';
  String noteQuery = '';
  bool allBooksNotes = true;
  bool switching = false;
  final search = TextEditingController();
  final noteSearch = TextEditingController();
  final scroll = ScrollController();
  LearningController get c => widget.controller;
  @override
  void dispose() {
    search.dispose();
    noteSearch.dispose();
    scroll.dispose();
    super.dispose();
  }

  void navigate(int index) {
    setState(() {
      section = index;
      query = '';
      search.clear();
    });
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  void openLesson(Lesson lesson) {
    c.visit(lesson.id).catchError((Object e) {
      if (mounted) showFailure(context, e);
    });
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LessonPage(controller: c, lesson: lesson),
      ),
    );
  }

  Future<void> switchChapter(String id) async {
    if (switching) return;
    setState(() => switching = true);
    try {
      await c.selectChapter(id);
      if (mounted) navigate(0);
    } catch (e) {
      if (mounted) showFailure(context, e);
    }
    if (mounted) setState(() => switching = false);
  }

  Future<void> switchBook(BookPart target) async {
    if (switching || c.currentBook == target) return;
    setState(() => switching = true);
    try {
      await c.selectBook(target);
      if (mounted) navigate(0);
    } catch (e) {
      if (mounted) showFailure(context, e);
    }
    if (mounted) setState(() => switching = false);
  }

  Future<void> openBook() async {
    final destination = await Navigator.of(context).push<BookDestination>(
      MaterialPageRoute(builder: (_) => BookPage(controller: c)),
    );
    if (destination == null || !mounted) return;
    await switchChapter(destination.chapterId);
    if (mounted &&
        c.chapter.id == destination.chapterId &&
        destination.lessonId != null) {
      openLesson(
        c.chapter.lessons.firstWhere(
          (lesson) => lesson.id == destination.lessonId,
        ),
      );
    }
  }

  void openCodingArena() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => CodingArenaPage(controller: c)),
    );
  }

  void openHotQuestions() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => HotQuestionsPage(controller: c)),
    );
  }

  Future<void> _openSearchHit(RankedSearchHit hit) async {
    await switchChapter(hit.chapter.id);
    if (mounted && c.chapter.id == hit.chapter.id && hit.lesson != null) {
      final match = c.chapter.lessons.where((l) => l.id == hit.lesson!.id);
      if (match.isNotEmpty) openLesson(match.first);
    }
  }

  Widget _globalSearchResultsPanel(List<RankedSearchHit> hits, String term) {
    final primary = Theme.of(context).colorScheme.primary;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final divider = Theme.of(context).dividerColor;
    return Panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Eyebrow(
                  'সব ৬টি বই ও ${c.chapters.length} অধ্যায়ে ফলাফল (${hits.length})',
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  search.clear();
                  setState(() => query = '');
                },
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (hits.isEmpty) ...[
            Text(
              '“$term” শিরোনামে মেলেনি। পুরো কনটেন্ট ও ৫,০৬৯টি Q&A খুঁজতে All Books সার্চ খুলুন।',
              style: TextStyle(
                fontFamilyFallback: const ['NotoSansBengali'],
                fontSize: 12,
                color: muted,
                height: 1.7,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: openBook,
              icon: const Icon(Icons.manage_search_rounded, size: 17),
              label: const Text('All Books Full-Text Search খুলুন'),
            ),
          ] else
            for (final hit in hits)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: .025),
                  borderRadius: BorderRadius.circular(11),
                  child: ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                      side: BorderSide(color: divider),
                    ),
                    leading: Icon(
                      hit.lesson == null
                          ? Icons.menu_book_rounded
                          : Icons.article_outlined,
                      size: 19,
                      color: primary,
                    ),
                    title: Text(
                      hit.lesson == null ? hit.chapter.title : hit.lesson!.title,
                      style: const TextStyle(
                        fontFamilyFallback: ['NotoSansBengali'],
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      hit.lesson == null
                          ? '${hit.chapter.bookVolume.label} · ${hit.chapter.label} (${hit.chapter.lessons.length} lessons)'
                          : '${hit.chapter.bookVolume.shortTitle} · ${hit.chapter.label} · ${hit.chapter.shortTitle}',
                      style: TextStyle(
                        fontFamilyFallback: const ['NotoSansBengali'],
                        fontSize: 11,
                        color: muted,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 13,
                    ),
                    onTap: () => _openSearchHit(hit),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Future<void> openQuickNavigator() async {
    final result = await showQuickNavigatorSheet(
      context,
      controller: c,
      activeSection: section,
    );
    if (result == null || !mounted) return;
    switch (result) {
      case QuickNavChapter(:final chapterId, :final lessonId):
        await switchChapter(chapterId);
        if (mounted && c.chapter.id == chapterId && lessonId != null) {
          final match = c.chapter.lessons.where((l) => l.id == lessonId);
          if (match.isNotEmpty) openLesson(match.first);
        }
      case QuickNavSection(:final section):
        navigate(section);
      case QuickNavHub(:final target):
        if (target == 'library') {
          await openBook();
        } else if (target == 'coding') {
          openCodingArena();
        } else if (target == 'viva') {
          openHotQuestions();
        }
    }
  }

  Widget _mobileHubChip({
    Key? key,
    required IconData icon,
    required String label,
    required Color accent,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      key: key,
      color: accent.withValues(alpha: isDark ? .18 : .09),
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: accent.withValues(alpha: isDark ? .38 : .24),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: accent),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontFamilyFallback: const ['NotoSansBengali'],
                  fontSize: 11,
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

  Widget _mobileBookSelector() => Panel(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 7,
          runSpacing: 7,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _mobileHubChip(
              key: const ValueKey('mobile-quick-nav'),
              icon: Icons.explore_outlined,
              label: 'Quick Nav',
              accent: forest,
              onTap: openQuickNavigator,
            ),
            _mobileHubChip(
              icon: Icons.library_books_outlined,
              label: 'সব বই',
              accent: forest,
              onTap: openBook,
            ),
            _mobileHubChip(
              key: const ValueKey('open-coding-arena'),
              icon: Icons.terminal_rounded,
              label: 'Coding Arena',
              accent: const Color(0xFF2D6A8E),
              onTap: openCodingArena,
            ),
            _mobileHubChip(
              key: const ValueKey('open-hot-questions'),
              icon: Icons.local_fire_department_outlined,
              label: 'Hot Qs',
              accent: const Color(0xFFB44C3B),
              onTap: openHotQuestions,
            ),
            _mobileHubChip(
              icon: Icons.bookmark_border_rounded,
              label: 'Bookmarks',
              accent: const Color(0xFF9C7139),
              onTap: () => navigate(4),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Eyebrow('বই নির্বাচন করুন (৬টি বই)'),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final book in BookPart.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    key: ValueKey('book-chip-${book.id}'),
                    label: Text(
                      '${book.number}. ${book.shortTitle}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    selected: c.currentBook == book,
                    onSelected: switching ? null : (_) => switchBook(book),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _chapterPicker(),
      ],
    ),
  );

  Widget _chapterPicker() {
    final prev = c.previousChapter;
    final next = c.nextChapter;
    return Row(
      children: [
        IconButton(
          key: const ValueKey('prev-chapter-btn'),
          tooltip: prev == null ? null : 'Previous: ${prev.shortTitle}',
          visualDensity: VisualDensity.compact,
          onPressed: switching || prev == null
              ? null
              : () => switchChapter(prev.id),
          icon: const Icon(Icons.chevron_left_rounded, size: 22),
        ),
        Expanded(
          child: DropdownButtonFormField<String>(
            key: ValueKey('chapter-picker-${c.currentBook.id}-${c.chapter.id}'),
            initialValue: c.chapter.id,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: '${c.currentBook.shortTitle} · অধ্যায় বেছে নিন',
              prefixIcon: const Icon(Icons.auto_stories_outlined),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            selectedItemBuilder: (context) => [
              for (final ch in c.currentBookChapters)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    '${ch.bookChapterNumber.toString().padLeft(2, '0')} · ${ch.shortTitle}',
                    semanticsLabel: '${ch.fullLabel}: ${ch.title}',
                    style: const TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            items: [
              for (final ch in c.currentBookChapters)
                DropdownMenuItem(
                  value: ch.id,
                  child: Text(
                    '${ch.bookChapterNumber.toString().padLeft(2, '0')} · ${ch.title}',
                    style: const TextStyle(fontSize: 12),
                    maxLines: 2,
                  ),
                ),
            ],
            onChanged: switching
                ? null
                : (id) {
                    if (id != null) switchChapter(id);
                  },
          ),
        ),
        IconButton(
          key: const ValueKey('next-chapter-btn'),
          tooltip: next == null ? null : 'Next: ${next.shortTitle}',
          visualDensity: VisualDensity.compact,
          onPressed: switching || next == null
              ? null
              : () => switchChapter(next.id),
          icon: const Icon(Icons.chevron_right_rounded, size: 22),
        ),
      ],
    );
  }

  Widget _chapterLink(Curriculum ch) {
    final done = ch.lessons.where((l) => c.completed(l.id)).length;
    final active = ch.id == c.chapter.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Material(
        color: active ? forest.withValues(alpha: .11) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          enabled: !switching,
          onTap: () => switchChapter(ch.id),
          leading: Text(
            ch.bookChapterNumber.toString().padLeft(2, '0'),
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: active
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          title: Text(
            ch.shortTitle,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '$done/${ch.lessons.length} lessons · ${ch.label}',
            style: const TextStyle(fontSize: 9.5),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    return Scaffold(
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: section > 3 ? 3 : section,
              onDestinationSelected: navigate,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.auto_stories_outlined),
                  selectedIcon: Icon(Icons.auto_stories),
                  label: 'Learn',
                ),
                NavigationDestination(
                  icon: Icon(Icons.science_outlined),
                  selectedIcon: Icon(Icons.science),
                  label: 'Lab',
                ),
                NavigationDestination(
                  icon: Icon(Icons.code_rounded),
                  selectedIcon: Icon(Icons.code_rounded),
                  label: 'Practice',
                ),
                NavigationDestination(
                  icon: Icon(Icons.edit_note_rounded),
                  selectedIcon: Icon(Icons.edit_note_rounded),
                  label: 'Notebook',
                ),
              ],
            ),
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (wide) _sidebar(),
            Expanded(
              child: Column(
                children: [
                  _topbar(wide),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scroll,
                      padding: EdgeInsets.fromLTRB(
                        wide ? 38 : 20,
                        wide ? 32 : 20,
                        wide ? 38 : 20,
                        40,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1320),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!wide) ...[
                                _mobileBookSelector(),
                                const SizedBox(height: 20),
                              ],
                              _body(wide),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topbar(bool wide) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final prev = c.previousChapter;
    final next = c.nextChapter;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: wide ? 28 : 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                if (!wide) ...[
                  const Icon(Icons.hub_rounded, color: forest, size: 22),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Material(
                    key: const ValueKey('topbar-quick-nav'),
                    color: forest.withValues(alpha: isDark ? .20 : .08),
                    borderRadius: BorderRadius.circular(11),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(11),
                      onTap: openQuickNavigator,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: wide ? 12 : 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: forest.withValues(alpha: isDark ? .42 : .24),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.explore_outlined, size: 16, color: primary),
                            const SizedBox(width: 7),
                            Flexible(
                              child: Text(
                                wide
                                    ? 'Book ${c.currentBook.number} · ${c.currentBook.shortTitle}  ›  Ch ${c.chapter.bookChapterNumber} · ${c.chapter.shortTitle}'
                                    : 'B${c.currentBook.number} · Ch ${c.chapter.bookChapterNumber} · ${c.chapter.shortTitle}',
                                style: const TextStyle(
                                  fontFamilyFallback: ['NotoSansBengali'],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (wide) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: prev == null ? null : 'Previous: ${prev.shortTitle}',
                    visualDensity: VisualDensity.compact,
                    onPressed: switching || prev == null
                        ? null
                        : () => switchChapter(prev.id),
                    icon: const Icon(Icons.chevron_left_rounded, size: 20),
                  ),
                  IconButton(
                    tooltip: next == null ? null : 'Next: ${next.shortTitle}',
                    visualDensity: VisualDensity.compact,
                    onPressed: switching || next == null
                        ? null
                        : () => switchChapter(next.id),
                    icon: const Icon(Icons.chevron_right_rounded, size: 20),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (wide) ...[
            SizedBox(
              width: 245,
              height: 38,
              child: TextField(
                key: const ValueKey('shell-lesson-search'),
                controller: search,
                onChanged: (v) => setState(() {
                  query = v;
                  section = 0;
                }),
                decoration: InputDecoration(
                  hintText: 'Search all 6 books (e.g. RSI)…',
                  hintStyle: const TextStyle(fontSize: 12),
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: query.trim().isNotEmpty
                      ? IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            search.clear();
                            setState(() => query = '');
                          },
                          icon: const Icon(Icons.close_rounded, size: 16),
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          IconButton(
            key: const ValueKey('topbar-global-search'),
            tooltip: 'Search all 6 books, 890 lessons & 5,069 Q&As',
            visualDensity: VisualDensity.compact,
            onPressed: openBook,
            icon: const Icon(Icons.manage_search_rounded, size: 21),
          ),
          IconButton(
            tooltip: 'Toggle light / dark mode',
            visualDensity: VisualDensity.compact,
            onPressed: () => c.toggleTheme().catchError((Object e) {
              if (mounted) showFailure(context, e);
            }),
            icon: Icon(
              c.themeMode == ThemeMode.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebar() => Container(
    width: 264,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border(right: BorderSide(color: Theme.of(context).dividerColor)),
    ),
    child: LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight),
          child: IntrinsicHeight(child: _sidebarContent()),
        ),
      ),
    ),
  );

  Widget _sidebarContent() => Padding(
    padding: const EdgeInsets.fromLTRB(18, 28, 18, 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 13),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: forest,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.hub_rounded, color: lime, size: 24),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'mlpath',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.2,
                    ),
                  ),
                ),
              ),
              const Text(' /', style: TextStyle(fontSize: 29, color: forest)),
            ],
          ),
        ),
        const SizedBox(height: 9),
        const Padding(
          padding: EdgeInsets.only(left: 14),
          child: Text(
            'Small steps. Deep understanding.',
            style: TextStyle(fontSize: 9.5),
          ),
        ),
        const SizedBox(height: 43),
        const Padding(
          padding: EdgeInsets.only(left: 14),
          child: Eyebrow('WORKSPACE'),
        ),
        const SizedBox(height: 15),
        _nav(0, Icons.auto_stories_outlined, 'My learning'),
        _nav(1, Icons.science_outlined, 'Interactive lab'),
        _nav(2, Icons.code_rounded, 'Practice studio'),
        _nav(3, Icons.edit_note_rounded, 'My notebook'),
        _nav(4, Icons.bookmark_border_rounded, 'Bookmarks'),
        Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            child: InkWell(
              borderRadius: BorderRadius.circular(9),
              onTap: openBook,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.library_books_outlined,
                      size: 19,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'All books (Library)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            child: InkWell(
              key: const ValueKey('sidebar-coding-arena'),
              borderRadius: BorderRadius.circular(9),
              onTap: openCodingArena,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.terminal_rounded,
                      size: 19,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Coding Arena (${c.codingProblems.length})',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            child: InkWell(
              key: const ValueKey('sidebar-hot-questions'),
              borderRadius: BorderRadius.circular(9),
              onTap: openHotQuestions,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.local_fire_department_outlined,
                      size: 19,
                      color: Color(0xFFB44C3B),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'FAANG Hot Qs (${c.hotQuestions.length})',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Padding(
          padding: EdgeInsets.only(left: 14),
          child: Eyebrow('BOOKS (৬টি বই)'),
        ),
        const SizedBox(height: 10),
        for (final book in BookPart.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Material(
              key: ValueKey('sidebar-book-${book.id}'),
              color: c.currentBook == book
                  ? forest.withValues(alpha: .10)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              child: InkWell(
                borderRadius: BorderRadius.circular(9),
                onTap: switching ? null : () => switchBook(book),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'B${book.number}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: c.currentBook == book
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          book.shortTitle,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: c.currentBook == book
                                ? FontWeight.w800
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 22),
        Padding(
          padding: const EdgeInsets.only(left: 14),
          child: Eyebrow('${c.currentBook.shortTitle.toUpperCase()} CHAPTERS'),
        ),
        const SizedBox(height: 12),
        for (final ch in c.currentBookChapters) _chapterLink(ch),
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: forest.withValues(alpha: .06),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.spa_outlined, color: forest, size: 25),
              const SizedBox(height: 12),
              const Text(
                'Built for your pace.',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 7),
              const Text(
                'No streaks to chase. Just a little more understanding, every day.',
                style: TextStyle(fontSize: 10, height: 1.8),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 6,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      '100% offline. Always yours.',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const Padding(
          padding: EdgeInsets.only(left: 12),
          child: Text(
            'LEARN IN BANGLA. THINK IN ML.',
            style: TextStyle(
              fontSize: 8,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _nav(int index, IconData icon, String text) {
    final active = section == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Material(
        color: active ? forest.withValues(alpha: .09) : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: () => navigate(index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 19,
                  color: active
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                ),
                if (active) ...[
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: forest,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(bool wide) {
    if (section == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading(
            'Learn by doing.',
            'Turn the knobs. Watch the mathematics come alive.',
          ),
          const SizedBox(height: 24),
          if (c.chapter.lab == 'optimization') ...[
            OptimizationLab(key: ValueKey('optimizer-${c.chapter.id}')),
            const SizedBox(height: 24),
            const MultipleFeatureLab(),
            const SizedBox(height: 24),
            const PolynomialLab(),
          ] else if (c.chapter.lab == 'classification') ...[
            const ClassificationLab(),
            const SizedBox(height: 24),
            const ThresholdLab(),
          ] else if (c.chapter.lab == 'reinforcement') ...[
            const BellmanLab(),
          ] else if (c.chapter.lab == 'final_capstone') ...[
            const PortfolioEvidenceLab(),
            const SizedBox(height: 24),
            const PortfolioAuditLab(),
            const SizedBox(height: 24),
            MockDefenseLab(controller: c),
          ] else if (c.chapter.lab == 'interview_practice') ...[
            const TopKPracticeLab(),
            const SizedBox(height: 24),
            const SqlInterviewLab(),
            const SizedBox(height: 24),
            const MetricDebugLab(),
          ] else if (c.chapter.lab == 'system_design') ...[
            const ArchitectureCapacityLab(),
            const SizedBox(height: 24),
            const SelectiveReviewLab(),
            const SizedBox(height: 24),
            const CaseFailureLab(),
          ] else if (c.chapter.lab == 'experimentation') ...[
            const TrialInferenceLab(),
            const SizedBox(height: 24),
            const ExperimentDesignLab(),
            const SizedBox(height: 24),
            const ObservationalAuditLab(),
          ] else if (c.chapter.lab == 'mlops') ...[
            const ReleaseRoutingLab(),
            const SizedBox(height: 24),
            const MonitoringDriftLab(),
            const SizedBox(height: 24),
            const SLOIncidentLab(),
          ] else if (c.chapter.lab == 'feature_systems') ...[
            const PointInTimeFeatureLab(),
            const SizedBox(height: 24),
            const PipelineReplayLab(),
            const SizedBox(height: 24),
            const FeatureConsistencyLab(),
          ] else if (c.chapter.lab == 'recommender_capstone') ...[
            const CapstoneRetrievalLab(),
            const SizedBox(height: 24),
            const CapstoneEvaluationLab(),
            const SizedBox(height: 24),
            const CapstoneServingLab(),
          ] else if (c.chapter.lab == 'recommendation_evaluation') ...[
            const PairedEvaluationLab(),
            const SizedBox(height: 24),
            const DiversityRerankingLab(),
            const SizedBox(height: 24),
            const ExposureExperimentLab(),
          ] else if (c.chapter.lab == 'deep_recommendation') ...[
            const DeepRetrievalLab(),
            const SizedBox(height: 24),
            const ContrastiveBatchLab(),
            const SizedBox(height: 24),
            const DeepRankingAuditLab(),
          ] else if (c.chapter.lab == 'factorization') ...[
            const FactorWorkbench(),
            const SizedBox(height: 24),
            const ALSUpdateLab(),
            const SizedBox(height: 24),
            const RankingLossLab(),
          ] else if (c.chapter.lab == 'recommendation') ...[
            const FeedbackBaselineLab(),
            const SizedBox(height: 24),
            const RecommendationWorkbench(),
            const SizedBox(height: 24),
            const RecommendationEvaluationLab(),
          ] else if (c.chapter.lab == 'gen_capstone') ...[
            const EvidenceWorkbench(),
            const SizedBox(height: 24),
            const CapstoneScorecard(),
            const SizedBox(height: 24),
            const CapstoneReleaseAudit(),
          ] else if (c.chapter.lab == 'diffusion') ...[
            const ForwardNoiseLab(),
            const SizedBox(height: 24),
            const ReverseSamplingLab(),
            const SizedBox(height: 24),
            const MultimodalAlignmentLab(),
          ] else if (c.chapter.lab == 'generative') ...[
            const VaeObjectiveLab(),
            const SizedBox(height: 24),
            const LatentSpaceLab(),
            const SizedBox(height: 24),
            const GanGameLab(),
          ] else if (c.chapter.lab == 'reliability') ...[
            if (c.chapter.id == 'chapter_42') ...[
              const PassAtKLab(),
              const SizedBox(height: 24),
            ],
            const EvaluationScoreLab(),
            const SizedBox(height: 24),
            const SelectiveRiskLab(),
            const SizedBox(height: 24),
            const ServingReplayLab(),
          ] else if (c.chapter.lab == 'adaptation') ...[
            const ResponseMaskLab(),
            const SizedBox(height: 24),
            const LoRAUpdateLab(),
            const SizedBox(height: 24),
            const AdaptationAuditLab(),
          ] else if (c.chapter.lab == 'rag') ...[
            const RAGChunkLab(),
            const SizedBox(height: 24),
            const RAGPipelineLab(),
            const SizedBox(height: 24),
            const RAGEvidenceAuditLab(),
          ] else if (c.chapter.lab == 'retrieval') ...[
            const EmbeddingGeometryLab(),
            const SizedBox(height: 24),
            const SemanticSearchLab(),
            const SizedBox(height: 24),
            const RetrievalEvaluationLab(),
          ] else if (c.chapter.lab == 'llm') ...[
            if (c.chapter.id == 'chapter_43') ...[
              const ActivationPatchLab(),
              const SizedBox(height: 24),
            ],
            const TokenizerLab(),
            const SizedBox(height: 24),
            const LanguageObjectiveLab(),
            const SizedBox(height: 24),
            const LLMDecodingLab(),
          ] else if (c.chapter.lab == 'deep_capstone') ...[
            const DeepExperimentLab(),
            const SizedBox(height: 24),
            const DeepPolicyLab(),
            const SizedBox(height: 24),
            const DeepArtifactLab(),
          ] else if (c.chapter.lab == 'attention') ...[
            const AttentionLab(),
            const SizedBox(height: 24),
            const AttentionMaskLab(),
            const SizedBox(height: 24),
            const TransformerBlockLab(),
          ] else if (c.chapter.lab == 'sequence') ...[
            const RecurrentLab(),
            const SizedBox(height: 24),
            const PaddingLab(),
            const SizedBox(height: 24),
            const SequenceForecastLab(),
          ] else if (c.chapter.lab == 'vision') ...[
            const ConvolutionLab(),
            const SizedBox(height: 24),
            const PoolingLab(),
            const SizedBox(height: 24),
            const TransferLab(),
          ] else if (c.chapter.lab == 'reliable') ...[
            const OptimizerLab(),
            const SizedBox(height: 24),
            const NormalizationLab(),
            const SizedBox(height: 24),
            const ResumeLab(),
          ] else if (c.chapter.lab == 'neural') ...[
            const ForwardLab(),
            const SizedBox(height: 24),
            const BackpropLab(),
            const SizedBox(height: 24),
            const TrainingLab(),
          ] else if (c.chapter.lab == 'tensors') ...[
            const TensorLayoutLab(),
            const SizedBox(height: 24),
            const BroadcastLab(),
            const SizedBox(height: 24),
            const AutogradLab(),
          ] else if (c.chapter.lab == 'capstone') ...[
            const ExperimentLab(),
            const SizedBox(height: 24),
            const DecisionLab(),
            const SizedBox(height: 24),
            const PipelineLab(),
          ] else if (c.chapter.lab == 'temporal') ...[
            const AnomalyLab(),
            const SizedBox(height: 24),
            const ForecastLab(),
            const SizedBox(height: 24),
            const BacktestLab(),
          ] else if (c.chapter.lab == 'unsupervised') ...[
            const KMeansLab(),
            const SizedBox(height: 24),
            const DensityLab(),
            const SizedBox(height: 24),
            const PcaLab(),
          ] else if (c.chapter.lab == 'classical') ...[
            const SvmLab(),
            const SizedBox(height: 24),
            const KnnLab(),
            const SizedBox(height: 24),
            const NaiveBayesLab(),
          ] else if (c.chapter.lab == 'ensembles') ...[
            const BaggingLab(),
            const SizedBox(height: 24),
            const BoostingLab(),
          ] else if (c.chapter.lab == 'trees') ...[
            const SplitLab(),
            const SizedBox(height: 24),
            const PruningLab(),
          ] else if (c.chapter.lab == 'statistics') ...[
            const BayesLab(),
            const SizedBox(height: 24),
            const CoverageLab(),
          ] else if (c.chapter.lab == 'mathematics') ...[
            const ProjectionLab(),
            const SizedBox(height: 24),
            const CurvatureLab(),
          ] else if (c.chapter.lab == 'python') ...[
            const BroadcastingLab(),
            const SizedBox(height: 24),
            const IteratorLab(),
          ] else if (c.chapter.lab == 'evaluation') ...[
            const FoldLab(),
            const SizedBox(height: 24),
            const BootstrapLab(),
          ] else if (c.chapter.lab == 'preparation') ...[
            const PreprocessingLab(),
            const SizedBox(height: 24),
            const EncodingLab(),
          ] else
            const RegressionLab(),
        ],
      );
    }
    if (section == 2) {
      return PracticePage(key: ValueKey(c.chapter.id), controller: c);
    }
    if (section >= 3) return _notebook(section == 4);
    return _learn(wide);
  }

  Widget _heading(String title, String subtitle) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: TextStyle(
          fontSize: MediaQuery.sizeOf(context).width < 500 ? 28 : 32,
          fontFamily: RegExp(r'[\u0980-\u09FF]').hasMatch(title)
              ? 'NotoSansBengali'
              : 'Manrope',
          fontWeight: FontWeight.w700,
          letterSpacing: RegExp(r'[\u0980-\u09FF]').hasMatch(title) ? 0 : -1.1,
        ),
      ),
      const SizedBox(height: 9),
      Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          height: 1.8,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  );

  Widget _learn(bool wide) {
    final trimmedQuery = query.trim();
    final globalHits = trimmedQuery.isEmpty
        ? const <RankedSearchHit>[]
        : CurriculumSearch(trimmedQuery).searchCatalog(c.readingPath, limit: 25);
    final filtered = c.chapter.lessons
        .where(
          (l) => '${l.title} ${l.subtitle}'.toLowerCase().contains(
            trimmedQuery.toLowerCase(),
          ),
        )
        .toList();
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (wide && trimmedQuery.isNotEmpty) ...[
          _globalSearchResultsPanel(globalHits, trimmedQuery),
          const SizedBox(height: 22),
        ],
        _hero(wide),
        const SizedBox(height: 25),
        _stats(),
        const SizedBox(height: 18),
        ChapterReadingCard(controller: c, onOpenBook: openBook),
        const SizedBox(height: 32),
        Row(
          children: [
            const Expanded(
              child: Text(
                'এই অধ্যায়ে যা শিখবেন',
                style: TextStyle(
                  fontFamily: 'NotoSansBengali',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ),
            Text(
              '${c.chapter.lessons.length} lessons',
              style: const TextStyle(fontSize: 11),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.list_rounded, size: 18),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          'ধারণা বুঝে নিন, তারপর উদাহরণ ও অনুশীলনে মিলিয়ে দেখুন।',
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 18),
        if (!wide) ...[
          TextField(
            key: const ValueKey('shell-lesson-search'),
            controller: search,
            onChanged: (v) => setState(() => query = v),
            decoration: InputDecoration(
              hintText: 'Search all 6 books & lessons (e.g. RSI)…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: trimmedQuery.isNotEmpty
                  ? IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        search.clear();
                        setState(() => query = '');
                      },
                      icon: const Icon(Icons.close_rounded, size: 18),
                    )
                  : null,
              hintStyle: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),
          if (trimmedQuery.isNotEmpty) ...[
            _globalSearchResultsPanel(globalHits, trimmedQuery),
            const SizedBox(height: 18),
          ],
        ],
        if (filtered.isEmpty && trimmedQuery.isEmpty)
          const Panel(
            child: Text('No lessons found. Try “training” or “regression”.'),
          ),
        for (final l in filtered)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _lessonTile(l),
          ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(19),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.eco_outlined, size: 20, color: forest),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'ধারণা → mathematics → code → practice → interview defense।\nReading path থেকে পরের chapter ও prerequisite দেখে নিন।',
                  style: TextStyle(fontSize: 11, height: 1.9),
                ),
              ),
            ],
          ),
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: Eyebrow('আজ কী শিখবেন')),
            if (wide)
              const Text(
                'বাংলায় শিখি, গভীরভাবে বুঝি।',
                style: TextStyle(
                  fontFamily: 'NotoSansBengali',
                  fontSize: 11,
                  color: forest,
                ),
              ),
          ],
        ),
        const SizedBox(height: 13),
        _heading(
          'এক ধাপ করে বুঝে শিখি।',
          'ধারণা বুঝুন, হিসাব মিলিয়ে দেখুন, তারপর নিজের হাতে code লিখুন।',
        ),
        const SizedBox(height: 28),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: content),
              const SizedBox(width: 26),
              SizedBox(width: 258, child: _aside()),
            ],
          )
        else ...[
          content,
          const SizedBox(height: 24),
          _aside(),
        ],
      ],
    );
  }

  Widget _hero(bool wide) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF233C2C) : const Color(0xFFEDF2E4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: dark ? const Color(0xFF3B5541) : const Color(0xFFDDE6D3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(27),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                Tag(c.chapter.badge, icon: Icons.auto_stories_outlined),
                Tag(c.chapter.difficulty),
              ],
            ),
            const SizedBox(height: 23),
            LayoutBuilder(
              builder: (context, box) {
                final copy = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.chapter.displayTitle,
                      style: TextStyle(
                        fontSize: box.maxWidth > 500 ? 31 : 28,
                        height: 1.23,
                        letterSpacing: -1.1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      c.chapter.subtitle,
                      style: TextStyle(
                        fontFamily: 'NotoSansBengali',
                        fontSize: 12,
                        height: 1.9,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      c.chapter.description,
                      style: const TextStyle(fontSize: 11, height: 1.9),
                    ),
                  ],
                );
                return box.maxWidth > 550
                    ? Row(
                        children: [
                          Expanded(flex: 3, child: copy),
                          const SizedBox(width: 16),
                          Expanded(flex: 2, child: _heroGraph(dark)),
                        ],
                      )
                    : copy;
              },
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 13,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: () => openLesson(c.nextLesson),
                  label: Text(
                    c.completedCount == 0
                        ? 'Start learning'
                        : c.completedCount == c.chapter.lessons.length
                        ? 'Revisit chapter'
                        : 'Continue learning',
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                  iconAlignment: IconAlignment.end,
                ),
                Text(
                  '${c.chapter.lessons.length} lessons  ·  ~${c.chapter.minutes} min',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: LinearProgressIndicator(
                      value: c.completedCount / c.chapter.lessons.length,
                      backgroundColor: forest.withValues(alpha: .12),
                      color: dark ? lime : forest,
                      minHeight: 4,
                    ),
                  ),
                ),
                const SizedBox(width: 13),
                Text(
                  '${c.completedCount} of ${c.chapter.lessons.length} completed',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroGraph(bool dark) => Column(
    children: [
      SizedBox(
        height: 160,
        child: c.chapter.lab == 'reinforcement'
            ? Icon(
                Icons.alt_route_rounded,
                color: dark ? lime : forest,
                size: 90,
              )
            : c.chapter.lab == 'final_capstone'
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Icon(
                    Icons.folder_open_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.fact_check_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.record_voice_over_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                ],
              )
            : c.chapter.lab == 'interview_practice'
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Icon(Icons.sort, color: dark ? lime : forest, size: 34),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.table_chart_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.bug_report_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                ],
              )
            : c.chapter.lab == 'system_design'
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Icon(
                    Icons.account_tree_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.calculate_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.rule_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                ],
              )
            : c.chapter.lab == 'experimentation'
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Icon(
                    Icons.shuffle_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.science_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.rule_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                ],
              )
            : c.chapter.lab == 'mlops'
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.monitor_heart_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.restart_alt_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                ],
              )
            : c.chapter.lab == 'feature_systems'
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Icon(
                    Icons.history_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.sync_alt_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.rule_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                ],
              )
            : c.chapter.lab == 'recommender_capstone'
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Icon(
                    Icons.hub_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.fact_check_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.inventory_2_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                ],
              )
            : c.chapter.lab == 'recommendation_evaluation'
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Icon(
                    Icons.analytics_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.hub_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.science_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                ],
              )
            : c.chapter.lab == 'deep_recommendation'
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Icon(
                    Icons.account_tree_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.filter_alt_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.analytics_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                ],
              )
            : c.chapter.lab == 'factorization'
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Icon(Icons.grid_on, color: dark ? lime : forest, size: 34),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.calculate_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.compare_arrows,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                ],
              )
            : c.chapter.lab == 'recommendation'
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Icon(
                    Icons.movie_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.people_outline,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.format_list_numbered,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                ],
              )
            : c.chapter.lab == 'gen_capstone'
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Icon(
                    Icons.account_tree_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.analytics_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.fact_check_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                ],
              )
            : c.chapter.lab == 'diffusion'
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Icon(Icons.grain, color: dark ? lime : forest, size: 34),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.auto_awesome,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.compare_arrows,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                ],
              )
            : c.chapter.lab == 'generative'
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Icon(Icons.blur_on, color: dark ? lime : forest, size: 34),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(Icons.grid_view, color: dark ? lime : forest, size: 34),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.compare_arrows,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                ],
              )
            : c.chapter.lab == 'reliability'
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Icon(
                    Icons.analytics_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.filter_alt_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.speed_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                ],
              )
            : c.chapter.lab == 'adaptation'
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Icon(
                    Icons.rule_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.layers_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.fact_check_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                ],
              )
            : c.chapter.lab == 'rag'
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Icon(
                    Icons.source_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.account_tree_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.fact_check_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                ],
              )
            : c.chapter.lab == 'retrieval'
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Icon(
                    Icons.scatter_plot_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.manage_search_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.fact_check_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                ],
              )
            : c.chapter.lab == 'llm'
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Icon(
                    Icons.text_fields_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.memory_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.auto_awesome_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                ],
              )
            : c.chapter.lab == 'deep_capstone'
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Icon(
                    Icons.science_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.tune_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.inventory_2_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                ],
              )
            : c.chapter.lab == 'attention'
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Icon(
                    Icons.grid_on_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.filter_alt_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.account_tree_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                ],
              )
            : c.chapter.lab == 'sequence'
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Icon(Icons.timeline, color: dark ? lime : forest, size: 34),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.memory_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(Icons.show_chart, color: dark ? lime : forest, size: 34),
                ],
              )
            : c.chapter.lab == 'vision'
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Icon(
                    Icons.grid_on_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.view_module_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.swap_horiz_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                ],
              )
            : c.chapter.lab == 'reliable'
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Icon(
                    Icons.tune_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.view_array_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.restore_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                ],
              )
            : c.chapter.lab == 'neural'
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Icon(
                    Icons.account_tree_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.route_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.show_chart_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                ],
              )
            : c.chapter.lab == 'tensors'
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Icon(
                    Icons.grid_on_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.view_array_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.route_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                ],
              )
            : c.chapter.lab == 'capstone'
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Icon(
                    Icons.science_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.tune_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.account_tree_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                ],
              )
            : c.chapter.lab == 'temporal'
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Icon(
                    Icons.radar_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.timeline_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.date_range_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                ],
              )
            : c.chapter.lab == 'unsupervised'
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Icon(
                    Icons.scatter_plot_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.hub_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.compress_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                ],
              )
            : c.chapter.lab == 'classical'
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Icon(
                    Icons.linear_scale,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.scatter_plot_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.account_tree_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                ],
              )
            : c.chapter.lab == 'ensembles'
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Icon(
                    Icons.hub_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.forest_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.stacked_line_chart,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                ],
              )
            : c.chapter.lab == 'trees'
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Icon(Icons.call_split, color: dark ? lime : forest, size: 34),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.account_tree_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(Icons.rule, color: dark ? lime : forest, size: 34),
                ],
              )
            : c.chapter.lab == 'statistics'
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Icon(
                    Icons.account_tree_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.align_horizontal_center,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.analytics_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                ],
              )
            : c.chapter.lab == 'mathematics'
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Icon(Icons.open_with, color: dark ? lime : forest, size: 34),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(Icons.functions, color: dark ? lime : forest, size: 34),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.multiline_chart,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                ],
              )
            : c.chapter.lab == 'python'
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Icon(
                    Icons.grid_on_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(Icons.code, color: dark ? lime : forest, size: 34),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.check_circle_outline,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                ],
              )
            : c.chapter.lab == 'evaluation'
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Icon(Icons.call_split, color: dark ? lime : forest, size: 34),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(Icons.search, color: dark ? lime : forest, size: 34),
                  Icon(
                    Icons.arrow_forward,
                    color: dark ? lime : forest,
                    size: 16,
                  ),
                  Icon(
                    Icons.assessment_outlined,
                    color: dark ? lime : forest,
                    size: 34,
                  ),
                ],
              )
            : c.chapter.lab == 'preparation'
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Icon(Icons.storage_outlined, color: forest, size: 34),
                  Icon(Icons.arrow_forward, color: forest, size: 16),
                  Icon(Icons.tune, color: forest, size: 34),
                  Icon(Icons.arrow_forward, color: forest, size: 16),
                  Icon(Icons.fact_check_outlined, color: forest, size: 34),
                ],
              )
            : CustomPaint(
                painter: c.chapter.lab == 'classification'
                    ? SigmoidPainter(
                        color: dark ? lime : forest,
                        grid: forest.withValues(alpha: .12),
                      )
                    : RegressionPainter(decorative: true, dark: dark),
                child: const SizedBox.expand(),
              ),
      ),
      const SizedBox(height: 9),
      Text(
        'a little data, a little intuition.',
        style: TextStyle(
          fontSize: 9,
          color: dark ? lime : forest,
          letterSpacing: .4,
        ),
      ),
    ],
  );

  Widget _stats() => LayoutBuilder(
    builder: (context, box) {
      final items = [
        (
          Icons.auto_stories_outlined,
          '${c.completedCount}/${c.chapter.lessons.length}',
          'Lessons complete',
        ),
        (
          Icons.fact_check_outlined,
          '${c.answers.length}/${c.chapter.quizzes.length}',
          'Questions attempted',
        ),
        (
          Icons.bookmark_outline,
          '${c.chapter.lessons.where((l) => c.bookmarked(l.id)).length}',
          'Saved for later',
        ),
      ];
      return Row(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: Panel(
                padding: EdgeInsets.all(box.maxWidth < 500 ? 12 : 17),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      items[i].$1,
                      size: 19,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      items[i].$2,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      items[i].$3,
                      style: const TextStyle(fontSize: 9, height: 1.7),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      );
    },
  );

  Widget _lessonTile(Lesson lesson, {Curriculum? owner}) {
    final source = owner ?? c.chapter;
    final index = source.lessons.indexWhere((item) => item.id == lesson.id),
        done = c.completed(lesson.id),
        isNext = source.id == c.chapter.id && lesson.id == c.nextLesson.id;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => openLesson(lesson),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 17),
          child: Row(
            children: [
              Container(
                width: 39,
                height: 43,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: done
                      ? forest.withValues(alpha: .10)
                      : Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: done
                    ? Icon(
                        Icons.check_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      )
                    : Text(
                        '${(index >= 0 ? index : 0) + 1}'.padLeft(2, '0'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (owner != null) ...[
                      Eyebrow('${source.fullLabel} · ${source.shortTitle}'),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      lesson.title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 5),
                    RichProse(
                      lesson.subtitle,
                      selectable: false,
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'NotoSansBengali',
                        fontFamilyFallback: const [
                          'Manrope',
                          'NotoSansMath',
                          'NotoSans',
                        ],
                        height: 1.8,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Icon(Icons.schedule, size: 11),
                        const SizedBox(width: 4),
                        Text(
                          lesson.duration,
                          style: const TextStyle(fontSize: 9),
                        ),
                        if (lesson.blocks.any(
                          (b) => b.type == 'lab' || b.type.endsWith('_lab'),
                        )) ...[
                          const SizedBox(width: 9),
                          const Icon(Icons.touch_app_outlined, size: 11),
                          const SizedBox(width: 3),
                          const Text(
                            'Interactive lab',
                            style: TextStyle(fontSize: 9),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (MediaQuery.sizeOf(context).width > 650 &&
                  isNext &&
                  !done) ...[
                const Tag('UP NEXT'),
                const SizedBox(width: 8),
              ],
              IconButton(
                tooltip: c.bookmarked(lesson.id)
                    ? 'Remove bookmark'
                    : 'Bookmark lesson',
                onPressed: () =>
                    c.toggleBookmark(lesson.id).catchError((Object e) {
                      if (mounted) showFailure(context, e);
                    }),
                icon: Icon(
                  c.bookmarked(lesson.id)
                      ? Icons.bookmark
                      : Icons.bookmark_border,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const Icon(Icons.chevron_right, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _aside() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.route_outlined, size: 17, color: forest),
                SizedBox(width: 8),
                Expanded(child: Eyebrow('YOUR LEARNING PATH')),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              'Start with the why.',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 9),
            const Text(
              'Then build the intuition.\nThen write the code.',
              style: TextStyle(fontSize: 11, height: 1.9),
            ),
            const SizedBox(height: 22),
            _pathStep(
              '01',
              'Understand',
              '${c.chapter.lessons.length} guided lessons',
              true,
            ),
            _pathStep('02', 'Experiment', 'Hands-on learning labs', false),
            _pathStep(
              '03',
              'Put it to the test',
              'Quizzes, code & interviews',
              false,
            ),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 10),
            const Text(
              'Your pace is the right pace.',
              style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      Container(
        padding: const EdgeInsets.all(23),
        decoration: BoxDecoration(
          color: const Color(0xFF233D2D),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.terminal_rounded, color: lime, size: 27),
            const SizedBox(height: 19),
            const Text(
              'Less memorizing.\nMore “aha!”',
              style: TextStyle(
                color: Colors.white,
                fontSize: 21,
                height: 1.4,
                fontWeight: FontWeight.w700,
                letterSpacing: -.4,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              c.chapter.lab == 'reinforcement'
                  ? 'Trace decisions, rewards and Bellman updates.'
                  : c.chapter.lab == 'final_capstone'
                  ? 'Connect the evidence. Own your contribution. Defend the limits.'
                  : c.chapter.lab == 'interview_practice'
                  ? 'Clarify the contract. Show the invariant. Test the edge case.'
                  : c.chapter.lab == 'system_design'
                  ? 'Connect the data. Budget the bottleneck. Defend the failure policy.'
                  : c.chapter.lab == 'experimentation'
                  ? 'Define the question. Respect the unit. Audit every causal assumption.'
                  : c.chapter.lab == 'mlops'
                  ? 'Package a complete release. Observe meaningful signals. Rehearse safe recovery.'
                  : c.chapter.lab == 'feature_systems'
                  ? 'Respect the cutoff. Replay safely. Keep the definition consistent.'
                  : c.chapter.lab == 'recommender_capstone'
                  ? 'Build the pipeline. Audit the evidence. Defend the decision.'
                  : c.chapter.lab == 'recommendation_evaluation'
                  ? 'Measure the uncertainty. Inspect the bias. Question the conclusion.'
                  : c.chapter.lab == 'deep_recommendation'
                  ? 'Retrieve the candidates. Rank the shortlist. Inspect the bottleneck.'
                  : c.chapter.lab == 'factorization'
                  ? 'Derive the objective. Solve the update. Inspect the interaction.'
                  : c.chapter.lab == 'recommendation'
                  ? 'Learn the feedback. Find the neighbors. Audit the ranking.'
                  : c.chapter.lab == 'gen_capstone'
                  ? 'Build the pipeline. Follow the evidence. Keep the failure in the report.'
                  : c.chapter.lab == 'diffusion'
                  ? 'Add noise. Follow the reverse process. Separate alignment from understanding.'
                  : c.chapter.lab == 'generative'
                  ? 'Infer the latent. Generate a sample. Follow gradients and audit the evidence.'
                  : c.chapter.lab == 'reliability'
                  ? 'Audit the score. Follow the failure. Separate simulation from measurement.'
                  : c.chapter.lab == 'adaptation'
                  ? 'Trace the gradients. Merge the adapter. Check the task against its baseline.'
                  : c.chapter.lab == 'rag'
                  ? 'Follow the source. Trace the context. Check what a citation really proves.'
                  : c.chapter.lab == 'retrieval'
                  ? 'Encode the query. Inspect the candidates. Measure what the ranking misses.'
                  : c.chapter.lab == 'llm'
                  ? 'Trace the tokens. Shift the targets. Inspect what the model actually generates.'
                  : c.chapter.lab == 'deep_capstone'
                  ? 'Build the experiment. Lock the policy. Ship the evidence with the model.'
                  : c.chapter.lab == 'attention'
                  ? 'Follow the weights. Respect the mask. Trace every residual path.'
                  : c.chapter.lab == 'sequence'
                  ? 'Trace the state. Respect the lengths. Fix the forecast origin.'
                  : c.chapter.lab == 'vision'
                  ? 'Trace the kernel. Inspect the pooling. Audit the transferred features.'
                  : c.chapter.lab == 'reliable'
                  ? 'Audit the update. Check the mode. Resume the state.'
                  : c.chapter.lab == 'neural'
                  ? 'Trace the signal. Derive the gradient. Defend the learning curve.'
                  : c.chapter.lab == 'tensors'
                  ? 'Trace a layout. Audit a shape. Verify a gradient.'
                  : c.chapter.lab == 'capstone'
                  ? 'Audit the data. Lock the decision policy. Defend a reproducible model.'
                  : c.chapter.lab == 'temporal'
                  ? 'Investigate a flag. Freeze a forecast origin. Respect the information boundary.'
                  : c.chapter.lab == 'unsupervised'
                  ? 'Choose a geometry. Inspect a partition. Measure what a projection loses.'
                  : c.chapter.lab == 'classical'
                  ? 'Read a margin. Find a neighbor. Add log evidence with clear assumptions.'
                  : c.chapter.lab == 'ensembles'
                  ? 'Inspect a vote. Add a correction. Follow the evidence behind an ensemble.'
                  : c.chapter.lab == 'trees'
                  ? 'Move a split. Price a leaf. Trace a decision from data to prediction.'
                  : c.chapter.lab == 'statistics'
                  ? 'Change a base rate. Inspect an interval. Explain the assumptions behind evidence.'
                  : c.chapter.lab == 'mathematics'
                  ? 'Project a vector. Read a contour. Connect geometry, calculus and code.'
                  : c.chapter.lab == 'python'
                  ? 'Inspect a shape. Advance an iterator. Write code you can test and explain.'
                  : c.chapter.lab == 'evaluation'
                  ? 'Inspect a fold. Preserve a pair. Understand the evidence behind a score.'
                  : c.chapter.lab == 'preparation'
                  ? 'Trace a missing value. Freeze a vocabulary. Follow the complete pipeline.'
                  : c.chapter.lab == 'classification'
                  ? 'Move a boundary. Change a threshold. See the decisions behind the metrics.'
                  : 'Tweak a curve. Watch the error change. See regression make sense.',
              style: const TextStyle(
                color: Color(0xFFBECDC0),
                fontSize: 11,
                height: 1.9,
              ),
            ),
            const SizedBox(height: 19),
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: lime,
                padding: EdgeInsets.zero,
              ),
              onPressed: () => navigate(1),
              label: const Text(
                'Open the playground',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
              icon: const Icon(Icons.arrow_forward, size: 16),
              iconAlignment: IconAlignment.end,
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Tag('INTERVIEW CORNER', color: Color(0xFF9C7139)),
            const SizedBox(height: 17),
            const Text(
              'Can you explain it\nwithout the jargon?',
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${c.chapter.interviews.length} FAANG-style prompts to turn understanding into clear answers.',
              style: const TextStyle(fontSize: 11, height: 1.9),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => navigate(2),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              child: const Text(
                'Try interview practice →',
                style: TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      const Center(
        child: Text(
          'NO ACCOUNT. NO WIFI. NO DISTRACTIONS.',
          style: TextStyle(
            fontSize: 7.5,
            letterSpacing: .9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );
  Widget _pathStep(String n, String title, String subtitle, bool active) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 21),
        child: Row(
          children: [
            Container(
              width: 29,
              height: 29,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active
                    ? forest
                    : Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                n,
                style: TextStyle(
                  fontSize: 9,
                  color: active
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(subtitle, style: const TextStyle(fontSize: 9)),
                ],
              ),
            ),
          ],
        ),
      );

  Future<void> _showExportBackupDialog() async {
    try {
      final payload = await c.exportBackup();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Learner Data Backup (JSON)'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'আপনার সব বইয়ের lesson progress, notes, bookmarks, quiz উত্তর এবং exercise draft নিচে JSON আকারে আছে। এটি কপি করে যেকোনো নিরাপদ জায়গায় সেভ রাখতে পারেন।',
                    style: TextStyle(
                      fontFamilyFallback: ['NotoSansBengali'],
                      fontSize: 12,
                      height: 1.8,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    payload,
                    key: const ValueKey('backup-export-text'),
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 11,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
            FilledButton.icon(
              key: const ValueKey('copy-backup-json'),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: payload));
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Backup JSON copied to clipboard.'),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copy JSON'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  Future<void> _showImportBackupDialog() async {
    final input = TextEditingController();
    String? errorText;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('Restore Learner Data (JSON)'),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'আগে export করা `ml_path_backup_v1` JSON নিচে পেস্ট করে Restore data চাপুন।',
                      style: TextStyle(
                        fontFamilyFallback: ['NotoSansBengali'],
                        fontSize: 12,
                        height: 1.8,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const ValueKey('backup-import-field'),
                      controller: input,
                      minLines: 6,
                      maxLines: 12,
                      style: const TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 11,
                        height: 1.6,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Paste ml_path_backup_v1 JSON here…',
                        errorText: errorText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const ValueKey('confirm-restore-backup'),
                onPressed: () async {
                  try {
                    final summary = await c.importBackup(input.text.trim());
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                    if (mounted) {
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Restored ${summary['progress']} lessons, ${summary['quiz_answers']} quiz answers, and ${summary['exercises']} exercises.',
                          ),
                        ),
                      );
                    }
                  } on FormatException catch (e) {
                    setDialogState(() => errorText = e.message);
                  } catch (_) {
                    setDialogState(
                      () => errorText = 'Invalid backup JSON payload.',
                    );
                  }
                },
                child: const Text('Restore data'),
              ),
            ],
          ),
        ),
      );
    } finally {
      input.dispose();
    }
  }

  Widget _notebook(bool bookmarksOnly) {
    final needle = noteQuery.trim().toLowerCase();
    final entries = c
        .notebookEntries(bookmarksOnly: bookmarksOnly, allBooks: allBooksNotes)
        .where((entry) {
          if (needle.isEmpty) return true;
          final ch = entry.$1;
          final l = entry.$2;
          return l.title.toLowerCase().contains(needle) ||
              l.subtitle.toLowerCase().contains(needle) ||
              ch.title.toLowerCase().contains(needle) ||
              ch.fullLabel.toLowerCase().contains(needle) ||
              c.note(l.id).toLowerCase().contains(needle);
        })
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          bookmarksOnly ? 'Worth coming back to.' : 'Make it your own.',
          bookmarksOnly
              ? 'Your saved lessons across all 6 books, ready whenever you are.'
              : 'Notes, bookmarks, and offline backup across all 6 books.',
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            ChoiceChip(
              key: const ValueKey('notes-scope-all'),
              label: const Text(
                'সব বই (All Books)',
                style: TextStyle(fontSize: 11),
              ),
              selected: allBooksNotes,
              onSelected: (_) => setState(() => allBooksNotes = true),
            ),
            ChoiceChip(
              key: const ValueKey('notes-scope-chapter'),
              label: const Text('এই অধ্যায়', style: TextStyle(fontSize: 11)),
              selected: !allBooksNotes,
              onSelected: (_) => setState(() => allBooksNotes = false),
            ),
            if (!bookmarksOnly) ...[
              ActionChip(
                avatar: const Icon(Icons.bookmark_border, size: 16),
                label: const Text('View bookmarks'),
                onPressed: () => navigate(4),
              ),
              ActionChip(
                avatar: const Icon(Icons.add, size: 16),
                label: const Text('Add a lesson note'),
                onPressed: () => openLesson(c.nextLesson),
              ),
              ActionChip(
                key: const ValueKey('export-backup'),
                avatar: const Icon(Icons.download_outlined, size: 16),
                label: const Text('Backup JSON'),
                onPressed: _showExportBackupDialog,
              ),
              ActionChip(
                key: const ValueKey('import-backup'),
                avatar: const Icon(Icons.upload_file_outlined, size: 16),
                label: const Text('Restore JSON'),
                onPressed: _showImportBackupDialog,
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: TextField(
            key: const ValueKey('notebook-search'),
            controller: noteSearch,
            onChanged: (value) => setState(() => noteQuery = value),
            decoration: const InputDecoration(
              hintText: 'Search notes or bookmarked lessons…',
              hintStyle: TextStyle(fontSize: 12),
              prefixIcon: Icon(Icons.search, size: 18),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (entries.isEmpty)
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.edit_note_rounded, size: 40, color: forest),
                const SizedBox(height: 16),
                const Text(
                  'Your ideas will live here.',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Open any lesson to write a note or tap its bookmark icon. Everything stays on your device.',
                  style: TextStyle(height: 1.8),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => navigate(0),
                  child: Text('Explore ${c.chapter.label}'),
                ),
              ],
            ),
          ),
        for (final entry in entries) ...[
          _lessonTile(entry.$2, owner: entry.$1),
          if (!bookmarksOnly && c.note(entry.$2.id).trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              child: Text(
                c.note(entry.$2.id),
                style: const TextStyle(
                  fontFamilyFallback: ['NotoSansBengali'],
                  height: 1.9,
                ),
              ),
            )
          else
            const SizedBox(height: 14),
        ],
      ],
    );
  }
}
