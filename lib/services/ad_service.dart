import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

final adServiceProvider = Provider<AdService>((ref) {
  return AdService();
});

class AdService {
  String get nativeAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/2247696110';
    }
    return 'ca-app-pub-3940256099942544/3986624511';
  }

  Widget buildFeedAdPlaceholder(int slot) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: SizedBox(
        height: 120,
        child: Center(
          child: Text('Sponsored • ad slot $slot'),
        ),
      ),
    );
  }

  NativeAd createNativeAd() {
    return NativeAd(
      adUnitId: nativeAdUnitId,
      request: const AdRequest(),
      listener: NativeAdListener(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
      ),
    );
  }
}
