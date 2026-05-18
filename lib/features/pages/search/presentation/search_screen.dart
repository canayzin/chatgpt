import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../feed/data/knowledge_repository.dart';
import '../../../feed/domain/knowledge_model.dart';
import '../../../feed/presentation/knowledge_card.dart';
import '../../../../services/favorites_service.dart';
import '../../../growth/sharing/services/share_card_service.dart';

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = FutureProvider.autoDispose<List<KnowledgeModel>>((ref) async {
  final query = ref.watch(searchQueryProvider).trim();
  if (query.isEmpty) return const [];
  return ref.watch(knowledgeRepositoryProvider).searchKnowledge(query);
});


final favoriteIdsForSearchProvider = StreamProvider<Set<String>>((ref) {
  return ref.watch(favoritesServiceProvider).watchFavoriteIds();
});
class SearchScreen extends ConsumerWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(searchQueryProvider);
    final resultAsync = ref.watch(searchResultsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Search knowledge')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search psychology, finance, biases...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => ref.read(searchQueryProvider.notifier).state = value,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              children: const ['mindset', 'money', 'sales', 'decision'].map((term) {
                return _SuggestionChip(term: term);
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: query.trim().isEmpty
                ? const Center(child: Text('Start typing to search cards.'))
                : resultAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, _) => Center(child: Text('Search failed: $error')),
                    data: (results) {
                      if (results.isEmpty) {
                        return const Center(child: Text('No matching results found.'));
                      }

                      return ListView.builder(
                        itemCount: results.length,
                        itemBuilder: (context, index) {
                          final knowledge = results[index];
                          return Consumer(
                            builder: (context, ref, _) {
                              final favoriteIds = ref.watch(favoriteIdsForSearchProvider);
                              final isFavorite = favoriteIds.valueOrNull?.contains(knowledge.id) ?? false;
                              return SizedBox(
                                height: 360,
                                child: KnowledgeCard(
                                  item: knowledge,
                                  isFavorite: isFavorite,
                                  onMeaningfulInteraction: () {},
                                  onFavoriteTap: () => ref
                                      .read(favoritesServiceProvider)
                                      .toggleFavorite(knowledge.id, isFavorite),
                                  onListenTap: () {},
                  onShareTap: () => ref.read(shareCardServiceProvider).shareKnowledgeCard(knowledge),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionChip extends ConsumerWidget {
  const _SuggestionChip({required this.term});

  final String term;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ActionChip(
      label: Text(term),
      onPressed: () => ref.read(searchQueryProvider.notifier).state = term,
    );
  }
}
