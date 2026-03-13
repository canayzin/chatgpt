import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_functions/firebase_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/referral_models.dart';

final referralServiceProvider = Provider<ReferralService>((ref) {
  return ReferralService(
    firestore: FirebaseFirestore.instance,
    auth: FirebaseAuth.instance,
    functions: FirebaseFunctions.instance,
  );
});

final referralProfileProvider = StreamProvider<ReferralProfile>((ref) {
  return ref.watch(referralServiceProvider).watchReferralProfile();
});

class ReferralService {
  ReferralService({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    required FirebaseFunctions functions,
  })  : _firestore = firestore,
        _auth = auth,
        _functions = functions;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  String get _uid => _auth.currentUser!.uid;

  DocumentReference<Map<String, dynamic>> get _referralRef => _firestore.collection('referral_profiles').doc(_uid);

  Stream<ReferralProfile> watchReferralProfile() {
    return _referralRef.snapshots().asyncMap((doc) async {
      if (!doc.exists) {
        await _ensureReferralCode();
        final created = await _referralRef.get();
        return ReferralProfile.fromFirestore(created);
      }
      return ReferralProfile.fromFirestore(doc);
    });
  }

  Future<String> getReferralCode() async {
    final snap = await _referralRef.get();
    if (!snap.exists || (snap.data()?['referralCode'] as String? ?? '').isEmpty) {
      return _ensureReferralCode();
    }
    return snap.data()!['referralCode'] as String;
  }

  Future<ReferralProgress> getProgress() async {
    final profile = await watchReferralProfile().first;
    final milestone = _nextMilestone(profile.successfulInstalls);
    return ReferralProgress(
      invites: profile.totalInvites,
      installs: profile.successfulInstalls,
      nextRewardAt: milestone,
    );
  }

  Future<void> registerInviteSent() {
    return _referralRef.set({
      'totalInvites': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> applyReferralInstall({required String referralCode, String? contentId}) async {
    final callable = _functions.httpsCallable('processReferralInstall');
    await callable.call({
      'referralCode': referralCode,
      'contentId': contentId,
    });
  }

  Future<String> _ensureReferralCode() async {
    final random = Random().nextInt(1 << 31).toRadixString(36).padLeft(6, '0').substring(0, 6);
    final code = 'AI${random.toUpperCase()}';
    await _referralRef.set({
      'referralCode': code,
      'totalInvites': 0,
      'successfulInstalls': 0,
      'rewards': const <String>[],
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return code;
  }

  int _nextMilestone(int installs) {
    if (installs < 1) return 1;
    if (installs < 3) return 3;
    if (installs < 5) return 5;
    if (installs < 10) return 10;
    return installs + 5;
  }
}
