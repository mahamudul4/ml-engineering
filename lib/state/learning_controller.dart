import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/learning_repository.dart';
import '../models/book_part.dart';
import '../models/coding_problem.dart';
import '../models/curriculum.dart';

class LearningController extends ChangeNotifier {
  final LearningRepository repository;
  late Curriculum chapter;
  late List<Curriculum> chapters;
  List<CodingProblem> codingProblems = [];
  Map<String, Map<String, Object?>> records = {};
  Map<String, int> _allAnswers = {};
  Set<String> starredInterviews = {};
  Set<String> solvedCoding = {};
  Set<String> starredCoding = {};
  Map<String, String> _codingNotes = {};
  Map<String, int> get answers => {
    for (final q in chapter.quizzes)
      if (_allAnswers.containsKey(q.id)) q.id: _allAnswers[q.id]!,
  };
  ThemeMode themeMode = ThemeMode.light;
  String? lastLesson;
  LearningController(this.repository);
  List<Curriculum> get readingPath =>
      [...chapters]..sort((a, b) => a.book.order.compareTo(b.book.order));

  BookPart get currentBook => chapter.bookVolume;

  List<Curriculum> chaptersForBook(BookPart target) =>
      readingPath.where((item) => item.bookVolume == target).toList();

  List<Curriculum> get currentBookChapters => chaptersForBook(currentBook);

  Curriculum? get nextChapterInBook {
    final list = currentBookChapters;
    final index = list.indexWhere((item) => item.id == chapter.id);
    return index >= 0 && index + 1 < list.length ? list[index + 1] : null;
  }

  Curriculum? get previousChapterInBook {
    final list = currentBookChapters;
    final index = list.indexWhere((item) => item.id == chapter.id);
    return index > 0 ? list[index - 1] : null;
  }

  BookPart? get nextBook => currentBook.index + 1 < BookPart.values.length
      ? BookPart.values[currentBook.index + 1]
      : null;

  Curriculum? get nextChapter {
    final path = readingPath;
    final index = path.indexWhere((item) => item.id == chapter.id);
    return index >= 0 && index + 1 < path.length ? path[index + 1] : null;
  }

  Curriculum? get previousChapter {
    final path = readingPath;
    final index = path.indexWhere((item) => item.id == chapter.id);
    return index > 0 ? path[index - 1] : null;
  }

  int totalLessonsForBook(BookPart target) => chaptersForBook(
    target,
  ).fold(0, (sum, item) => sum + item.lessons.length);

  int completedLessonsForBook(BookPart target) => chaptersForBook(target).fold(
    0,
    (sum, item) => sum + item.lessons.where((l) => completed(l.id)).length,
  );

  int completedChaptersForBook(BookPart target) => chaptersForBook(target)
      .where(
        (item) =>
            item.lessons.isNotEmpty &&
            item.lessons.every((l) => completed(l.id)),
      )
      .length;

  String interviewKey(String chapterId, int index) => '$chapterId:$index';

  bool isInterviewStarred(String chapterId, int index) =>
      starredInterviews.contains(interviewKey(chapterId, index));

  Future<void> toggleInterviewStar(String chapterId, int index) async {
    final key = interviewKey(chapterId, index);
    final next = {...starredInterviews};
    if (!next.remove(key)) {
      next.add(key);
    }
    final ordered = next.toList()..sort();
    await repository.setSetting('starred_interviews', jsonEncode(ordered));
    starredInterviews = next;
    notifyListeners();
  }

  int? recordedAnswer(String questionId) => _allAnswers[questionId];

  List<(Curriculum, QuizQuestion, int)> wrongQuizzes({bool allBooks = true}) {
    final scope = allBooks ? readingPath : [chapter];
    final items = <(Curriculum, QuizQuestion, int)>[];
    for (final ch in scope) {
      for (final q in ch.quizzes) {
        final chosen = _allAnswers[q.id];
        if (chosen != null && chosen != q.answer) {
          items.add((ch, q, chosen));
        }
      }
    }
    return items;
  }

  List<(Curriculum, InterviewQuestion, int)> starredInterviewItems({
    bool allBooks = true,
  }) {
    final scope = allBooks ? readingPath : [chapter];
    final items = <(Curriculum, InterviewQuestion, int)>[];
    for (final ch in scope) {
      for (var idx = 0; idx < ch.interviews.length; idx++) {
        if (isInterviewStarred(ch.id, idx)) {
          items.add((ch, ch.interviews[idx], idx));
        }
      }
    }
    return items;
  }

  List<(Curriculum, Lesson)> notebookEntries({
    required bool bookmarksOnly,
    required bool allBooks,
  }) {
    final scope = allBooks ? readingPath : [chapter];
    final items = <(Curriculum, Lesson)>[];
    for (final ch in scope) {
      for (final l in ch.lessons) {
        final match = bookmarksOnly
            ? bookmarked(l.id)
            : note(l.id).trim().isNotEmpty || bookmarked(l.id);
        if (match) items.add((ch, l));
      }
    }
    return items;
  }

  bool isCodingSolved(String id) => solvedCoding.contains(id);

  bool isCodingStarred(String id) => starredCoding.contains(id);

  String codingNote(String id) => _codingNotes[id] ?? '';

  int get solvedCodingCount =>
      codingProblems.where((p) => solvedCoding.contains(p.id)).length;

  Future<void> toggleCodingSolved(String id) async {
    final next = {...solvedCoding};
    if (!next.remove(id)) {
      next.add(id);
    }
    final ordered = next.toList()..sort();
    await repository.setSetting('coding_solved', jsonEncode(ordered));
    solvedCoding = next;
    notifyListeners();
  }

  Future<void> toggleCodingStar(String id) async {
    final next = {...starredCoding};
    if (!next.remove(id)) {
      next.add(id);
    }
    final ordered = next.toList()..sort();
    await repository.setSetting('coding_starred', jsonEncode(ordered));
    starredCoding = next;
    notifyListeners();
  }

  Future<void> saveCodingNote(String id, String text) async {
    final next = {..._codingNotes};
    if (text.trim().isEmpty) {
      next.remove(id);
    } else {
      next[id] = text;
    }
    await repository.setSetting('coding_notes', jsonEncode(next));
    _codingNotes = next;
    notifyListeners();
  }

  Set<String> _decodeStringSet(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      return Set<String>.from(jsonDecode(raw) as List);
    } catch (_) {
      return {};
    }
  }

  Map<String, String> _decodeStringMap(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return {for (final e in decoded.entries) e.key: e.value.toString()};
    } catch (_) {
      return {};
    }
  }

  Future<String> exportBackup() => repository.exportBackup();

  Future<Map<String, int>> importBackup(String rawJson) async {
    final summary = await repository.importBackup(rawJson);
    await load();
    return summary;
  }

  Future<void> load() async {
    chapters = await repository.chapters();
    codingProblems = await repository.codingProblems();
    final selected = await repository.setting('selected_chapter');
    chapter = chapters.firstWhere(
      (c) => c.id == selected,
      orElse: () => readingPath.first,
    );
    await repository.setSetting(
      'selected_chapter:${chapter.bookVolume.id}',
      chapter.id,
    );
    starredInterviews = _decodeStringSet(
      await repository.setting('starred_interviews'),
    );
    solvedCoding = _decodeStringSet(await repository.setting('coding_solved'));
    starredCoding = _decodeStringSet(
      await repository.setting('coding_starred'),
    );
    _codingNotes = _decodeStringMap(await repository.setting('coding_notes'));
    await refresh();
    themeMode = await repository.setting('theme') == 'dark'
        ? ThemeMode.dark
        : ThemeMode.light;
    lastLesson = await _lastLesson(chapter);
  }

  Future<String?> _lastLesson(Curriculum target) async =>
      await repository.setting('last_lesson:${target.id}') ??
      (target.id == 'chapter_01'
          ? await repository.setting('last_lesson')
          : null);

  Future<void> selectChapter(String id) async {
    final next = chapters.firstWhere((c) => c.id == id);
    final last = await _lastLesson(next);
    await repository.setSetting('selected_chapter', id);
    await repository.setSetting('selected_chapter:${next.bookVolume.id}', id);
    chapter = next;
    lastLesson = last;
    notifyListeners();
  }

  Future<void> selectBook(BookPart target) async {
    final saved = await repository.setting('selected_chapter:${target.id}');
    final candidates = chaptersForBook(target);
    final destination = candidates.firstWhere(
      (item) => item.id == saved,
      orElse: () => candidates.first,
    );
    await selectChapter(destination.id);
  }

  Future<void> refresh() async {
    final nextRecords = {
      for (final r in await repository.progress()) r['lesson_id'] as String: r,
    };
    final nextAnswers = await repository.answers();
    records = nextRecords;
    _allAnswers = nextAnswers;
    notifyListeners();
  }

  bool completed(String id) => records[id]?['completed'] == 1;
  bool bookmarked(String id) => records[id]?['bookmarked'] == 1;
  String note(String id) => records[id]?['note'] as String? ?? '';
  int get completedCount =>
      chapter.lessons.where((l) => completed(l.id)).length;
  int get score =>
      chapter.quizzes.where((q) => answers[q.id] == q.answer).length;
  Lesson get nextLesson => chapter.lessons.firstWhere(
    (l) => l.id == lastLesson && !completed(l.id),
    orElse: () => chapter.lessons.firstWhere(
      (l) => !completed(l.id),
      orElse: () => chapter.lessons.first,
    ),
  );
  Future<void> visit(String id) async {
    final source = chapters.firstWhere(
      (item) => item.lessons.any((lesson) => lesson.id == id),
    );
    await repository.setSetting('last_lesson:${source.id}', id);
    // A prerequisite may open while its interview's chapter stays selected.
    if (source.id == chapter.id) lastLesson = id;
    notifyListeners();
  }

  Future<void> toggleComplete(String id) async {
    await repository.updateLesson(id, completed: !completed(id));
    await refresh();
  }

  Future<void> toggleBookmark(String id) async {
    await repository.updateLesson(id, bookmarked: !bookmarked(id));
    await refresh();
  }

  Future<void> saveNote(String id, String text) async {
    await repository.updateLesson(id, note: text);
    await refresh();
  }

  Future<void> answer(String id, int choice) async {
    await repository.answer(id, choice);
    await refresh();
  }

  Future<void> resetQuiz() async {
    await repository.resetQuiz(chapter.quizzes.map((q) => q.id));
    await refresh();
  }

  Future<void> toggleTheme() async {
    final next = themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await repository.setSetting('theme', next.name);
    themeMode = next;
    notifyListeners();
  }
}
