class LearningSeries {
  const LearningSeries({
    required this.id,
    required this.title,
    required this.category,
    required this.totalDays,
    required this.currentDay,
    required this.completed,
  });

  final String id;
  final String title;
  final String category;
  final int totalDays;
  final int currentDay;
  final bool completed;

  factory LearningSeries.fromMap(String id, Map<String, dynamic> data) {
    return LearningSeries(
      id: id,
      title: data['title'] as String? ?? 'Learning Series',
      category: data['category'] as String? ?? 'general',
      totalDays: (data['totalDays'] as num?)?.toInt() ?? 7,
      currentDay: (data['currentDay'] as num?)?.toInt() ?? 1,
      completed: data['completed'] as bool? ?? false,
    );
  }
}
