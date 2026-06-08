import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Stable production import config used by catalog_production_* gate tests.
class CatalogProductionConfigFixtures {
  CatalogProductionConfigFixtures._();

  static String get goldenConfigPath =>
      '${Directory.current.path}/test/fixtures/config.full_import.production.golden.json';

  static String get liveProductionConfigPath =>
      '${Directory.current.path}/tools/catalog_import/config.full_import.production.json';

  static Map<String, dynamic> readGoldenJson() {
    return jsonDecode(File(goldenConfigPath).readAsStringSync())
        as Map<String, dynamic>;
  }

  static Map<String, dynamic> readLiveProductionJson() {
    return jsonDecode(File(liveProductionConfigPath).readAsStringSync())
        as Map<String, dynamic>;
  }

  static void expectLiveMatchesGoldenSafetyKeys() {
    final live = readLiveProductionJson();
    final golden = readGoldenJson();

    expect(live['resume'], golden['resume']);
    expect(live['write'], golden['write']);
    expect(live['firestoreTarget'], golden['firestoreTarget']);
    expect(live['firebaseProjectId'], golden['firebaseProjectId']);
    expect(live['batchSize'], golden['batchSize']);
    expect(live['productionThrottling'], golden['productionThrottling']);
    expect(live['collections'], golden['collections']);
  }
}
