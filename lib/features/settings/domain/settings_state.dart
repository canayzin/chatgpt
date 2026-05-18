class SettingsState {
  const SettingsState({
    required this.isDarkMode,
    required this.notificationsEnabled,
    required this.audioSpeed,
    required this.dailyGoal,
  });

  final bool isDarkMode;
  final bool notificationsEnabled;
  final double audioSpeed;
  final int dailyGoal;

  factory SettingsState.defaults() {
    return const SettingsState(
      isDarkMode: false,
      notificationsEnabled: true,
      audioSpeed: 1.0,
      dailyGoal: 10,
    );
  }

  SettingsState copyWith({
    bool? isDarkMode,
    bool? notificationsEnabled,
    double? audioSpeed,
    int? dailyGoal,
  }) {
    return SettingsState(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      audioSpeed: audioSpeed ?? this.audioSpeed,
      dailyGoal: dailyGoal ?? this.dailyGoal,
    );
  }
}
