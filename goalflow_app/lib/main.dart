import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application/providers.dart';
import 'application/theme_provider.dart';
import 'core/notifications/push_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Firebase is optional at runtime: without a config file the app still runs,
  // it simply cannot receive push.
  try {
    await Firebase.initializeApp();
    // Must be registered before runApp so a tap on a tray notification can wake
    // the app straight into the background isolate.
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
  } catch (_) {}

  runApp(const ProviderScope(child: GoalFlowApp()));
}

class GoalFlowApp extends ConsumerStatefulWidget {
  const GoalFlowApp({super.key});

  @override
  ConsumerState<GoalFlowApp> createState() => _GoalFlowAppState();
}

class _GoalFlowAppState extends ConsumerState<GoalFlowApp> {
  @override
  void initState() {
    super.initState();
    // Register for push only once the user is actually signed in.
    ref.listenManual(authProvider, (previous, next) {
      if (previous?.stage != AuthStage.ready && next.stage == AuthStage.ready) {
        PushService(
          (token, platform) =>
              ref.read(appRepositoryProvider).registerDevice(token, platform),
          onOpenRoute: (route) {
            // Tapping a notification should land on the relevant screen, and
            // refresh it -- the payload that triggered it is already stale.
            invalidateProgressData(ref);
            ref.read(routerProvider).go(route);
          },
        ).init();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'GoalFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
