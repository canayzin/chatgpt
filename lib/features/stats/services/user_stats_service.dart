import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../analytics/services/analytics_event_service.dart';
import '../../settings/services/settings_service.dart';
import '../domain/user_stats.dart';

final userStatsServiceProvider = Provider<UserStatsService>((ref) {
  return UserStatsService(
    firestore: FirebaseFirestore.instance,
    auth: FirebaseAuth.instance,
    analytics: ref.read(analyticsEventServiceProvider),
  );
});

final userStatsProvider = StreamProvider<UserStats>((ref) {
  return ref.watch(userStatsServiceProvider).watchStats(
        defaultDailyGoal: ref.watch(settingsControllerProvider).valueOrNull?.dailyGoal ?? 10,
      );
});

class UserStatsService {
  UserStatsService({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    required AnalyticsEventService analytics,
  })  : _firestore = firestore,
        _auth = auth,
        _analytics = analytics;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final AnalyticsEventService _analytics;

  String get _uid => _auth.currentUser!.uid;

  DocumentReference<Map<String, dynamic>> get _statsRef =>
      _firestore.collection('users').doc(_uid).collection('progress').doc('stats');

  Stream<UserStats> watchStats({required int defaultDailyGoal}) {
    return _statsRef.snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null) return UserStats.initial(dailyGoal: defaultDailyGoal);

      return UserStats(
        totalLearned: (data['totalLearned'] as num?)?.toInt() ?? 0,
        dailyLearned: (data['dailyLearned'] as num?)?.toInt() ?? 0,
        streakCount: (data['streakCount'] as num?)?.toInt() ?? 0,
        dailyGoal: (data['dailyGoal'] as num?)?.toInt() ?? defaultDailyGoal,
        lastLearnedAt: (data['lastLearnedAt'] as Timestamp?)?.toDate(),
      );
    });
  }

  Future<void> syncDailyGoal(int goal) async {
    await _statsRef.set({'dailyGoal': goal}, SetOptions(merge: true));
  }

  Future<void> markKnowledgeRead(String knowledgeId) async {
    final readRef = _statsRef.collection('readItems').doc(knowledgeId);

    var streakUpdated = false;
    var streakCount = 0;

    await _firestore.runTransaction((txn) async {
      final knowledgeRef = _firestore.collection('knowledge_cards').doc(knowledgeId);
      final statsSnapshot = await txn.get(_statsRef);
      final readSnapshot = await txn.get(readRef);
      if (readSnapshot.exists) return;

      final now = DateTime.now().toUtc();
      final data = statsSnapshot.data() ?? <String, dynamic>{};
      final lastLearnedAt = (data['lastLearnedAt'] as Timestamp?)?.toDate().toUtc();

      final isNewDay = lastLearnedAt == null || !_isSameUtcDate(lastLearnedAt, now);
      final dayDiff = lastLearnedAt == null
          ? null
          : DateTime.utc(now.year, now.month, now.day).difference(
              DateTime.utc(lastLearnedAt.year, lastLearnedAt.month, lastLearnedAt.day),
            ).inDays;

      final previousStreak = (data['streakCount'] as num?)?.toInt() ?? 0;
      final nextStreak = switch (dayDiff) {
        null => 1,
        0 => previousStreak == 0 ? 1 : previousStreak,
        1 => previousStreak + 1,
        _ => 1,
      };

      final nextDaily = isNewDay ? 1 : ((data['dailyLearned'] as num?)?.toInt() ?? 0) + 1;
      streakUpdated = isNewDay;
      streakCount = nextStreak;

      txn.set(readRef, {'readAt': FieldValue.serverTimestamp()});
      txn.set(knowledgeRef, {'readCount': FieldValue.increment(1)}, SetOptions(merge: true));
      txn.set(
        _statsRef,
        {
          'totalLearned': FieldValue.increment(1),
          'dailyLearned': nextDaily,
          'streakCount': nextStreak,
          'lastLearnedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });

    if (streakUpdated) {
      await _analytics.logEvent(
        eventType: 'streak_update',
        properties: {'streakCount': streakCount},
        dedupeKey: 'streak:$streakCount',
      );
    }
  }

  bool _isSameUtcDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
