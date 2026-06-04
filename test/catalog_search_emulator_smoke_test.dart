import 'dart:io';

import 'package:construction_rfq/catalog_import/catalog_search_emulator_smoke.dart';
import 'package:construction_rfq/catalog_import/import_config.dart';
import 'package:construction_rfq/repositories/catalog_search/emulator_rest_catalog_search_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// VM-safe catalog search smoke test (REST `:runQuery`, no FirebaseCore).
///
/// Prefer running inside gate session:
///   ./tools/catalog_import/run_emulator_gate.sh
void main() {
  final hasEmulator = CatalogImportSafety.isEmulatorHostConfigured;
  final verificationSummary = File(
    'tools/catalog_import/out/emulator_verification/summary.json',
  );

  test(
    'REST search smoke on live Firestore emulator',
    () async {
      final repo = EmulatorRestCatalogSearchRepository();
      try {
        final result = await CatalogSearchEmulatorSmoke.run(
          repo,
          verificationSummary: verificationSummary,
        );
        if (!result.passed) {
          fail(result.errors.join('\n'));
        }
        expect(result.categoryCount, 418);
        expect(result.browseHits, greaterThan(0));
      } finally {
        repo.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
    skip: !hasEmulator,
  );
}
