import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../services/favorites_service.dart';
import '../../../feed/presentation/knowledge_card.dart';
import '../services/daily_knowledge_service.dart';
import '../../sharing/services/share_card_service.dart';

final _dailyFavoriteIdsProvider = StreamProvider<Set<String>>((ref) {
  return ref.watch(favoritesServiceProvider).watchFavoriteIds();
});

class DailyKnowledgeScreen extends ConsumerWidget {
  const DailyKnowledgeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailyAsync = ref.watch(dailyKnowledgeProvider);
    final favIds = ref.watch(_dailyFavoriteIdsProvider).valueOrNull ?? <String>{};

    return Scaffold(
      appBar: AppBar(title: const Text('Knowledge of the Day')),
      body: dailyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Unable to load daily knowledge: $error')),
        data: (item) {
          if (item == null) {
            return const Center(child: Text('Daily knowledge is not published yet.'));
          }
          return KnowledgeCard(
            item: item,
            isFavorite: favIds.contains(item.id),
            onFavoriteTap: () => ref.read(favoritesServiceProvider).toggleFavorite(item.id, favIds.contains(item.id)),
            onListenTap: () {},
                  onShareTap: () => ref.read(shareCardServiceProvider).shareKnowledgeCard(item),
            onMeaningfulInteraction: () {},
          );
        },
      ),
    );
  }
}
