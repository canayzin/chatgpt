import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../growth/sharing/services/share_card_service.dart';
import '../../../settings/services/settings_service.dart';
import '../../../stats/services/user_stats_service.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(userStatsProvider);
    final settings = ref.watch(settingsControllerProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load profile: $error')),
        data: (stats) {
          final goal = settings?.dailyGoal ?? stats.dailyGoal;
          final progress = goal == 0 ? 0.0 : (stats.dailyLearned / goal).clamp(0.0, 1.0);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _StatCard(label: 'Total learned', value: '${stats.totalLearned}'),
              _StatCard(label: 'Today', value: '${stats.dailyLearned}/$goal'),
              _StatCard(label: 'Streak', value: '${stats.streakCount} days'),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Daily goal progress'),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: progress),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Growth tools'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: () => context.push('/series'),
                            icon: const Icon(Icons.timeline),
                            label: const Text('Series'),
                          ),
                          FilledButton.icon(
                            onPressed: () => context.push('/podcast'),
                            icon: const Icon(Icons.podcasts),
                            label: const Text('Mini podcast'),
                          ),
                          FilledButton.icon(
                            onPressed: () => context.push('/quiz/psychology'),
                            icon: const Icon(Icons.quiz),
                            label: const Text('Quiz mode'),
                          ),
                          FilledButton.icon(
                            onPressed: () => context.push('/invite'),
                            icon: const Icon(Icons.group_add),
                            label: const Text('Invite friends'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => ref.read(shareCardServiceProvider).shareStreak(streakCount: stats.streakCount),
                        icon: const Icon(Icons.local_fire_department),
                        label: const Text('Share streak'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Weekly summary'),
                      SizedBox(height: 8),
                      Text('Weekly insights and charts will appear here in next phase.'),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(label),
        trailing: Text(value, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}
