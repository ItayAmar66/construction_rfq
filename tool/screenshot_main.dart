// QA / screenshot entrypoint — tooling only, not shipped.
//
// Forces demo mode and auto-logs-in a demo user (role from the `?role=` query
// param) before runApp, so the desktop shell can be captured at any deep-link
// route without driving the login screen. Business logic is untouched — this
// only wires the existing demo login + the real app.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/main.dart';
import 'package:construction_rfq/models/user_type.dart';
import 'package:construction_rfq/providers/providers.dart';
import 'package:construction_rfq/services/mock_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  AppMode.enableDemoMode();
  MockStore.instance.init();

  final container = ProviderContainer();
  try {
    await container.read(seedServiceProvider).seedProductsIfNeeded();
  } catch (_) {
    // Non-fatal: dashboards still render structure without seeded products.
  }

  final role = Uri.base.queryParameters['role'] ?? 'customer';
  final type =
      role == 'supplier' ? UserType.privateSupplier : UserType.privateCustomer;
  await container.read(authServiceProvider).loginAsDemo(type);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const ConstructionRfqApp(),
    ),
  );
}
