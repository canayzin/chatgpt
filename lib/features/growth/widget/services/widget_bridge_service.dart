import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../feed/domain/knowledge_model.dart';

final widgetBridgeServiceProvider = Provider<WidgetBridgeService>((ref) {
  return const WidgetBridgeService();
});

class WidgetBridgeService {
  const WidgetBridgeService();

  static const _channel = MethodChannel('ai_learn/widget');

  Future<void> updateKnowledgeOfDayWidget(KnowledgeModel item) async {
    try {
      await _channel.invokeMethod('updateKnowledgeOfDay', {
        'question': item.question,
        'answer': item.shortAnswer,
        'category': item.category,
      });
    } catch (_) {
      // Widget updates are best-effort in MVP phase.
    }
  }
}
