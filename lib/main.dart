import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await MobileAds.instance.initialize();
  await FirebaseAuth.instance.signInAnonymously();

  final crashlyticsEnabled = const bool.fromEnvironment('enableCrashlytics', defaultValue: true) && !kDebugMode;
  final perfEnabled = const bool.fromEnvironment('enablePerformanceMonitoring', defaultValue: true) && !kDebugMode;

  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(crashlyticsEnabled);
  await FirebasePerformance.instance.setPerformanceCollectionEnabled(perfEnabled);

  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  runZonedGuarded(
    () => runApp(const ProviderScope(child: AiLearnApp())),
    (error, stack) => FirebaseCrashlytics.instance.recordError(error, stack, fatal: true),
  );
}
