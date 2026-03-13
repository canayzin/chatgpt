import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'user_profile_service.dart';

final interactionTrackingServiceProvider = Provider<InteractionTrackingService>((ref) {
  return InteractionTrackingService(
    firestore: FirebaseFirestore.instance,
    auth: FirebaseAuth.instance,
    ref: ref,
  );
});

class InteractionTrackingService {
  InteractionTrackingService({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    required Ref ref,
  })  : _firestore = firestore,
        _auth = auth,
        _ref = ref;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final Ref _ref;

  String get _uid => _auth.currentUser!.uid;

  Future<void> trackKnowledgeEvent({
    required String knowledgeId,
    required String category,
    required String eventType,
    int? dwellMs,
    bool isFavorite = false,
  }) async {
    await _firestore.collection('interaction_events').add({
      'uid': _uid,
      'knowledgeId': knowledgeId,
      'category': category,
      'eventType': eventType,
      'dwellMs': dwellMs,
      'isFavorite': isFavorite,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _ref.read(userProfileServiceProvider).recordKnowledgeSignal(
          knowledgeId: knowledgeId,
          category: category,
          eventType: eventType,
          dwellMs: dwellMs,
          isFavorite: isFavorite,
        );
  }

  Future<void> trackQuizCompletion({required String topic, required int correct, required int total}) async {
    await _firestore.collection('interaction_events').add({
      'uid': _uid,
      'eventType': 'quiz_complete',
      'topic': topic,
      'correct': correct,
      'total': total,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _ref.read(userProfileServiceProvider).recordQuizSignal(topic: topic, correct: correct, total: total);
  }
}
