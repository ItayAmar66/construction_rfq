import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/app_mode.dart';
import 'providers/providers.dart';
import 'router/app_router.dart';
import 'services/mock_store.dart';
import 'services/seed_service.dart';
import 'utils/app_theme.dart';
import 'utils/constants.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppMode.initialize();

  if (AppMode.isDemoMode) {
    MockStore.instance.init();
  } else if (AppMode.useFirebase) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
    if (kDebugMode) {
      debugPrint('[Main] Firestore persistence enabled');
    }
  }

  final container = ProviderContainer();

  if (AppMode.useFirebase) {
    try {
      await container.read(seedServiceProvider).seedProductsIfNeeded();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Main] Product seed failed (non-fatal): $e');
      }
    }
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const ConstructionRfqApp(),
    ),
  );
}

class ConstructionRfqApp extends ConsumerWidget {
  const ConstructionRfqApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      locale: const Locale('he', 'IL'),
      supportedLocales: const [Locale('he', 'IL')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ??
              const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
        );
      },
      routerConfig: router,
    );
  }
}
