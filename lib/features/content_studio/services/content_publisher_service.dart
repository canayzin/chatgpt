import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_content_repository.dart';
import '../domain/content_draft_model.dart';

final contentPublisherServiceProvider = Provider<ContentPublisherService>((ref) {
  return ContentPublisherService(
    firestore: FirebaseFirestore.instance,
    repository: ref.read(adminContentRepositoryProvider),
  );
});

class ContentPublisherService {
  ContentPublisherService({required FirebaseFirestore firestore, required AdminContentRepository repository})
      : _firestore = firestore,
        _repository = repository;

  final FirebaseFirestore _firestore;
  final AdminContentRepository _repository;

  Future<String> publishDraft(ContentDraftModel draft) async {
    final ref = _firestore.collection('knowledge_cards').doc();
    await ref.set({
      'category': draft.category,
      'question': draft.question,
      'shortAnswer': draft.shortAnswer,
      'details': draft.detailExplanation,
      'quizQuestion': draft.quizQuestion,
      'quizOptions': draft.quizOptions,
      'quizCorrectAnswer': draft.quizCorrectAnswer,
      'tags': draft.tags,
      'searchTokens': _buildSearchTokens(draft),
      'estimatedReadingTime': draft.estimatedReadingTime,
      'audioUrl': draft.audioUrl,
      'qualityScore': draft.qualityScore,
      'viralityScore': draft.viralityScore,
      'engagementScore': draft.engagementScore,
      'readCount': 0,
      'favoriteCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'publishedFromBatchId': draft.batchId,
    });

    await _repository.markPublished(draftId: draft.id, knowledgeId: ref.id);
    return ref.id;
  }

  List<String> _buildSearchTokens(ContentDraftModel draft) {
    final text = '${draft.question} ${draft.shortAnswer} ${draft.tags.join(' ')}'.toLowerCase();
    final words = text.split(RegExp(r'\s+')).where((word) => word.length > 2).toSet();
    return words.take(30).toList();
  }
}
