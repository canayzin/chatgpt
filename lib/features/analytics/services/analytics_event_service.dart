import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/analytics_event.dart';
import 'session_tracking_service.dart';

final analyticsEventServiceProvider = Provider<AnalyticsEventService>((ref) {
  return AnalyticsEventService(
    firestore: FirebaseFirestore.instance,
    auth: FirebaseAuth.instance,
    ref: ref,
  );
});

class AnalyticsEventService {
  AnalyticsEventService({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    required Ref ref,
  })  : _firestore = firestore,
        _auth = auth,
        _ref = ref;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final Ref _ref;

  static const _offlineQueueKey = 'analytics.offline_queue';

  String get _uid => _auth.currentUser?.uid ?? 'anonymous';

  Future<void> logEvent({
    required String eventType,
    String? contentId,
    String? category,
    String? dedupeKey,
    Map<String, dynamic> properties = const {},
  }) async {
    final sessionId = await _ref.read(sessionTrackingServiceProvider).getOrCreateSessionId();
    final eventId = dedupeKey == null ? null : '$sessionId:$dedupeKey';

    final event = AnalyticsEvent(
      userId: _uid,
      eventType: eventType,
      contentId: contentId,
      category: category,
      timestamp: DateTime.now().toUtc(),
      sessionId: sessionId,
      eventId: eventId,
      deviceInfo: const {
        'platform': 'flutter',
        'runtime': 'dart',
      },
      properties: properties,
    );

    try {
      await _writeEvent(event);
      await _ref.read(sessionTrackingServiceProvider).touchSession();
      await flushOfflineQueue();
    } catch (_) {
      await _enqueueOffline(event);
    }
  }

  Future<void> flushOfflineQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getStringList(_offlineQueueKey) ?? const [];
    if (pending.isEmpty) return;

    final keep = <String>[];
    for (final item in pending) {
      try {
        final map = jsonDecode(item) as Map<String, dynamic>;
        final event = AnalyticsEvent(
          userId: map['userId'] as String? ?? _uid,
          eventType: map['eventType'] as String? ?? 'unknown',
          contentId: map['contentId'] as String?,
          category: map['category'] as String?,
          timestamp: DateTime.tryParse(map['timestamp'] as String? ?? '') ?? DateTime.now().toUtc(),
          sessionId: map['sessionId'] as String? ?? await _ref.read(sessionTrackingServiceProvider).getOrCreateSessionId(),
          deviceInfo: Map<String, dynamic>.from(map['deviceInfo'] as Map? ?? const {}),
          properties: Map<String, dynamic>.from(map['properties'] as Map? ?? const {}),
          eventId: map['eventId'] as String?,
        );
        await _writeEvent(event);
      } catch (_) {
        keep.add(item);
      }
    }

    await prefs.setStringList(_offlineQueueKey, keep.take(150).toList());
  }

  Future<void> _writeEvent(AnalyticsEvent event) {
    final ref = event.eventId == null
        ? _firestore.collection('analytics_events').doc()
        : _firestore.collection('analytics_events').doc(event.eventId);

    return ref.set(event.toFirestore(), SetOptions(merge: event.eventId != null));
  }

  Future<void> _enqueueOffline(AnalyticsEvent event) async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getStringList(_offlineQueueKey) ?? <String>[];
    pending.add(
      jsonEncode({
        ...event.toFirestore(),
        'timestamp': event.timestamp.toIso8601String(),
      }),
    );
    await prefs.setStringList(_offlineQueueKey, pending.take(150).toList());
  }
}
