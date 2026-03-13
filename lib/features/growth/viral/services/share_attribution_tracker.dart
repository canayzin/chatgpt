import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../analytics/services/analytics_event_service.dart';
import 'referral_service.dart';

final shareAttributionTrackerProvider = Provider<ShareAttributionTracker>((ref) {
  return ShareAttributionTracker(
    dynamicLinks: FirebaseDynamicLinks.instance,
    ref: ref,
  );
});

class ShareAttributionTracker {
  ShareAttributionTracker({required FirebaseDynamicLinks dynamicLinks, required Ref ref})
      : _dynamicLinks = dynamicLinks,
        _ref = ref;

  final FirebaseDynamicLinks _dynamicLinks;
  final Ref _ref;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final initial = await _dynamicLinks.getInitialLink();
    if (initial != null) {
      await _handleDeepLink(initial.link);
    }

    _dynamicLinks.onLink.listen((event) async {
      await _handleDeepLink(event.link);
    });
  }

  Future<void> _handleDeepLink(Uri link) async {
    final referralId = link.queryParameters['referralId'];
    final contentId = link.queryParameters['contentId'];

    if (referralId == null || referralId.isEmpty) return;

    await _ref.read(analyticsEventServiceProvider).logEvent(
          eventType: 'share_action',
          contentId: contentId,
          properties: {
            'referralId': referralId,
            'attribution': 'dynamic_link_open',
          },
          dedupeKey: 'dynamic_open:$referralId:${contentId ?? 'none'}',
        );

    await _ref.read(referralServiceProvider).applyReferralInstall(
          referralCode: referralId,
          contentId: contentId,
        );
  }
}
