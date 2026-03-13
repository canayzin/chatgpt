import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../growth/notifications/services/notification_service.dart';
import '../../stats/services/user_stats_service.dart';
import '../services/settings_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load settings: $error')),
        data: (settings) {
          return ListView(
            children: [
              SwitchListTile(
                title: const Text('Dark mode'),
                value: settings.isDarkMode,
                onChanged: (value) => ref.read(settingsControllerProvider.notifier).update(settings.copyWith(isDarkMode: value)),
              ),
              SwitchListTile(
                title: const Text('Notifications'),
                subtitle: const Text('Daily reminder and streak nudges'),
                value: settings.notificationsEnabled,
                onChanged: (value) async {
                  final next = settings.copyWith(notificationsEnabled: value);
                  try {
                    await ref.read(settingsControllerProvider.notifier).update(next);
                    final granted = await ref.read(notificationServiceProvider).syncPermissionAndToken(enabled: value);
                    if (value && !granted && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Notification permission denied. You can enable it in system settings.')),
                      );
                    }
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Failed to update notification settings.')),
                      );
                    }
                  }
                },
              ),
              ListTile(
                title: const Text('Audio speed'),
                subtitle: Text('${settings.audioSpeed.toStringAsFixed(2)}x'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Slider(
                  min: 0.75,
                  max: 2.0,
                  divisions: 5,
                  value: settings.audioSpeed,
                  onChanged: (value) => ref
                      .read(settingsControllerProvider.notifier)
                      .update(settings.copyWith(audioSpeed: value.clamp(0.75, 2.0))),
                ),
              ),
              ListTile(
                title: const Text('Daily goal'),
                subtitle: Text('${settings.dailyGoal} cards/day'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Slider(
                  min: 3,
                  max: 30,
                  divisions: 9,
                  value: settings.dailyGoal.toDouble(),
                  onChanged: (value) async {
                    final nextGoal = value.round();
                    await ref.read(settingsControllerProvider.notifier).update(settings.copyWith(dailyGoal: nextGoal));
                    await ref.read(userStatsServiceProvider).syncDailyGoal(nextGoal);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
