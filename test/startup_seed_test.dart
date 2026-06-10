import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/services/seed_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('seed service skips legacy products in production firebase mode', () async {
    AppMode.isDemoMode = false;
    AppMode.isFirebaseInitialized = true;

    final service = SeedService();
    await expectLater(service.seedProductsIfNeeded(), completes);
  });

  test('seed service skips when firebase is not used', () async {
    AppMode.isDemoMode = true;
    AppMode.isFirebaseInitialized = false;

    final service = SeedService();
    await expectLater(service.seedProductsIfNeeded(), completes);
  });
}
