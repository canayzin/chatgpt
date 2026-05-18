import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../feed/presentation/knowledge_card.dart';
import '../../../../services/favorites_service.dart';
import '../../../growth/sharing/services/share_card_service.dart';

final favoriteKnowledgeProvider = StreamProvider((ref) {
  return ref.watch(favoritesServiceProvider).watchFavoriteKnowledge();
});

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(favoriteKnowledgeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: favoritesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load favorites: $error')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Text('No favorites yet. Tap ⭐ in feed to save cards.'),
            );
          }

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final knowledge = items[index];
              return SizedBox(
                height: 350,
                child: KnowledgeCard(
                  item: knowledge,
                  isFavorite: true,
                  showCategoryChip: true,
                  onMeaningfulInteraction: () {},
                  onListenTap: () {},
                  onShareTap: () => ref.read(shareCardServiceProvider).shareKnowledgeCard(knowledge),
                  onFavoriteTap: () => ref
                      .read(favoritesServiceProvider)
                      .toggleFavorite(knowledge.id, true),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
