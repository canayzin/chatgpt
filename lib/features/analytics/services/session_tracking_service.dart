import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final sessionTrackingServiceProvider = Provider<SessionTrackingService>((ref) {
  return SessionTrackingService(
    firestore: FirebaseFirestore.instance,
    auth: FirebaseAuth.instance,
  );
});

class SessionTrackingService {
  SessionTrackingService({required FirebaseFirestore firestore, required FirebaseAuth auth})
      : _firestore = firestore,
        _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String? _sessionId;

  String get _uid => _auth.currentUser?.uid ?? 'anonymous';

  Future<String> getOrCreateSessionId() async {
    if (_sessionId != null) return _sessionId!;

    final now = DateTime.now().toUtc();
    final random = Random().nextInt(1 << 32).toRadixString(16);
    _sessionId = '${_uid}_${now.millisecondsSinceEpoch}_$random';

    await _firestore.collection('user_sessions').doc(_sessionId).set({
      'userId': _uid,
      'startedAt': FieldValue.serverTimestamp(),
      'lastSeenAt': FieldValue.serverTimestamp(),
      'deviceInfo': _deviceInfo(),
    }, SetOptions(merge: true));

    return _sessionId!;
  }

  Future<void> touchSession() async {
    final sessionId = await getOrCreateSessionId();
    await _firestore.collection('user_sessions').doc(sessionId).set({
      'lastSeenAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Map<String, dynamic> _deviceInfo() {
    return {
      'platform': 'flutter',
      'sdk': 'dart',
    };
  }
}
