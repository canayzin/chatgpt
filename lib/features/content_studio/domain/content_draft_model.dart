import 'package:cloud_firestore/cloud_firestore.dart';

enum ModerationStatus { pending, approved, rejected, published }

class ContentDraftModel {
  const ContentDraftModel({
    required this.id,
    required this.category,
    required this.question,
    required this.shortAnswer,
    required this.detailExplanation,
    required this.quizQuestion,
    required this.quizOptions,
    required this.quizCorrectAnswer,
    required this.tags,
    required this.estimatedReadingTime,
    required this.status,
    required this.batchId,
    required this.qualityScore,
    required this.viralityScore,
    required this.engagementScore,
    required this.createdAt,
    this.reviewNotes,
    this.audioText,
    this.audioUrl,
    this.publishedKnowledgeId,
  });

  final String id;
  final String category;
  final String question;
  final String shortAnswer;
  final String detailExplanation;
  final String quizQuestion;
  final List<String> quizOptions;
  final int quizCorrectAnswer;
  final List<String> tags;
  final int estimatedReadingTime;
  final ModerationStatus status;
  final String batchId;
  final double qualityScore;
  final double viralityScore;
  final double engagementScore;
  final DateTime createdAt;
  final String? reviewNotes;
  final String? audioText;
  final String? audioUrl;
  final String? publishedKnowledgeId;

  ContentDraftModel copyWith({
    String? category,
    String? question,
    String? shortAnswer,
    String? detailExplanation,
    String? quizQuestion,
    List<String>? quizOptions,
    int? quizCorrectAnswer,
    List<String>? tags,
    int? estimatedReadingTime,
    ModerationStatus? status,
    String? reviewNotes,
    String? audioText,
    String? audioUrl,
    String? publishedKnowledgeId,
  }) {
    return ContentDraftModel(
      id: id,
      category: category ?? this.category,
      question: question ?? this.question,
      shortAnswer: shortAnswer ?? this.shortAnswer,
      detailExplanation: detailExplanation ?? this.detailExplanation,
      quizQuestion: quizQuestion ?? this.quizQuestion,
      quizOptions: quizOptions ?? this.quizOptions,
      quizCorrectAnswer: quizCorrectAnswer ?? this.quizCorrectAnswer,
      tags: tags ?? this.tags,
      estimatedReadingTime: estimatedReadingTime ?? this.estimatedReadingTime,
      status: status ?? this.status,
      batchId: batchId,
      qualityScore: qualityScore,
      viralityScore: viralityScore,
      engagementScore: engagementScore,
      createdAt: createdAt,
      reviewNotes: reviewNotes ?? this.reviewNotes,
      audioText: audioText ?? this.audioText,
      audioUrl: audioUrl ?? this.audioUrl,
      publishedKnowledgeId: publishedKnowledgeId ?? this.publishedKnowledgeId,
    );
  }

  factory ContentDraftModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ContentDraftModel(
      id: doc.id,
      category: data['category'] as String? ?? 'psychology',
      question: data['question'] as String? ?? '',
      shortAnswer: data['shortAnswer'] as String? ?? '',
      detailExplanation: data['detailExplanation'] as String? ?? '',
      quizQuestion: data['quizQuestion'] as String? ?? '',
      quizOptions: (data['quizOptions'] as List?)?.whereType<String>().toList() ?? const [],
      quizCorrectAnswer: (data['quizCorrectAnswer'] as num?)?.toInt() ?? 0,
      tags: (data['tags'] as List?)?.whereType<String>().toList() ?? const [],
      estimatedReadingTime: (data['estimatedReadingTime'] as num?)?.toInt() ?? 30,
      status: _parseStatus(data['status'] as String?),
      batchId: data['batchId'] as String? ?? 'manual',
      qualityScore: (data['qualityScore'] as num?)?.toDouble() ?? 0,
      viralityScore: (data['viralityScore'] as num?)?.toDouble() ?? 0,
      engagementScore: (data['engagementScore'] as num?)?.toDouble() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
      reviewNotes: data['reviewNotes'] as String?,
      audioText: data['audioText'] as String?,
      audioUrl: data['audioUrl'] as String?,
      publishedKnowledgeId: data['publishedKnowledgeId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'category': category,
      'question': question,
      'shortAnswer': shortAnswer,
      'detailExplanation': detailExplanation,
      'quizQuestion': quizQuestion,
      'quizOptions': quizOptions,
      'quizCorrectAnswer': quizCorrectAnswer,
      'tags': tags,
      'estimatedReadingTime': estimatedReadingTime,
      'status': status.name,
      'batchId': batchId,
      'qualityScore': qualityScore,
      'viralityScore': viralityScore,
      'engagementScore': engagementScore,
      'reviewNotes': reviewNotes,
      'audioText': audioText,
      'audioUrl': audioUrl,
      'publishedKnowledgeId': publishedKnowledgeId,
    };
  }

  static ModerationStatus _parseStatus(String? value) {
    return ModerationStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => ModerationStatus.pending,
    );
  }
}
