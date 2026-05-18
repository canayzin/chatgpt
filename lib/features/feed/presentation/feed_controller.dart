import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/knowledge_repository.dart';
import '../domain/knowledge_model.dart';

final feedControllerProvider = AsyncNotifierProviderFamily<FeedController, FeedState, FeedQuery>(FeedController.new);

class FeedState {
  const FeedState({
    required this.items,
    required this.hasMore,
    this.lastDocument,
    this.isLoadingMore = false,
  });

  final List<FeedListItem> items;
  final bool hasMore;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool isLoadingMore;

  FeedState copyWith({
    List<FeedListItem>? items,
    bool? hasMore,
    DocumentSnapshot<Map<String, dynamic>>? lastDocument,
    bool? isLoadingMore,
  }) {
    return FeedState(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      lastDocument: lastDocument ?? this.lastDocument,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class FeedController extends FamilyAsyncNotifier<FeedState, FeedQuery> {
  static const adFrequency = 7;

  late final FeedQuery _query;

  @override
  Future<FeedState> build(FeedQuery arg) async {
    _query = arg;
    return _fetchInitial();
  }

  Future<FeedState> _fetchInitial() async {
    final page = await _fetchPage();
    developer.log(
      'FeedState items=${page.items.length} firstBaslik=${page.items.isEmpty ? '-' : page.items.first.baslik}',
      name: 'FeedController._fetchInitial',
    );
    return FeedState(
      items: _injectAds(page.items),
      hasMore: page.hasMore,
      lastDocument: page.lastDocument,
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) {
      return;
    }

    state = AsyncData(current.copyWith(isLoadingMore: true));

    try {
      final nextPage = await _fetchPage(lastDocument: current.lastDocument);
      final knowledgeOnly = [
        for (final item in current.items)
          if (item is KnowledgeFeedItem) item.knowledge,
        ...nextPage.items,
      ];

      state = AsyncData(
        current.copyWith(
          items: _injectAds(knowledgeOnly),
          hasMore: nextPage.hasMore,
          lastDocument: nextPage.lastDocument,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(isLoadingMore: false));
      rethrow;
    }
  }

  Future<FeedPage> _fetchPage({DocumentSnapshot<Map<String, dynamic>>? lastDocument}) {
    final repository = ref.read(knowledgeRepositoryProvider);
    return repository.getKnowledgePage(
      lastDocument: lastDocument,
      category: _query.category,
    );
  }

  List<FeedListItem> _injectAds(List<KnowledgeModel> knowledge) {
    final result = <FeedListItem>[];
    var adSlot = 0;

    for (var i = 0; i < knowledge.length; i++) {
      result.add(KnowledgeFeedItem(knowledge[i]));
      final position = i + 1;
      if (position % adFrequency == 0) {
        adSlot++;
        result.add(AdFeedItem(slot: adSlot));
      }
    }

    return result;
  }
}
