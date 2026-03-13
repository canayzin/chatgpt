import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final contentGeneratorServiceProvider = Provider<ContentGeneratorService>((ref) {
  return ContentGeneratorService(FirebaseFunctions.instance);
});

class ContentGeneratorService {
  ContentGeneratorService(this._functions);

  final FirebaseFunctions _functions;

  Future<String> generateBatch({
    required int totalItems,
    required List<String> categories,
  }) async {
    final callable = _functions.httpsCallable('generateKnowledgeBatch');
    final result = await callable.call({
      'totalItems': totalItems,
      'categories': categories,
    });

    final data = (result.data as Map?) ?? const {};
    return data['batchId'] as String? ?? 'unknown-batch';
  }
}
