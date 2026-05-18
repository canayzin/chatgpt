class UserStats {
  const UserStats({
    required this.totalLearned,
    required this.dailyLearned,
    required this.streakCount,
    required this.dailyGoal,
    this.lastLearnedAt,
  });

  final int totalLearned;
  final int dailyLearned;
  final int streakCount;
  final int dailyGoal;
  final DateTime? lastLearnedAt;

  double get dailyProgress => dailyGoal == 0 ? 0 : (dailyLearned / dailyGoal).clamp(0, 1);

  factory UserStats.initial({int dailyGoal = 10}) {
    return UserStats(
      totalLearned: 0,
      dailyLearned: 0,
      streakCount: 0,
      dailyGoal: dailyGoal,
      lastLearnedAt: null,
    );
  }

  factory UserStats.fromMap(Map<String, dynamic> map) {
    return UserStats(
      totalLearned: (map['totalLearned'] as num?)?.toInt() ?? 0,
      dailyLearned: (map['dailyLearned'] as num?)?.toInt() ?? 0,
      streakCount: (map['streakCount'] as num?)?.toInt() ?? 0,
      dailyGoal: (map['dailyGoal'] as num?)?.toInt() ?? 10,
      lastLearnedAt: (map['lastLearnedAt'] as DateTime?),
    );
  }

  UserStats copyWith({
    int? totalLearned,
    int? dailyLearned,
    int? streakCount,
    int? dailyGoal,
    DateTime? lastLearnedAt,
  }) {
    return UserStats(
      totalLearned: totalLearned ?? this.totalLearned,
      dailyLearned: dailyLearned ?? this.dailyLearned,
      streakCount: streakCount ?? this.streakCount,
      dailyGoal: dailyGoal ?? this.dailyGoal,
      lastLearnedAt: lastLearnedAt ?? this.lastLearnedAt,
    );
  }
}
