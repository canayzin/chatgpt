import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../services/audio_service.dart';
import '../services/podcast_service.dart';

class PodcastScreen extends ConsumerWidget {
  const PodcastScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(podcastQueueProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Daily Mini Podcast')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('A 5-minute learning session with 10 short audio cards.'),
            const SizedBox(height: 16),
            queueAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (error, _) => Text('Audio queue unavailable: $error'),
              data: (queue) => Text('Queued audio cards: ${queue.length}'),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => ref.read(podcastServiceProvider).playDailySession(),
              icon: const Icon(Icons.play_circle_fill),
              label: const Text('Start Session'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => ref.read(audioServiceProvider).skipToNext(),
              icon: const Icon(Icons.skip_next),
              label: const Text('Skip'),
            ),
          ],
        ),
      ),
    );
  }
}
