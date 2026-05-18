import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../services/audio_service.dart';
import '../../../services/favorites_service.dart';
import '../../growth/daily_knowledge/services/daily_knowledge_service.dart';
import '../../growth/sharing/services/share_card_service.dart';
import '../../analytics/services/analytics_event_service.dart';
import '../../recommendation/services/interaction_tracking_service.dart';
import '../../settings/services/settings_service.dart';
import '../../stats/services/read_tracking_service.dart';
import '../domain/knowledge_model.dart';
import 'feed_controller.dart';
import 'knowledge_card.dart';

final favoriteIdsProvider = StreamProvider<Set<String>>((ref) {
  return ref.watch(favoritesServiceProvider).watchFavoriteIds();
});

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({
    this.query = const FeedQuery(),
    this.title = 'AI Learn',
    this.showCategoryChip = false,
    super.key,
  });

  final FeedQuery query;
  final String title;
  final bool showCategoryChip;

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(analyticsEventServiceProvider).flushOfflineQueue());
  }

  final Map<String, DateTime> _enteredAtByKnowledgeId = {};
  KnowledgeModel? _currentKnowledge;

  @override
  void dispose() {
    _tryMarkCurrentAsRead(interacted: false);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(feedControllerProvider(widget.query));
    final favoriteIdsAsync = ref.watch(favoriteIdsProvider);
    final dailyAsync = ref.watch(dailyKnowledgeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(onPressed: () => context.push('/daily'), icon: const Icon(Icons.today), tooltip: 'Daily'),
          IconButton(
            onPressed: () => context.push('/trending'),
            icon: const Icon(Icons.trending_up),
            tooltip: 'Trending',
          ),
          IconButton(onPressed: () => context.push('/search'), icon: const Icon(Icons.search), tooltip: 'Search'),
        ],
      ),
      body: feedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('Failed to load feed. Pull to retry.\n$error'),
        ),
        data: (feedState) {
          if (feedState.items.isEmpty) {
            return const Center(
              child: Text('No knowledge yet. Content is coming soon.'),
            );
          }

          final favoriteIds = favoriteIdsAsync.valueOrNull ?? <String>{};

          return Column(
            children: [
              if (widget.query.personalized && widget.query.category == null)
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 6, 12, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Chip(label: Text('Personalized for you')),
                  ),
                ),
              if (widget.query.category == null)
                dailyAsync.maybeWhen(
                  data: (daily) => daily == null
                      ? const SizedBox.shrink()
                      : MaterialBanner(
                          content: Text('Knowledge of the Day: ${daily.question}'),
                          actions: [
                            TextButton(onPressed: () => context.push('/daily'), child: const Text('Open')),
                          ],
                        ),
                  orElse: SizedBox.shrink,
                ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => ref.refresh(feedControllerProvider(widget.query).future),
                  child: PageView.builder(
                    controller: _pageController,
                    scrollDirection: Axis.vertical,
                    itemCount: feedState.items.length,
                    onPageChanged: (index) {
                      _tryMarkCurrentAsRead(interacted: false);
                      ref.read(analyticsEventServiceProvider).logEvent(
                            eventType: 'feed_scroll',
                            dedupeKey: 'scroll:$index',
                            properties: {'index': index},
                          );
                      final nearEnd = index >= feedState.items.length - 3;
                      if (nearEnd) {
                        ref.read(feedControllerProvider(widget.query).notifier).loadMore();
                      }

                      final current = feedState.items[index];
                      if (current is KnowledgeFeedItem) {
                        _currentKnowledge = current.knowledge;
                        _enteredAtByKnowledgeId[current.knowledge.id] = DateTime.now();
                        ref.read(analyticsEventServiceProvider).logEvent(
                              eventType: 'knowledge_view',
                              contentId: current.knowledge.id,
                              category: current.knowledge.category,
                              dedupeKey: 'view:${current.knowledge.id}',
                            );
                      } else {
                        _currentKnowledge = null;
                      }
                    },
                    itemBuilder: (context, index) {
                      final item = feedState.items[index];
                      if (item is AdFeedItem) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Card(
                            child: Center(
                              child: Text('Sponsored • ad slot #${item.slot}'),
                            ),
                          ),
                        );
                      }

                      final knowledge = (item as KnowledgeFeedItem).knowledge;
                      final isFavorite = favoriteIds.contains(knowledge.id);

                      return KnowledgeCard(
                        item: knowledge,
                        isFavorite: isFavorite,
                        showCategoryChip: !widget.showCategoryChip,
                        onMeaningfulInteraction: () => _markRead(knowledge, interacted: true),
                        onFavoriteTap: () async {
                          await ref.read(favoritesServiceProvider).toggleFavorite(knowledge.id, isFavorite);
                          await ref.read(analyticsEventServiceProvider).logEvent(
                                eventType: !isFavorite ? 'favorite_add' : 'favorite_remove',
                                contentId: knowledge.id,
                                category: knowledge.category,
                              );
                          await ref.read(interactionTrackingServiceProvider).trackKnowledgeEvent(
                                knowledgeId: knowledge.id,
                                category: knowledge.category,
                                eventType: !isFavorite ? 'favorite_add' : 'favorite_remove',
                                isFavorite: !isFavorite,
                              );
                        },
                        onShareTap: () async {
                          await ref.read(shareCardServiceProvider).shareKnowledgeCard(knowledge);
                          await ref.read(analyticsEventServiceProvider).logEvent(
                                eventType: 'share_action',
                                contentId: knowledge.id,
                                category: knowledge.category,
                              );
                          await ref.read(interactionTrackingServiceProvider).trackKnowledgeEvent(
                                knowledgeId: knowledge.id,
                                category: knowledge.category,
                                eventType: 'share',
                              );
                        },
                        onListenTap: () async {
                          if (!knowledge.hasAudio) {
                            _showSnack(context, 'No audio available for this knowledge card yet.');
                            return;
                          }
                          try {
                            final speed = ref.read(settingsControllerProvider).valueOrNull?.audioSpeed ?? 1.0;
                            await ref.read(audioServiceProvider).setSpeed(speed);
                            await ref.read(audioServiceProvider).playFromUrl(
                                  knowledge.audioUrl!,
                                  onComplete: () => ref.read(analyticsEventServiceProvider).logEvent(
                                        eventType: 'audio_complete',
                                        contentId: knowledge.id,
                                        category: knowledge.category,
                                      ),
                                );
                            await ref.read(analyticsEventServiceProvider).logEvent(
                                  eventType: 'audio_play',
                                  contentId: knowledge.id,
                                  category: knowledge.category,
                                );
                            await _markRead(knowledge, interacted: true);
                            await ref.read(interactionTrackingServiceProvider).trackKnowledgeEvent(
                                  knowledgeId: knowledge.id,
                                  category: knowledge.category,
                                  eventType: 'audio_play',
                                );
                          } catch (_) {
                            _showSnack(context, 'Audio is loading slowly. Please try again.');
                          }
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _tryMarkCurrentAsRead({required bool interacted}) async {
    final knowledge = _currentKnowledge;
    if (knowledge == null) return;
    await _markRead(knowledge, interacted: interacted);
  }

  Future<void> _markRead(KnowledgeModel knowledge, {required bool interacted}) async {
    final enteredAt = _enteredAtByKnowledgeId[knowledge.id];
    if (enteredAt == null) return;
    final dwellMs = DateTime.now().difference(enteredAt).inMilliseconds;

    await ref.read(readTrackingServiceProvider).markIfMeaningful(
          knowledgeId: knowledge.id,
          viewedDuration: DateTime.now().difference(enteredAt),
          interacted: interacted,
        );

    await ref.read(interactionTrackingServiceProvider).trackKnowledgeEvent(
          knowledgeId: knowledge.id,
          category: knowledge.category,
          eventType: interacted ? 'read' : 'dwell',
          dwellMs: dwellMs,
        );

    if (interacted || dwellMs >= 9000) {
      await ref.read(analyticsEventServiceProvider).logEvent(
            eventType: 'knowledge_complete',
            contentId: knowledge.id,
            category: knowledge.category,
            properties: {'dwellMs': dwellMs},
            dedupeKey: 'complete:${knowledge.id}',
          );
    }
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
