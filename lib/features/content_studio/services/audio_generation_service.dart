import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final audioGenerationServiceProvider = Provider<AudioGenerationService>((ref) {
  return AudioGenerationService(FirebaseFunctions.instance);
});

class AudioGenerationService {
  AudioGenerationService(this._functions);

  final FirebaseFunctions _functions;

  Future<String?> generateAudioForDraft(String draftId) async {
    final callable = _functions.httpsCallable('generateKnowledgeAudio');
    final result = await callable.call({'draftId': draftId});
    return (result.data as Map?)?['audioUrl'] as String?;
  }
}
