import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/content_draft_model.dart';

final adminContentRepositoryProvider = Provider<AdminContentRepository>((ref) {
  return AdminContentRepository(FirebaseFirestore.instance);
});

class AdminContentRepository {
  AdminContentRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _drafts =>
      _firestore.collection('moderation_queue');

  Stream<List<ContentDraftModel>> watchByStatus(ModerationStatus status) {
    return _drafts
        .where('status', isEqualTo: status.name)
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(ContentDraftModel.fromFirestore).toList());
  }

  Future<void> updateDraft(ContentDraftModel draft) {
    return _drafts.doc(draft.id).set(draft.toFirestore(), SetOptions(merge: true));
  }

  Future<void> setModerationStatus({
    required String draftId,
    required ModerationStatus status,
    String? reviewNotes,
  }) {
    return _drafts.doc(draftId).set({
      'status': status.name,
      'reviewNotes': reviewNotes,
      'reviewedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> markPublished({required String draftId, required String knowledgeId}) {
    return _drafts.doc(draftId).set({
      'status': ModerationStatus.published.name,
      'publishedKnowledgeId': knowledgeId,
      'publishedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
