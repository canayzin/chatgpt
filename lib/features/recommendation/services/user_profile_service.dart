import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/user_profile_model.dart';

final userProfileServiceProvider = Provider<UserProfileService>((ref) {
  return UserProfileService(
    firestore: FirebaseFirestore.instance,
    auth: FirebaseAuth.instance,
  );
});

final userProfileProvider = StreamProvider<UserProfileModel>((ref) {
  return ref.watch(userProfileServiceProvider).watchProfile();
});

class UserProfileService {
  UserProfileService({required FirebaseFirestore firestore, required FirebaseAuth auth})
      : _firestore = firestore,
        _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String get _uid => _auth.currentUser!.uid;

  DocumentReference<Map<String, dynamic>> get _profileRef => _firestore.collection('user_profiles').doc(_uid);

  Stream<UserProfileModel> watchProfile() {
    return _profileRef.snapshots().map((doc) {
      if (!doc.exists) return UserProfileModel.empty(_uid);
      return UserProfileModel.fromFirestore(doc);
    });
  }

  Future<void> recordKnowledgeSignal({
    required String knowledgeId,
    required String category,
    required String eventType,
    int? dwellMs,
    bool isFavorite = false,
  }) async {
    await _firestore.runTransaction((txn) async {
      final snapshot = await txn.get(_profileRef);
      final data = snapshot.data() ?? <String, dynamic>{};

      final affinityRaw = Map<String, dynamic>.from(data['categoryAffinity'] as Map? ?? const {});
      final favoriteTopics = (data['favoriteTopics'] as List?)?.whereType<String>().toList() ?? <String>[];
      final recent = (data['recentInteractions'] as List?)?.whereType<String>().toList() ?? <String>[];
      final learningFrequency = Map<String, dynamic>.from(data['learningFrequency'] as Map? ?? const {});

      final weight = _eventWeight(eventType: eventType, dwellMs: dwellMs);

      final current = (affinityRaw[category] as num?)?.toDouble() ?? 0;
      affinityRaw[category] = (current + weight).clamp(0, 200);

      if (isFavorite && !favoriteTopics.contains(category)) {
        favoriteTopics.add(category);
      }

      final eventKey = '$eventType:$knowledgeId';
      final nextRecent = [eventKey, ...recent.where((item) => item != eventKey)].take(80).toList();

      final dayKey = DateTime.now().toUtc().toIso8601String().split('T').first;
      learningFrequency[dayKey] = ((learningFrequency[dayKey] as num?)?.toInt() ?? 0) + 1;
      if (learningFrequency.length > 35) {
        final keys = learningFrequency.keys.toList()..sort();
        for (final key in keys.take(learningFrequency.length - 35)) {
          learningFrequency.remove(key);
        }
      }

      txn.set(
        _profileRef,
        {
          'categoryAffinity': affinityRaw,
          'favoriteTopics': favoriteTopics.take(12).toList(),
          'recentInteractions': nextRecent,
          'learningFrequency': learningFrequency,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }


  double _eventWeight({required String eventType, int? dwellMs}) {
    return switch (eventType) {
      'favorite' => 2.5,
      'favorite_add' => 2.5,
      'favorite_remove' => -1.0,
      'share' => 2.0,
      'audio_complete' => 1.8,
      'audio_play' => 1.4,
      'read' => 1.2,
      'dwell' => ((dwellMs ?? 0) / 12000).clamp(0.2, 1.6),
      _ => 0.8,
    };
  }

  Future<void> recordQuizSignal({required String topic, required int correct, required int total}) {
    final accuracy = total == 0 ? 0 : correct / total;
    return _profileRef.set({
      'quizStrength.$topic': accuracy,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
