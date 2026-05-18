import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../feed/data/knowledge_repository.dart';
import '../../../feed/domain/knowledge_model.dart';
import '../../widget/services/widget_bridge_service.dart';

final dailyKnowledgeProvider = FutureProvider<KnowledgeModel?>((ref) async {
  final item = await ref.watch(knowledgeRepositoryProvider).getKnowledgeOfDay();
  if (item != null) {
    await ref.read(widgetBridgeServiceProvider).updateKnowledgeOfDayWidget(item);
  }
  return item;
});
