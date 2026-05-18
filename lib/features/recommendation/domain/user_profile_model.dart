import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfileModel {
  const UserProfileModel({
    required this.userId,
    required this.categoryAffinity,
    required this.quizStrength,
    required this.learningFrequency,
    required this.recentInteractions,
    required this.favoriteTopics,
    required this.updatedAt,
  });

  final String userId;
  final Map<String, double> categoryAffinity;
  final Map<String, double> quizStrength;
  final Map<String, int> learningFrequency;
  final List<String> recentInteractions;
  final List<String> favoriteTopics;
  final DateTime? updatedAt;

  factory UserProfileModel.empty(String userId) {
    return UserProfileModel(
      userId: userId,
      categoryAffinity: const {},
      quizStrength: const {},
      learningFrequency: const {},
      recentInteractions: const [],
      favoriteTopics: const [],
      updatedAt: null,
    );
  }

  factory UserProfileModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    Map<String, double> parseDoubleMap(dynamic value) {
      if (value is! Map) return const {};
      return value.map((key, raw) => MapEntry('$key', (raw as num?)?.toDouble() ?? 0));
    }

    Map<String, int> parseIntMap(dynamic value) {
      if (value is! Map) return const {};
      return value.map((key, raw) => MapEntry('$key', (raw as num?)?.toInt() ?? 0));
    }

    return UserProfileModel(
      userId: doc.id,
      categoryAffinity: parseDoubleMap(data['categoryAffinity']),
      quizStrength: parseDoubleMap(data['quizStrength']),
      learningFrequency: parseIntMap(data['learningFrequency']),
      recentInteractions: (data['recentInteractions'] as List?)?.whereType<String>().toList() ?? const [],
      favoriteTopics: (data['favoriteTopics'] as List?)?.whereType<String>().toList() ?? const [],
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
