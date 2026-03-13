import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final growthInsightEngineProvider = Provider<GrowthInsightEngine>((ref) {
  return GrowthInsightEngine(FirebaseFirestore.instance);
});

class GrowthInsightEngine {
  GrowthInsightEngine(this._firestore);

  final FirebaseFirestore _firestore;

  Future<Map<String, dynamic>> getContentDashboardSnapshot({required String contentId}) async {
    final doc = await _firestore.collection('content_metrics').doc(contentId).get();
    return doc.data() ?? const {};
  }

  Future<Map<String, dynamic>> getDailyKpiSnapshot() async {
    final dateKey = DateTime.now().toUtc().toIso8601String().split('T').first;
    final doc = await _firestore.collection('analytics_daily').doc(dateKey).get();
    return doc.data() ?? const {};
  }
}
