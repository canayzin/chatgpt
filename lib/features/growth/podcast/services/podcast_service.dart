import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../services/audio_service.dart';
import '../../../feed/data/knowledge_repository.dart';

final podcastQueueProvider = FutureProvider<List<String>>((ref) async {
  final items = await ref.watch(knowledgeRepositoryProvider).getPodcastQueue(limit: 10);
  return items.where((i) => i.hasAudio).map((e) => e.audioUrl!).toList();
});

final podcastServiceProvider = Provider<PodcastService>((ref) {
  return PodcastService(ref: ref);
});

class PodcastService {
  PodcastService({required Ref ref}) : _ref = ref;

  final Ref _ref;

  Future<void> playDailySession() async {
    final queue = await _ref.read(podcastQueueProvider.future);
    if (queue.isEmpty) return;
    await _ref.read(audioServiceProvider).playPlaylist(queue);
  }
}
