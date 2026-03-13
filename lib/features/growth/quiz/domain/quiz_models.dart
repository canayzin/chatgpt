class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.topic,
    required this.question,
    required this.options,
    required this.correctIndex,
    this.explanation,
  });

  final String id;
  final String topic;
  final String question;
  final List<String> options;
  final int correctIndex;
  final String? explanation;

  factory QuizQuestion.fromMap(String id, Map<String, dynamic> data) {
    return QuizQuestion(
      id: id,
      topic: data['topic'] as String? ?? 'General',
      question: data['question'] as String? ?? '',
      options: ((data['options'] as List?) ?? const []).map((e) => e.toString()).toList(),
      correctIndex: (data['correctIndex'] as num?)?.toInt() ?? 0,
      explanation: data['explanation'] as String?,
    );
  }
}

class QuizResult {
  const QuizResult({required this.total, required this.correct});

  final int total;
  final int correct;
}
