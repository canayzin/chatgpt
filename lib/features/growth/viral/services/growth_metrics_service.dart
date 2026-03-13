import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final growthMetricsServiceProvider = Provider<GrowthMetricsService>((ref) {
  return GrowthMetricsService(FirebaseFirestore.instance);
});

class GrowthMetricsService {
  GrowthMetricsService(this._firestore);

  final FirebaseFirestore _firestore;

  Future<Map<String, dynamic>> getLatestGrowthMetrics() async {
    final dateKey = DateTime.now().toUtc().toIso8601String().split('T').first;
    final doc = await _firestore.collection('growth_metrics').doc(dateKey).get();
    return doc.data() ?? const {};
  }

  Stream<List<Map<String, dynamic>>> watchTopViralContent() {
    return _firestore
        .collection('content_metrics')
        .orderBy('shareRate', descending: true)
        .limit(20)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => {'contentId': doc.id, ...doc.data()}).toList());
  }
}
