import 'package:flutter/material.dart';

import '../../models/hot_question.dart';
import '../../state/learning_controller.dart';
import '../../ui/theme.dart';
import 'hot_question_detail_page.dart';

class HotQuestionsPage extends StatefulWidget {
  final LearningController controller;
  const HotQuestionsPage({super.key, required this.controller});

  @override
  State<HotQuestionsPage> createState() => _HotQuestionsPageState();
}

class _HotQuestionsPageState extends State<HotQuestionsPage> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  String _category = 'all';
  String _frequency = 'All';
  String _status = 'All';

  LearningController get c => widget.controller;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<(String, String, int)> _categories(List<HotQuestion> all) {
    final labels = <String, String>{};
    final counts = <String, int>{};
    for (final q in all) {
      labels[q.category] = q.categoryLabel;
      counts[q.category] = (counts[q.category] ?? 0) + 1;
    }
    return [
      ('all', 'All Topics', all.length),
      for (final e in labels.entries) (e.key, e.value, counts[e.key]!),
    ];
  }

  List<HotQuestion> _filtered(List<HotQuestion> all) {
    final needle = _query.trim().toLowerCase();
    return all.where((q) {
      if (_category != 'all' && q.category != _category) return false;
      if (_frequency != 'All' && q.frequency != _frequency) return false;
      if (_status == 'Confident' && !c.isVivaConfident(q.id)) return false;
      if (_status == 'Review' && !c.isVivaReview(q.id)) return false;
      if (_status == 'Unreviewed' &&
          (c.isVivaConfident(q.id) || c.isVivaReview(q.id))) {
        return false;
      }
      if (_status == 'Starred' && !c.isVivaStarred(q.id)) return false;
      if (needle.isNotEmpty) {
        final hay =
            '${q.badge} ${q.title} ${q.categoryLabel} ${q.tags.join(' ')} ${q.elevatorAnswer}'
                .toLowerCase();
        if (!hay.contains(needle)) return false;
      }
      return true;
    }).toList();
  }

  void _openDeck(
    List<HotQuestion> deck, {
    int index = 0,
    bool drillMode = false,
  }) {
    if (deck.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HotQuestionDetailPage(
          controller: c,
          deck: deck,
          initialIndex: index,
          startHidden: drillMode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final all = c.hotQuestions;
      final cats = _categories(all);
      final visible = _filtered(all);
      final total = all.length;
      final confident = c.confidentVivaCount;
      final reviewCount = all.where((q) => c.isVivaReview(q.id)).length;
      final starCount = all.where((q) => c.isVivaStarred(q.id)).length;

      return Scaffold(
        appBar: AppBar(
          title: Text(
            'FAANG Viva Hot Questions ($total)',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
        ),
        body: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1040),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Panel(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Eyebrow(
                                'HIGH-FREQUENCY FAANG VIVA BANK · REPEATABLE REVISION',
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'যেকোনো FAANG Viva প্রশ্নের ঝরঝরে, পয়েন্ট-বাই-পয়েন্ট উত্তর।',
                                style: TextStyle(
                                  fontFamilyFallback: ['NotoSansBengali'],
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Classical ML, Deep Learning, Transformers, LLMs, Interpretability, RecSys এবং Systems-এর সবচেয়ে বেশি আসা প্রশ্নগুলো—প্রতিটিতে ৩০-সেকেন্ডের সারাংশ, উদাহরণ, Python Snippet, তুলনার টেবিল ও Follow-up ফাঁদ।',
                                style: TextStyle(
                                  fontFamilyFallback: ['NotoSansBengali'],
                                  fontSize: 12.5,
                                  height: 1.9,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 10,
                                runSpacing: 8,
                                children: [
                                  Tag(
                                    '$confident / $total Confident',
                                    icon: Icons.check_circle_outline,
                                  ),
                                  Tag(
                                    '$reviewCount Review Again',
                                    icon: Icons.replay_rounded,
                                    color: const Color(0xFF9C7139),
                                  ),
                                  Tag(
                                    '$starCount Starred',
                                    icon: Icons.star_rounded,
                                    color: const Color(0xFF9C7139),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              LinearProgressIndicator(
                                value: total == 0 ? 0 : confident / total,
                                minHeight: 6,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  FilledButton.icon(
                                    key: const ValueKey('viva-start-drill'),
                                    onPressed: visible.isEmpty
                                        ? null
                                        : () =>
                                              _openDeck(visible, drillMode: true),
                                    icon: const Icon(
                                      Icons.record_voice_over_outlined,
                                      size: 17,
                                    ),
                                    label: Text(
                                      'Start Viva Flashcard Drill (${visible.length})',
                                    ),
                                  ),
                                  if (reviewCount > 0)
                                    OutlinedButton.icon(
                                      onPressed: () => _openDeck(
                                        all
                                            .where((q) => c.isVivaReview(q.id))
                                            .toList(),
                                        drillMode: true,
                                      ),
                                      icon: const Icon(
                                        Icons.replay_rounded,
                                        size: 16,
                                      ),
                                      label: Text(
                                        'Drill Review Queue ($reviewCount)',
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          key: const ValueKey('viva-search'),
                          controller: _search,
                          onChanged: (v) => setState(() => _query = v),
                          decoration: InputDecoration(
                            hintText:
                                'Search "root d", "xgboost", "bias variance", "l1 l2", "activation", "interpretability"…',
                            hintStyle: const TextStyle(fontSize: 12),
                            prefixIcon: const Icon(Icons.search, size: 19),
                            suffixIcon: _query.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Clear search',
                                    onPressed: () {
                                      _search.clear();
                                      setState(() => _query = '');
                                    },
                                    icon: const Icon(Icons.close, size: 18),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Eyebrow('TOPICS (HOT AREAS FIRST)'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final cat in cats)
                              ChoiceChip(
                                key: ValueKey('viva-cat-${cat.$1}'),
                                label: Text(
                                  '${cat.$2} (${cat.$3})',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                selected: _category == cat.$1,
                                onSelected: (_) =>
                                    setState(() => _category = cat.$1),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final freq in [
                              'All',
                              'Must-Know',
                              'High Frequency',
                              'L5+ Deep Dive',
                            ])
                              ChoiceChip(
                                key: ValueKey('viva-freq-$freq'),
                                label: Text(
                                  freq == 'All' ? 'All priority' : freq,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                selected: _frequency == freq,
                                onSelected: (_) =>
                                    setState(() => _frequency = freq),
                              ),
                            for (final st in [
                              'All',
                              'Unreviewed',
                              'Review',
                              'Confident',
                              'Starred',
                            ])
                              ChoiceChip(
                                key: ValueKey('viva-status-$st'),
                                label: Text(
                                  st == 'All'
                                      ? 'All status'
                                      : st == 'Review'
                                      ? 'Review Again'
                                      : st,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                selected: _status == st,
                                onSelected: (_) => setState(() => _status = st),
                              ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Showing ${visible.length} of $total FAANG Viva questions',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (visible.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 48),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1040),
                      child: Panel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'এই ফিল্টারে কোনো প্রশ্ন পাওয়া যায়নি।',
                              style: TextStyle(
                                fontFamilyFallback: ['NotoSansBengali'],
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: () {
                                _search.clear();
                                setState(() {
                                  _query = '';
                                  _category = 'all';
                                  _frequency = 'All';
                                  _status = 'All';
                                });
                              },
                              child: const Text('Reset filters'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 48),
                sliver: SliverList.builder(
                  itemCount: visible.length,
                  itemBuilder: (context, idx) => Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1040),
                      child: _questionCard(visible, idx),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );

  Widget _questionCard(List<HotQuestion> visible, int idx) {
    final q = visible[idx];
    final confident = c.isVivaConfident(q.id);
    final review = c.isVivaReview(q.id);
    final starred = c.isVivaStarred(q.id);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        key: ValueKey('viva-card-${q.id}'),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openDeck(visible, index: idx, drillMode: false),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: confident
                        ? forest.withValues(alpha: .12)
                        : review
                        ? const Color(0xFF9C7139).withValues(alpha: .14)
                        : Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: confident
                      ? const Icon(Icons.check_rounded, color: forest, size: 22)
                      : review
                      ? const Icon(
                          Icons.replay_rounded,
                          color: Color(0xFF9C7139),
                          size: 20,
                        )
                      : Text(
                          q.number.toString().padLeft(2, '0'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        q.title,
                        style: const TextStyle(
                          fontFamilyFallback: ['NotoSansBengali'],
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 7,
                        runSpacing: 6,
                        children: [
                          Tag(
                            q.frequency,
                            color: frequencyColor(q.frequency),
                          ),
                          Tag(q.categoryLabel),
                          if (q.codeSnippet.isNotEmpty)
                            Tag(
                              'Python',
                              icon: Icons.code,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key: ValueKey('viva-star-${q.id}'),
                      visualDensity: VisualDensity.compact,
                      tooltip: starred ? 'Remove star' : 'Star question',
                      onPressed: () =>
                          c.toggleVivaStar(q.id).catchError((Object e) {
                            if (mounted) showFailure(context, e);
                          }),
                      icon: Icon(
                        starred
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        size: 20,
                        color: starred ? const Color(0xFF9C7139) : null,
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 18),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
