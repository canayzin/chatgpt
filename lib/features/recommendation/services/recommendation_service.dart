import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../feed/domain/knowledge_model.dart';

final recommendationServiceProvider = Provider<RecommendationService>((ref) {
  return RecommendationService(
    functions: FirebaseFunctions.instance,
    auth: FirebaseAuth.instance,
  );
});

class RecommendationService {
  RecommendationService({required FirebaseFunctions functions, required FirebaseAuth auth})
      : _functions = functions,
        _auth = auth;

  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  Future<void> refreshServerSideScores() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _functions.httpsCallable('recomputeUserFeedScores').call({'uid': uid});
  }

  double scoreKnowledge({
    required KnowledgeModel item,
    required Map<String, double> categoryAffinity,
    required Set<String> recentInteractionIds,
  }) {
    final categoryPreferenceScore = (categoryAffinity[item.category] ?? 0).clamp(0, 100) * 0.7;
    final engagementScore = (item.favoriteCount * 1.8) + (item.readCount * 0.35) + (item.engagementScore * 10);
    final qualityBoost = item.qualityScore * 12;
    final viralityBoost = item.viralityScore * 10;
    final recencyBoost = _recencyBoost(item.createdAt);
    final repeatPenalty = recentInteractionIds.contains(item.id) ? -30 : 0;

    return engagementScore + categoryPreferenceScore + qualityBoost + viralityBoost + recencyBoost + repeatPenalty;
  }

  double _recencyBoost(DateTime createdAt) {
    final ageHours = DateTime.now().difference(createdAt).inHours;
    if (ageHours <= 24) return 16;
    if (ageHours <= 72) return 10;
    if (ageHours <= 168) return 5;
    return 1;
  }
}
