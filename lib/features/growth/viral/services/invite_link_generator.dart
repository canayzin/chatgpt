import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final inviteLinkGeneratorProvider = Provider<InviteLinkGenerator>((ref) {
  return InviteLinkGenerator(FirebaseDynamicLinks.instance);
});

class InviteLinkGenerator {
  InviteLinkGenerator(this._dynamicLinks);

  final FirebaseDynamicLinks _dynamicLinks;

  Future<Uri> buildInviteLink({required String referralCode, String? contentId}) async {
    final deepLink = Uri.parse(
      'https://ailearn.app/invite?referralId=$referralCode${contentId == null ? '' : '&contentId=$contentId'}',
    );

    final params = DynamicLinkParameters(
      uriPrefix: 'https://ailearnapp.page.link',
      link: deepLink,
      androidParameters: const AndroidParameters(packageName: 'com.ailearn.app'),
      iosParameters: const IOSParameters(bundleId: 'com.ailearn.app'),
    );

    final short = await _dynamicLinks.buildShortLink(params);
    return short.shortUrl;
  }
}
