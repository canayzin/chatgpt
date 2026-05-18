import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/quiz_models.dart';

final quizRepositoryProvider = Provider<QuizRepository>((ref) {
  return FirebaseQuizRepository(FirebaseFirestore.instance);
});

abstract class QuizRepository {
  Future<List<QuizQuestion>> getQuiz({required String topic, int limit = 10});
}

class FirebaseQuizRepository implements QuizRepository {
  FirebaseQuizRepository(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<List<QuizQuestion>> getQuiz({required String topic, int limit = 10}) async {
    final snapshot = await _firestore
        .collection('quiz_questions')
        .where('topic', isEqualTo: topic)
        .limit(limit)
        .get(const GetOptions(source: Source.serverAndCache));

    return snapshot.docs.map((d) => QuizQuestion.fromMap(d.id, d.data())).where((q) => q.options.length >= 2).toList();
  }
}
