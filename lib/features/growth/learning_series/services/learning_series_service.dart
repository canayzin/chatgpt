import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/learning_series_model.dart';

final learningSeriesServiceProvider = Provider<LearningSeriesService>((ref) {
  return LearningSeriesService(
    firestore: FirebaseFirestore.instance,
    auth: FirebaseAuth.instance,
  );
});

final learningSeriesProvider = StreamProvider<List<LearningSeries>>((ref) {
  return ref.watch(learningSeriesServiceProvider).watchSeries();
});

class LearningSeriesService {
  LearningSeriesService({required FirebaseFirestore firestore, required FirebaseAuth auth})
      : _firestore = firestore,
        _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Stream<List<LearningSeries>> watchSeries() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('learning_series')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((d) => LearningSeries.fromMap(d.id, d.data())).toList());
  }

  Future<void> completeDay(String seriesId, int currentDay, int totalDays) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final nextDay = (currentDay + 1).clamp(1, totalDays);
    final completed = nextDay >= totalDays;

    await _firestore.collection('users').doc(uid).collection('learning_series').doc(seriesId).set({
      'currentDay': nextDay,
      'completed': completed,
      'updatedAt': FieldValue.serverTimestamp(),
      if (completed) 'badgeEarnedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
