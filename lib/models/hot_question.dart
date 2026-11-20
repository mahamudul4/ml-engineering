class HotQuestion {
  final String id,
      title,
      category,
      categoryLabel,
      frequency,
      chapterRef,
      elevatorAnswer,
      coreBreakdown,
      concreteExample,
      mathFormula,
      codeSnippet,
      comparisonTable,
      followUpQuestion,
      followUpAnswer;
  final int number;
  final List<String> tags;

  const HotQuestion({
    required this.id,
    required this.number,
    required this.title,
    required this.category,
    required this.categoryLabel,
    required this.frequency,
    required this.chapterRef,
    required this.tags,
    required this.elevatorAnswer,
    required this.coreBreakdown,
    required this.concreteExample,
    required this.mathFormula,
    required this.codeSnippet,
    required this.comparisonTable,
    required this.followUpQuestion,
    required this.followUpAnswer,
  });

  String get badge => 'Q${number.toString().padLeft(3, '0')}';

  factory HotQuestion.fromJson(Map<String, dynamic> j) => HotQuestion(
    id: j['id'] as String,
    number: j['number'] as int,
    title: j['title'] as String,
    category: j['category'] as String,
    categoryLabel: j['categoryLabel'] as String,
    frequency: j['frequency'] as String,
    chapterRef: j['chapterRef'] as String,
    tags: List<String>.from(j['tags'] as List),
    elevatorAnswer: j['elevatorAnswer'] as String,
    coreBreakdown: j['coreBreakdown'] as String,
    concreteExample: j['concreteExample'] as String,
    mathFormula: (j['mathFormula'] as String?) ?? '',
    codeSnippet: (j['codeSnippet'] as String?) ?? '',
    comparisonTable: (j['comparisonTable'] as String?) ?? '',
    followUpQuestion: j['followUpQuestion'] as String,
    followUpAnswer: j['followUpAnswer'] as String,
  );
}

