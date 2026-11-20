import 'package:flutter/material.dart';

import '../../models/coding_problem.dart';
import '../../state/learning_controller.dart';
import '../../ui/theme.dart';
import 'coding_problem_page.dart';

class CodingArenaPage extends StatefulWidget {
  final LearningController controller;
  const CodingArenaPage({super.key, required this.controller});

  @override
  State<CodingArenaPage> createState() => _CodingArenaPageState();
}

class _CodingArenaPageState extends State<CodingArenaPage> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  String _category = 'all';
  String _difficulty = 'All';
  String _status = 'All';

  LearningController get c => widget.controller;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<(String, String, int)> _domainSummary(List<CodingProblem> all) {
    final labels = <String, String>{};
    final counts = <String, int>{};
    for (final p in all) {
      labels[p.category] = p.categoryLabel;
      counts[p.category] = (counts[p.category] ?? 0) + 1;
    }
    return [
      ('all', 'All Domains', all.length),
      for (final entry in labels.entries)
        (entry.key, entry.value, counts[entry.key]!),
    ];
  }

  List<CodingProblem> _filtered(List<CodingProblem> all) {
    final needle = _query.trim().toLowerCase();
    return all.where((p) {
      if (_category != 'all' && p.category != _category) return false;
      if (_difficulty != 'All' && p.difficulty != _difficulty) return false;
      if (_status == 'Solved' && !c.isCodingSolved(p.id)) return false;
      if (_status == 'Todo' && c.isCodingSolved(p.id)) return false;
      if (_status == 'Starred' && !c.isCodingStarred(p.id)) return false;
      if (needle.isNotEmpty) {
        final hay =
            '${p.badge} ${p.title} ${p.targetFunction} ${p.summary} ${p.categoryLabel} ${p.tags.join(' ')}'
                .toLowerCase();
        if (!hay.contains(needle)) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final all = c.codingProblems;
      final domains = _domainSummary(all);
      final visible = _filtered(all);
      final total = all.length;
      final solved = c.solvedCodingCount;
      final easyTotal = all.where((p) => p.difficulty == 'Easy').length;
      final easySolved = all
          .where((p) => p.difficulty == 'Easy' && c.isCodingSolved(p.id))
          .length;
      final medTotal = all.where((p) => p.difficulty == 'Medium').length;
      final medSolved = all
          .where((p) => p.difficulty == 'Medium' && c.isCodingSolved(p.id))
          .length;
      final hardTotal = all.where((p) => p.difficulty == 'Hard').length;
      final hardSolved = all
          .where((p) => p.difficulty == 'Hard' && c.isCodingSolved(p.id))
          .length;

      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'ML Coding Arena · Deep-ML Style',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
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
                          'DEEP-ML STYLE PROBLEM BANK · FULL CODEBASE STUDY',
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'কোডবেস বুঝুন। আগে নিজে ভাবুন। তারপর সমাধান মিলিয়ে নিন।',
                          style: TextStyle(
                            fontFamilyFallback: ['NotoSansBengali'],
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'প্রতিটি সমস্যার পূর্ণাঙ্গ ML কোডবেস পড়ে `# TODO` ফাংশনটি নিয়ে Think-First প্রশ্নের উত্তর দিন—এবং সম্পূর্ণ আলাদা Solution Fragment-এ গিয়ে যাচাইকৃত সমাধান ও ব্যাখ্যা দেখুন।',
                          style: TextStyle(
                            fontFamilyFallback: ['NotoSansBengali'],
                            fontSize: 12.5,
                            height: 1.9,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Tag(
                              '$solved / $total Solved',
                              icon: Icons.check_circle_outline,
                            ),
                            Tag(
                              'Easy $easySolved/$easyTotal',
                              color: forest,
                            ),
                            Tag(
                              'Medium $medSolved/$medTotal',
                              color: const Color(0xFF9C7139),
                            ),
                            Tag(
                              'Hard $hardSolved/$hardTotal',
                              color: const Color(0xFFB44C3B),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        LinearProgressIndicator(
                          value: total == 0 ? 0 : solved / total,
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    key: const ValueKey('coding-search'),
                    controller: _search,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText:
                          'Search problem, function (e.g. find_best_split, attention), or tag…',
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
                  const Eyebrow('DOMAINS'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final dom in domains)
                        ChoiceChip(
                          key: ValueKey('coding-domain-${dom.$1}'),
                          label: Text(
                            '${dom.$2} (${dom.$3})',
                            style: const TextStyle(fontSize: 11),
                          ),
                          selected: _category == dom.$1,
                          onSelected: (_) => setState(() => _category = dom.$1),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final diff in ['All', 'Easy', 'Medium', 'Hard'])
                        ChoiceChip(
                          key: ValueKey('coding-diff-$diff'),
                          label: Text(
                            diff == 'All' ? 'All levels' : diff,
                            style: const TextStyle(fontSize: 11),
                          ),
                          selected: _difficulty == diff,
                          onSelected: (_) => setState(() => _difficulty = diff),
                        ),
                      for (final st in ['All', 'Todo', 'Solved', 'Starred'])
                        ChoiceChip(
                          key: ValueKey('coding-status-$st'),
                          label: Text(
                            st == 'All' ? 'All status' : st,
                            style: const TextStyle(fontSize: 11),
                          ),
                          selected: _status == st,
                          onSelected: (_) => setState(() => _status = st),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Showing ${visible.length} of $total problems',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (visible.isEmpty)
                    Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'এই ফিল্টারে কোনো প্রবলেম পাওয়া যায়নি।',
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
                                _difficulty = 'All';
                                _status = 'All';
                              });
                            },
                            child: const Text('Reset filters'),
                          ),
                        ],
                      ),
                    ),
                  for (final p in visible) _problemCard(p),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _problemCard(CodingProblem p) {
    final solved = c.isCodingSolved(p.id);
    final starred = c.isCodingStarred(p.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        key: ValueKey('coding-card-${p.id}'),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => CodingProblemPage(controller: c, problem: p),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: solved
                        ? forest.withValues(alpha: .12)
                        : Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: solved
                      ? const Icon(Icons.check_rounded, color: forest, size: 22)
                      : Text(
                          p.number.toString().padLeft(2, '0'),
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
                        p.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        p.summary,
                        style: TextStyle(
                          fontFamilyFallback: const ['NotoSansBengali'],
                          fontSize: 11.5,
                          height: 1.8,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 7,
                        runSpacing: 6,
                        children: [
                          Tag(
                            p.difficulty,
                            color: difficultyColor(p.difficulty),
                          ),
                          Tag(p.categoryLabel),
                          Tag(
                            p.targetFunction,
                            icon: Icons.functions_rounded,
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
                      key: ValueKey('coding-star-${p.id}'),
                      visualDensity: VisualDensity.compact,
                      tooltip: starred ? 'Remove star' : 'Star problem',
                      onPressed: () =>
                          c.toggleCodingStar(p.id).catchError((Object e) {
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

