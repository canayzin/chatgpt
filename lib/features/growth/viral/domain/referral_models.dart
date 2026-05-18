import 'package:cloud_firestore/cloud_firestore.dart';

class ReferralProfile {
  const ReferralProfile({
    required this.userId,
    required this.referralCode,
    required this.totalInvites,
    required this.successfulInstalls,
    required this.rewards,
    this.updatedAt,
  });

  final String userId;
  final String referralCode;
  final int totalInvites;
  final int successfulInstalls;
  final List<String> rewards;
  final DateTime? updatedAt;

  factory ReferralProfile.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return ReferralProfile(
      userId: doc.id,
      referralCode: data['referralCode'] as String? ?? '',
      totalInvites: (data['totalInvites'] as num?)?.toInt() ?? 0,
      successfulInstalls: (data['successfulInstalls'] as num?)?.toInt() ?? 0,
      rewards: (data['rewards'] as List?)?.whereType<String>().toList() ?? const [],
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}

class ReferralProgress {
  const ReferralProgress({
    required this.invites,
    required this.installs,
    required this.nextRewardAt,
  });

  final int invites;
  final int installs;
  final int nextRewardAt;

  double get progress => nextRewardAt == 0 ? 1 : (installs / nextRewardAt).clamp(0, 1);
}
