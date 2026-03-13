import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/router.dart';
import 'features/settings/services/settings_service.dart';
import 'features/growth/viral/services/share_attribution_tracker.dart';

class AiLearnApp extends ConsumerWidget {
  const AiLearnApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final settings = ref.watch(settingsControllerProvider).valueOrNull;

    Future.microtask(() => ref.read(shareAttributionTrackerProvider).initialize());

    return MaterialApp.router(
      title: 'AI Learn',
      debugShowCheckedModeBanner: false,
      themeMode: (settings?.isDarkMode ?? false) ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      darkTheme: ThemeData.dark(useMaterial3: true),
      routerConfig: router,
    );
  }
}
