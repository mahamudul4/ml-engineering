class CodingExample {
  final String input, output, explanation;
  const CodingExample({
    required this.input,
    required this.output,
    required this.explanation,
  });

  factory CodingExample.fromJson(Map<String, dynamic> j) => CodingExample(
    input: j['input'] as String,
    output: j['output'] as String,
    explanation: j['explanation'] as String,
  );
}

class ThinkQuestion {
  final String question, explanation;
  final List<String> options;
  final int answer;
  const ThinkQuestion({
    required this.question,
    required this.options,
    required this.answer,
    required this.explanation,
  });

  factory ThinkQuestion.fromJson(Map<String, dynamic> j) => ThinkQuestion(
    question: j['question'] as String,
    options: List<String>.from(j['options'] as List),
    answer: j['answer'] as int,
    explanation: j['explanation'] as String,
  );
}

class CodingComplexity {
  final String time, space;
  const CodingComplexity({required this.time, required this.space});

  factory CodingComplexity.fromJson(Map<String, dynamic> j) => CodingComplexity(
    time: j['time'] as String,
    space: j['space'] as String,
  );
}

class CodingProblem {
  final String id,
      title,
      category,
      categoryLabel,
      difficulty,
      chapterRef,
      summary,
      problemStatement,
      mathFormula,
      targetFunction,
      codebaseTemplate,
      solutionCode,
      walkthrough;
  final int number;
  final List<String> tags, hints, edgeCases;
  final List<CodingExample> examples;
  final List<ThinkQuestion> thinkQuestions;
  final CodingComplexity complexity;

  const CodingProblem({
    required this.id,
    required this.number,
    required this.title,
    required this.category,
    required this.categoryLabel,
    required this.difficulty,
    required this.chapterRef,
    required this.tags,
    required this.summary,
    required this.problemStatement,
    required this.mathFormula,
    required this.targetFunction,
    required this.codebaseTemplate,
    required this.examples,
    required this.thinkQuestions,
    required this.hints,
    required this.solutionCode,
    required this.walkthrough,
    required this.complexity,
    required this.edgeCases,
  });

  String get badge => '#${number.toString().padLeft(3, '0')}';

  factory CodingProblem.fromJson(Map<String, dynamic> j) => CodingProblem(
    id: j['id'] as String,
    number: j['number'] as int,
    title: j['title'] as String,
    category: j['category'] as String,
    categoryLabel: j['categoryLabel'] as String,
    difficulty: j['difficulty'] as String,
    chapterRef: j['chapterRef'] as String,
    tags: List<String>.from(j['tags'] as List),
    summary: j['summary'] as String,
    problemStatement: j['problemStatement'] as String,
    mathFormula: (j['mathFormula'] as String?) ?? '',
    targetFunction: j['targetFunction'] as String,
    codebaseTemplate: j['codebaseTemplate'] as String,
    examples: (j['examples'] as List)
        .map((e) => CodingExample.fromJson(e as Map<String, dynamic>))
        .toList(),
    thinkQuestions: (j['thinkQuestions'] as List)
        .map((q) => ThinkQuestion.fromJson(q as Map<String, dynamic>))
        .toList(),
    hints: List<String>.from(j['hints'] as List),
    solutionCode: j['solutionCode'] as String,
    walkthrough: j['walkthrough'] as String,
    complexity: CodingComplexity.fromJson(
      j['complexity'] as Map<String, dynamic>,
    ),
    edgeCases: List<String>.from(j['edgeCases'] as List),
  );
}

