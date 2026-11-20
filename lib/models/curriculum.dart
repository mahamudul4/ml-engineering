import 'book_part.dart';

class Lesson {
  final String id, title, subtitle, duration, icon;
  final List<LessonBlock> blocks;
  Lesson.fromJson(Map<String, dynamic> json)
    : id = json['id'],
      title = json['title'],
      subtitle = json['subtitle'],
      duration = json['duration'],
      icon = json['icon'],
      blocks = (json['blocks'] as List)
          .map((b) => LessonBlock.fromJson(b))
          .toList();
}

class LessonBlock {
  final String type, title, body;
  final String? solution, reference;
  LessonBlock.fromJson(Map<String, dynamic> j)
    : type = j['type'] ?? 'text',
      title = j['title'] ?? '',
      body = j['body'],
      solution = j['solution'],
      reference = j['reference'];
}

class QuizQuestion {
  final String id, question, explanation;
  final List<String> options;
  final int answer;
  QuizQuestion.fromJson(Map<String, dynamic> j)
    : id = j['id'],
      question = j['question'],
      explanation = j['explanation'],
      options = List<String>.from(j['options']),
      answer = j['answer'];
}

class InterviewQuestion {
  final String title, tag, prompt, answer;
  final List<String> prerequisiteLessons;
  InterviewQuestion.fromJson(Map<String, dynamic> j)
    : title = j['title'],
      tag = j['tag'],
      prompt = j['prompt'],
      answer = j['answer'],
      prerequisiteLessons = List<String>.from(
        j['prerequisiteLessons'] ?? const [],
      );
}

class Exercise {
  final String id, title, prompt, starter, solution, explanation;
  final double expected;
  final double absoluteTolerance, relativeTolerance;
  double get tolerance =>
      absoluteTolerance + relativeTolerance * expected.abs();

  /// Checks a reported number, never the correctness of the scratchpad program.
  bool acceptsResult(double value) =>
      value.isFinite && (value - expected).abs() <= tolerance;
  Exercise.fromJson(Map<String, dynamic> j)
    : id = j['id'],
      title = j['title'],
      prompt = j['prompt'],
      starter = j['starter'],
      solution = j['solution'],
      explanation = j['explanation'],
      expected = (j['expected'] as num).toDouble(),
      absoluteTolerance = (j['absoluteTolerance'] as num?)?.toDouble() ?? 1e-9,
      relativeTolerance = (j['relativeTolerance'] as num?)?.toDouble() ?? 1e-6 {
    if (!expected.isFinite ||
        !absoluteTolerance.isFinite ||
        !relativeTolerance.isFinite ||
        absoluteTolerance < 0 ||
        relativeTolerance < 0 ||
        !tolerance.isFinite) {
      throw const FormatException(
        'Exercise requires a finite result and nonnegative finite tolerances',
      );
    }
  }
}

class Curriculum {
  final String id, title;
  final int number;
  final String shortTitle, displayTitle, subtitle, description, difficulty, lab;
  BookPart get bookVolume =>
      BookPart.forStep(book.order) ?? BookPart.foundations;
  int get bookChapterNumber => bookVolume.chapterNumberFor(book.order);
  String get label => 'Chapter $bookChapterNumber';
  String get fullLabel => '${bookVolume.shortTitle} · $label';
  String get badge =>
      '${bookVolume.shortTitle.toUpperCase()} · CHAPTER ${bookChapterNumber.toString().padLeft(2, '0')}';
  int get minutes => lessons.fold(
    0,
    (sum, l) => sum + (int.tryParse(l.duration.split(' ').first) ?? 0),
  );
  final List<Lesson> lessons;
  final List<QuizQuestion> quizzes;
  final List<InterviewQuestion> interviews;
  final List<Exercise> exercises;
  final BookChapter book;
  Curriculum.fromJson(Map<String, dynamic> j)
    : id = j['id'],
      title = j['title'],
      number = j['number'] ?? 1,
      shortTitle = j['shortTitle'] ?? 'ML Fundamentals',
      displayTitle = j['displayTitle'] ?? 'Machine Learning\nFundamentals',
      subtitle = j['subtitle'] ?? 'মেশিন কীভাবে শেখে? চলুন, শুরু থেকে বুঝি।',
      description =
          j['description'] ??
          'From your first feature to your first prediction.\nThe ideas that make machine learning click.',
      difficulty = j['difficulty'] ?? 'Beginner friendly',
      lab = j['lab'] ?? 'regression',
      book = BookChapter.fromJson(
        j['book'] as Map<String, dynamic>? ?? {},
        j['number'] ?? 1,
      ),
      lessons = (j['lessons'] as List).map((v) => Lesson.fromJson(v)).toList(),
      quizzes = (j['quizzes'] as List)
          .map((v) => QuizQuestion.fromJson(v))
          .toList(),
      interviews = (j['interviews'] as List)
          .map((v) => InterviewQuestion.fromJson(v))
          .toList(),
      exercises = (j['exercises'] as List)
          .map((v) => Exercise.fromJson(v))
          .toList();
}

/// Reading order is independent of permanent chapter IDs and saved progress.
class BookChapter {
  final int order;
  final String part, purpose, bridge;
  final List<String> prerequisites, outcomes, recall;

  BookChapter.fromJson(Map<String, dynamic> json, int chapterNumber)
    : order = json['order'] ?? chapterNumber,
      part = json['part'] ?? 'Learning path',
      purpose = json['purpose'] ?? '',
      bridge = json['bridge'] ?? '',
      prerequisites = List<String>.from(json['prerequisites'] ?? []),
      outcomes = List<String>.from(json['outcomes'] ?? []),
      recall = List<String>.from(json['recall'] ?? []);
}
