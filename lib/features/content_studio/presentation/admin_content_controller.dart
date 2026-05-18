import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_content_repository.dart';
import '../domain/content_draft_model.dart';
import '../services/audio_generation_service.dart';
import '../services/content_generator_service.dart';
import '../services/content_publisher_service.dart';

final moderationQueueProvider =
    StreamProvider.family<List<ContentDraftModel>, ModerationStatus>((ref, status) {
  return ref.read(adminContentRepositoryProvider).watchByStatus(status);
});

final adminContentControllerProvider = Provider<AdminContentController>((ref) {
  return AdminContentController(ref);
});

class AdminContentController {
  AdminContentController(this._ref);

  final Ref _ref;

  Future<String> generateBatch({required int totalItems, required List<String> categories}) {
    return _ref.read(contentGeneratorServiceProvider).generateBatch(
          totalItems: totalItems,
          categories: categories,
        );
  }

  Future<void> approveDraft(String draftId) {
    return _ref
        .read(adminContentRepositoryProvider)
        .setModerationStatus(draftId: draftId, status: ModerationStatus.approved);
  }

  Future<void> rejectDraft(String draftId, {String? note}) {
    return _ref.read(adminContentRepositoryProvider).setModerationStatus(
          draftId: draftId,
          status: ModerationStatus.rejected,
          reviewNotes: note,
        );
  }

  Future<void> saveDraft(ContentDraftModel draft) {
    return _ref.read(adminContentRepositoryProvider).updateDraft(draft);
  }

  Future<String> publishDraft(ContentDraftModel draft) {
    return _ref.read(contentPublisherServiceProvider).publishDraft(draft);
  }

  Future<void> generateAudio(ContentDraftModel draft) async {
    final audioUrl = await _ref.read(audioGenerationServiceProvider).generateAudioForDraft(draft.id);
    if (audioUrl == null || audioUrl.isEmpty) return;
    await _ref.read(adminContentRepositoryProvider).updateDraft(draft.copyWith(audioUrl: audioUrl));
  }
}
