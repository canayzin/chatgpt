import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../services/favorites_service.dart';
import '../../../feed/data/knowledge_repository.dart';
import '../../../feed/domain/knowledge_model.dart';
import '../../../feed/presentation/knowledge_card.dart';
import '../../sharing/services/share_card_service.dart';

final trendingProvider = FutureProvider<List<KnowledgeModel>>((ref) async {
  return ref.watch(knowledgeRepositoryProvider).getTrendingKnowledge();
});

class TrendingScreen extends ConsumerWidget {
  const TrendingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendingAsync = ref.watch(trendingProvider);
    final favoriteIds = ref.watch(favoriteIdsForTrendingProvider).valueOrNull ?? <String>{};

    return Scaffold(
      appBar: AppBar(title: const Text('Trending Knowledge')),
      body: trendingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load trending: $error')),
        data: (items) {
          if (items.isEmpty) return const Center(child: Text('No trending data yet.'));

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final isFavorite = favoriteIds.contains(item.id);
              return SizedBox(
                height: 360,
                child: KnowledgeCard(
                  item: item,
                  isFavorite: isFavorite,
                  onFavoriteTap: () => ref.read(favoritesServiceProvider).toggleFavorite(item.id, isFavorite),
                  onListenTap: () {},
                  onShareTap: () => ref.read(shareCardServiceProvider).shareKnowledgeCard(item),
                  onMeaningfulInteraction: () {},
                ),
              );
            },
          );
        },
      ),
    );
  }
}

final favoriteIdsForTrendingProvider = StreamProvider<Set<String>>((ref) {
  return ref.watch(favoritesServiceProvider).watchFavoriteIds();
});
