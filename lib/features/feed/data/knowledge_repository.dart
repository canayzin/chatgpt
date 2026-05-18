import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/knowledge_model.dart';

final knowledgeRepositoryProvider = Provider<KnowledgeRepository>((ref) {
  return FirebaseKnowledgeRepository(FirebaseFirestore.instance);
});

abstract class KnowledgeRepository {
  Future<FeedPage> getKnowledgePage({
    DocumentSnapshot<Map<String, dynamic>>? lastDocument,
    int limit = 20,
    String? category,
  });

  Future<FeedPage> getPersonalizedKnowledgePage({
    required String userId,
    DocumentSnapshot<Map<String, dynamic>>? lastDocument,
    int limit = 20,
  });

  Future<List<KnowledgeModel>> searchKnowledge(String query);

  Future<List<KnowledgeModel>> getByIds(List<String> ids);

  Future<List<KnowledgeModel>> getTrendingKnowledge({int limit = 30});

  Future<KnowledgeModel?> getKnowledgeOfDay();

  Future<List<KnowledgeModel>> getPodcastQueue({int limit = 10});
}

class FirebaseKnowledgeRepository implements KnowledgeRepository {
  FirebaseKnowledgeRepository(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<FeedPage> getKnowledgePage({
    DocumentSnapshot<Map<String, dynamic>>? lastDocument,
    int limit = 20,
    String? category,
  }) async {
    Query<Map<String, dynamic>> query =
        _firestore.collection('knowledge_cards').where('kategori', isEqualTo: 'psikoloji').orderBy('sira').limit(limit);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    final snapshot = await query.get(const GetOptions(source: Source.server));
    final docs = snapshot.docs;
    final selected = docs.map(KnowledgeModel.fromFirestore).toList();

    developer.log(
      selected.isEmpty ? 'NO PSYCHOLOGY DATA FOUND' : 'FIRST ITEM: ${selected.first.id} - ${selected.first.baslik}',
      name: 'FirebaseKnowledgeRepository.getKnowledgePage',
    );

    return FeedPage(
      items: selected,
      hasMore: docs.length == limit,
      lastDocument: docs.isEmpty ? lastDocument : docs.last,
    );
  }

  @override
  Future<FeedPage> getPersonalizedKnowledgePage({
    required String userId,
    DocumentSnapshot<Map<String, dynamic>>? lastDocument,
    int limit = 20,
  }) async {
    final profileSnap = await _firestore.collection('user_profiles').doc(userId).get();
    final profile = profileSnap.data() ?? const <String, dynamic>{};
    final categoryAffinity = Map<String, dynamic>.from(profile['categoryAffinity'] as Map? ?? const {});
    final recent = ((profile['recentInteractions'] as List?)?.whereType<String>().toList() ?? const <String>[])
        .map((value) => value.contains(':') ? value.split(':').last : value)
        .toSet();

    Query<Map<String, dynamic>> query =
        _firestore.collection('knowledge_cards').orderBy('createdAt', descending: true).limit(limit * 4);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    final snapshot = await query.get(const GetOptions(source: Source.serverAndCache));
    final docs = snapshot.docs;

    final ranked = docs
        .map(KnowledgeModel.fromFirestore)
        .where((item) => !recent.contains(item.id))
        .toList()
      ..sort((a, b) {
        final aScore = _personalizedScore(a, categoryAffinity);
        final bScore = _personalizedScore(b, categoryAffinity);
        return bScore.compareTo(aScore);
      });

    final selected = ranked.take(limit).toList();

    return FeedPage(
      items: selected,
      hasMore: docs.length >= limit,
      lastDocument: docs.isEmpty ? lastDocument : docs.last,
    );
  }

  @override
  Future<List<KnowledgeModel>> searchKnowledge(String query) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return const [];

    final keywordMatch = await _firestore
        .collection('knowledge_cards')
        .where('searchTokens', arrayContains: normalized)
        .limit(30)
        .get();

    if (keywordMatch.docs.isNotEmpty) {
      return keywordMatch.docs.map(KnowledgeModel.fromFirestore).toList();
    }

    final fallback = await _firestore
        .collection('knowledge_cards')
        .orderBy('createdAt', descending: true)
        .limit(80)
        .get(const GetOptions(source: Source.serverAndCache));

    return fallback.docs
        .map(KnowledgeModel.fromFirestore)
        .where((item) =>
            item.question.toLowerCase().contains(normalized) ||
            item.shortAnswer.toLowerCase().contains(normalized) ||
            (item.details ?? '').toLowerCase().contains(normalized))
        .toList();
  }

  @override
  Future<List<KnowledgeModel>> getByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];

    final chunks = <List<String>>[];
    for (var i = 0; i < ids.length; i += 10) {
      chunks.add(ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10));
    }

    final results = <KnowledgeModel>[];
    for (final chunk in chunks) {
      final snap = await _firestore
          .collection('knowledge_cards')
          .where(FieldPath.documentId, whereIn: chunk)
          .get(const GetOptions(source: Source.serverAndCache));
      results.addAll(snap.docs.map(KnowledgeModel.fromFirestore));
    }

    final byId = {for (final item in results) item.id: item};
    return ids.where(byId.containsKey).map((id) => byId[id]!).toList();
  }

  @override
  Future<List<KnowledgeModel>> getTrendingKnowledge({int limit = 30}) async {
    final snapshot = await _firestore
        .collection('knowledge_cards')
        .orderBy('favoriteCount', descending: true)
        .orderBy('readCount', descending: true)
        .limit(limit)
        .get(const GetOptions(source: Source.serverAndCache));

    return snapshot.docs.map(KnowledgeModel.fromFirestore).toList();
  }

  @override
  Future<KnowledgeModel?> getKnowledgeOfDay() async {
    final dailyFlagSnapshot = await _firestore
        .collection('knowledge_cards')
        .where('isDailyKnowledge', isEqualTo: true)
        .limit(1)
        .get(const GetOptions(source: Source.server));

    if (dailyFlagSnapshot.docs.isNotEmpty) {
      return KnowledgeModel.fromFirestore(dailyFlagSnapshot.docs.first);
    }

    final psikolojiFallback = await _firestore
        .collection('knowledge_cards')
        .where('kategori', isEqualTo: 'psikoloji')
        .orderBy('sira')
        .limit(1)
        .get(const GetOptions(source: Source.server));

    if (psikolojiFallback.docs.isEmpty) return null;
    return KnowledgeModel.fromFirestore(psikolojiFallback.docs.first);
  }

  @override
  Future<List<KnowledgeModel>> getPodcastQueue({int limit = 10}) async {
    final snapshot = await _firestore
        .collection('knowledge_cards')
        .where('audioUrl', isNull: false)
        .orderBy('createdAt', descending: true)
        .limit(limit * 2)
        .get(const GetOptions(source: Source.serverAndCache));

    return snapshot.docs.map(KnowledgeModel.fromFirestore).where((k) => k.hasAudio).take(limit).toList();
  }

  double _personalizedScore(KnowledgeModel item, Map<String, dynamic> categoryAffinity) {
    final preference = (categoryAffinity[item.category] as num?)?.toDouble() ?? 0;
    final recencyHours = DateTime.now().difference(item.createdAt).inHours;
    final recencyBoost = recencyHours <= 24
        ? 16.0
        : recencyHours <= 72
            ? 10.0
            : recencyHours <= 168
                ? 5.0
                : 1.0;

    return (item.favoriteCount * 1.8) +
        (item.readCount * 0.35) +
        (item.engagementScore * 10) +
        (item.qualityScore * 12) +
        (item.viralityScore * 10) +
        (preference * 0.7) +
        recencyBoost;
  }
}
