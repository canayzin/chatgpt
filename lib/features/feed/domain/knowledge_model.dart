import 'package:cloud_firestore/cloud_firestore.dart';

class KnowledgeModel {
  const KnowledgeModel({
    required this.id,
    required this.category,
    required this.question,
    required this.shortAnswer,
    required this.createdAt,
    this.details,
    this.audioUrl,
    this.favoriteCount = 0,
    this.readCount = 0,
    this.isDailyKnowledge = false,
    this.qualityScore = 0,
    this.viralityScore = 0,
    this.engagementScore = 0,
    this.estimatedReadingTime = 30,
    this.tags = const [],
  });

  final String id;
  final String category;
  final String question;
  final String shortAnswer;
  final String? details;
  final String? audioUrl;
  final DateTime createdAt;
  final int favoriteCount;
  final int readCount;
  final bool isDailyKnowledge;
  final double qualityScore;
  final double viralityScore;
  final double engagementScore;
  final int estimatedReadingTime;
  final List<String> tags;

  bool get hasAudio => (audioUrl ?? '').isNotEmpty;

  factory KnowledgeModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return KnowledgeModel(
      id: doc.id,
      category: data['category'] as String? ?? 'general',
      question: data['question'] as String? ?? '',
      shortAnswer: data['shortAnswer'] as String? ?? '',
      details: data['details'] as String?,
      audioUrl: data['audioUrl'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
      favoriteCount: (data['favoriteCount'] as num?)?.toInt() ?? 0,
      readCount: (data['readCount'] as num?)?.toInt() ?? 0,
      isDailyKnowledge: data['isDailyKnowledge'] as bool? ?? false,
      qualityScore: (data['qualityScore'] as num?)?.toDouble() ?? 0,
      viralityScore: (data['viralityScore'] as num?)?.toDouble() ?? 0,
      engagementScore: (data['engagementScore'] as num?)?.toDouble() ?? 0,
      estimatedReadingTime: (data['estimatedReadingTime'] as num?)?.toInt() ?? 30,
      tags: (data['tags'] as List?)?.whereType<String>().toList() ?? const [],
    );
  }

  int get trendingScore => (favoriteCount * 3) + readCount;
}

class FeedPage {
  const FeedPage({
    required this.items,
    required this.hasMore,
    this.lastDocument,
  });

  final List<KnowledgeModel> items;
  final bool hasMore;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
}

sealed class FeedListItem {
  const FeedListItem();
}

class KnowledgeFeedItem extends FeedListItem {
  const KnowledgeFeedItem(this.knowledge);
  final KnowledgeModel knowledge;
}

class AdFeedItem extends FeedListItem {
  const AdFeedItem({required this.slot});
  final int slot;
}

class FeedQuery {
  const FeedQuery({this.category, this.personalized = true});

  final String? category;
  final bool personalized;
}
