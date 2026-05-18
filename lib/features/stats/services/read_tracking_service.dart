import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'user_stats_service.dart';

final readTrackingServiceProvider = Provider<ReadTrackingService>((ref) {
  return ReadTrackingService(ref: ref);
});

class ReadTrackingService {
  ReadTrackingService({required Ref ref}) : _ref = ref;

  final Ref _ref;
  static const minimumViewDuration = Duration(seconds: 6);

  Future<void> markIfMeaningful({
    required String knowledgeId,
    required Duration viewedDuration,
    required bool interacted,
  }) async {
    if (viewedDuration < minimumViewDuration && !interacted) {
      return;
    }
    await _ref.read(userStatsServiceProvider).markKnowledgeRead(knowledgeId);
  }
}
