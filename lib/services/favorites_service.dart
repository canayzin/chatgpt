import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/feed/data/knowledge_repository.dart';
import '../features/feed/domain/knowledge_model.dart';

final favoritesServiceProvider = Provider<FavoritesService>((ref) {
  return FavoritesService(
    firestore: FirebaseFirestore.instance,
    auth: FirebaseAuth.instance,
    repository: ref.watch(knowledgeRepositoryProvider),
  );
});

class FavoritesService {
  FavoritesService({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    required KnowledgeRepository repository,
  })  : _firestore = firestore,
        _auth = auth,
        _repository = repository;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final KnowledgeRepository _repository;

  String get _userId => _auth.currentUser!.uid;

  CollectionReference<Map<String, dynamic>> get _favoritesRef =>
      _firestore.collection('users').doc(_userId).collection('favorites');

  Stream<Set<String>> watchFavoriteIds() {
    return _favoritesRef.snapshots().map((snapshot) => snapshot.docs.map((d) => d.id).toSet());
  }

  Stream<List<KnowledgeModel>> watchFavoriteKnowledge() {
    return watchFavoriteIds().asyncMap((ids) async {
      if (ids.isEmpty) return const [];
      return _repository.getByIds(ids.toList());
    });
  }

  Future<void> toggleFavorite(String knowledgeId, bool isFavorite) async {
    final ref = _favoritesRef.doc(knowledgeId);
    final knowledgeRef = _firestore.collection('knowledge_cards').doc(knowledgeId);

    if (isFavorite) {
      await _firestore.runTransaction((txn) async {
        txn.delete(ref);
        txn.set(knowledgeRef, {'favoriteCount': FieldValue.increment(-1)}, SetOptions(merge: true));
      });
      return;
    }

    await _firestore.runTransaction((txn) async {
      txn.set(
        ref,
        {
          'savedAt': FieldValue.serverTimestamp(),
          'folderId': null,
        },
        SetOptions(merge: true),
      );
      txn.set(knowledgeRef, {'favoriteCount': FieldValue.increment(1)}, SetOptions(merge: true));
    });
  }
}
