import '../models/curriculum.dart';

/// Relevance-scored search hit across chapters and lessons.
class RankedSearchHit {
  final Curriculum chapter;
  final Lesson? lesson;
  final int score;
  final bool exactOrPrefix;

  const RankedSearchHit({
    required this.chapter,
    required this.lesson,
    required this.score,
    required this.exactOrPrefix,
  });
}

/// Helper for relevance-ranked search across all 6 books and 51 chapters.
///
/// Whole-word matches (e.g. `RSI` matching `(RSI)` or `RSI কী?`) always outrank
/// accidental inner-word substring hits (e.g. `rsi` inside `version` or
/// `diversity`). For short ASCII queries (<= 3 chars like `rsi`, `rag`, `dpo`),
/// inner-word noise is suppressed whenever real word/prefix hits exist.
class CurriculumSearch {
  final String needle;
  final RegExp _wordBoundary;
  final RegExp _wordPrefix;
  final bool _isShortAscii;

  CurriculumSearch._(
    this.needle,
    this._wordBoundary,
    this._wordPrefix,
    this._isShortAscii,
  );

  factory CurriculumSearch(String rawQuery) {
    final needle = rawQuery.trim().toLowerCase();
    final escaped = RegExp.escape(needle);
    return CurriculumSearch._(
      needle,
      RegExp('(^|[^a-z0-9])$escaped(\$|[^a-z0-9])'),
      RegExp('(^|[^a-z0-9])$escaped'),
      needle.length <= 3 && RegExp(r'^[a-z0-9]+$').hasMatch(needle),
    );
  }

  bool get isEmpty => needle.isEmpty;

  /// Returns `100` for whole-word match, `50` for word-prefix match, `10` for
  /// inner substring match, or `0` for no match.
  int scoreText(String text) {
    if (needle.isEmpty || text.isEmpty) return 0;
    final lower = text.toLowerCase();
    if (!lower.contains(needle)) return 0;
    if (_wordBoundary.hasMatch(lower)) return 100;
    if (_wordPrefix.hasMatch(lower)) return 50;
    return 10;
  }

  /// Scores a chapter (optionally including its precomputed full-text index).
  /// Returns `(score, exactOrPrefix)`.
  (int, bool) scoreChapter(Curriculum ch, {String? fullTextIndex}) {
    if (needle.isEmpty) return (0, false);
    final titleScore = scoreText('${ch.title} ${ch.shortTitle}');
    final subScore = scoreText('${ch.subtitle} ${ch.description}');
    final labelScore = scoreText('${ch.fullLabel} ${ch.bookVolume.title}');

    var bestLessonTitle = 0;
    var bestLessonSub = 0;
    for (final l in ch.lessons) {
      final ts = scoreText(l.title);
      if (ts > bestLessonTitle) bestLessonTitle = ts;
      final ss = scoreText(l.subtitle);
      if (ss > bestLessonSub) bestLessonSub = ss;
    }

    final bodyScore = fullTextIndex == null ? 0 : scoreText(fullTextIndex);
    final total =
        titleScore * 12 +
        bestLessonTitle * 6 +
        subScore * 3 +
        labelScore * 2 +
        bestLessonSub * 2 +
        bodyScore;

    if (total == 0) return (0, false);
    final strong =
        titleScore >= 50 ||
        bestLessonTitle >= 50 ||
        subScore >= 50 ||
        labelScore >= 50 ||
        bestLessonSub >= 50 ||
        bodyScore >= 50;
    return (total, strong);
  }

  /// Scores a single lesson (optionally including its precomputed full-text).
  (int, bool) scoreLesson(Lesson l, {String? fullTextIndex}) {
    if (needle.isEmpty) return (0, false);
    final titleScore = scoreText(l.title);
    final subScore = scoreText(l.subtitle);
    final bodyScore = fullTextIndex == null ? 0 : scoreText(fullTextIndex);
    final total = titleScore * 10 + subScore * 3 + bodyScore;
    if (total == 0) return (0, false);
    final strong = titleScore >= 50 || subScore >= 50 || bodyScore >= 50;
    return (total, strong);
  }

  /// Searches all chapters and lessons, sorting by relevance score DESC and
  /// suppressing accidental inner-word matches for short ASCII acronyms when
  /// real word/prefix hits exist.
  List<RankedSearchHit> searchCatalog(
    List<Curriculum> readingPath, {
    int limit = 40,
    String? excludeChapterId,
  }) {
    if (needle.isEmpty) return const [];
    final hits = <RankedSearchHit>[];
    for (final ch in readingPath) {
      if (excludeChapterId != null && ch.id == excludeChapterId) continue;
      final titleScore = scoreText('${ch.title} ${ch.shortTitle}');
      final subScore = scoreText('${ch.subtitle} ${ch.description}');
      final labelScore = scoreText('${ch.fullLabel} ${ch.bookVolume.title}');
      final chTotal = titleScore * 12 + subScore * 3 + labelScore * 2;
      if (chTotal > 0) {
        hits.add(
          RankedSearchHit(
            chapter: ch,
            lesson: null,
            score: chTotal + 50, // Chapters gently lead over lessons of equal tier
            exactOrPrefix:
                titleScore >= 50 || subScore >= 50 || labelScore >= 50,
          ),
        );
      }
      for (final l in ch.lessons) {
        final (lTotal, lStrong) = scoreLesson(l);
        if (lTotal > 0) {
          hits.add(
            RankedSearchHit(
              chapter: ch,
              lesson: l,
              score: lTotal,
              exactOrPrefix: lStrong,
            ),
          );
        }
      }
    }

    var filtered = hits;
    if (_isShortAscii && hits.any((h) => h.exactOrPrefix)) {
      filtered = hits.where((h) => h.exactOrPrefix).toList();
    }

    filtered.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      final byOrder = a.chapter.book.order.compareTo(b.chapter.book.order);
      if (byOrder != 0) return byOrder;
      if (a.lesson == null && b.lesson != null) return -1;
      if (a.lesson != null && b.lesson == null) return 1;
      return 0;
    });

    if (filtered.length > limit) {
      return filtered.sublist(0, limit);
    }
    return filtered;
  }

  /// Whether a short-acronym query should suppress inner-word matches when
  /// stronger matches exist in a list.
  bool get suppressWeakForShortAscii => _isShortAscii;
}
