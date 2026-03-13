import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(
    messaging: FirebaseMessaging.instance,
    firestore: FirebaseFirestore.instance,
    auth: FirebaseAuth.instance,
  );
});

class NotificationService {
  NotificationService({
    required FirebaseMessaging messaging,
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  })  : _messaging = messaging,
        _firestore = firestore,
        _auth = auth;

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<bool> syncPermissionAndToken({required bool enabled}) async {
    if (!enabled) return false;

    final settings = await _messaging.requestPermission(alert: true, badge: true, sound: true);
    final granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;

    if (!granted) return false;

    if (Platform.isIOS) {
      await _messaging.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);
    }

    final token = await _messaging.getToken();
    final uid = _auth.currentUser?.uid;
    if (uid == null || token == null) return true;

    await _firestore.collection('users').doc(uid).set({
      'notificationPrefs': {
        'dailyKnowledge': true,
        'streakReminder': true,
        'seriesReminder': true,
      },
      'fcmToken': token,
      'fcmUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return true;
  }
}
