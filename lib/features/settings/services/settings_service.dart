import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/settings_state.dart';

final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService();
});

class SettingsService {
  static const _darkModeKey = 'settings.dark_mode';
  static const _notificationsKey = 'settings.notifications';
  static const _audioSpeedKey = 'settings.audio_speed';
  static const _dailyGoalKey = 'settings.daily_goal';

  Future<SettingsState> load() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsState(
      isDarkMode: prefs.getBool(_darkModeKey) ?? false,
      notificationsEnabled: prefs.getBool(_notificationsKey) ?? true,
      audioSpeed: prefs.getDouble(_audioSpeedKey) ?? 1.0,
      dailyGoal: prefs.getInt(_dailyGoalKey) ?? 10,
    );
  }

  Future<void> save(SettingsState state) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setBool(_darkModeKey, state.isDarkMode),
      prefs.setBool(_notificationsKey, state.notificationsEnabled),
      prefs.setDouble(_audioSpeedKey, state.audioSpeed),
      prefs.setInt(_dailyGoalKey, state.dailyGoal),
    ]);
  }
}

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, SettingsState>(SettingsController.new);

class SettingsController extends AsyncNotifier<SettingsState> {
  @override
  Future<SettingsState> build() async {
    return ref.read(settingsServiceProvider).load();
  }

  Future<void> applySettings(SettingsState next) async {
    final previous = state.valueOrNull ?? SettingsState.defaults();
    state = AsyncData(next);
    try {
      await ref.read(settingsServiceProvider).save(next);
    } catch (_) {
      state = AsyncData(previous);
      rethrow;
    }
  }
}
