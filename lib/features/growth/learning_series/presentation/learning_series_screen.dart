import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/learning_series_service.dart';

class LearningSeriesScreen extends ConsumerWidget {
  const LearningSeriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seriesAsync = ref.watch(learningSeriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Learning Series')),
      body: seriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Unable to load series: $error')),
        data: (series) {
          if (series.isEmpty) {
            return const Center(child: Text('No active learning series yet.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: series.length,
            itemBuilder: (context, index) {
              final item = series[index];
              final progress = item.totalDays == 0 ? 0.0 : (item.currentDay / item.totalDays).clamp(0.0, 1.0);

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text('Day ${item.currentDay}/${item.totalDays}'),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: progress),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: item.completed
                            ? null
                            : () => ref
                                .read(learningSeriesServiceProvider)
                                .completeDay(item.id, item.currentDay, item.totalDays),
                        child: Text(item.completed ? 'Completed • Badge earned' : 'Complete today'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
