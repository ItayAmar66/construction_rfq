import 'dart:io';

import 'package:construction_rfq/catalog_import/catalog_import_cli.dart';
import 'package:construction_rfq/catalog_import/import_config.dart';
import 'package:flutter_test/flutter_test.dart';

/// Full emulator gate via native CLI (VM), for use inside firebase emulators:exec.
void main() {
  final hasEmulator = CatalogImportSafety.isEmulatorHostConfigured;
  final hasDataset = File(
    '${Platform.environment['CATALOG_DATA_ROOT'] ?? '/Users/itayamar/catalog-working'}/normalized/products.jsonl',
  ).existsSync();

  test(
    'Gate: rollback → import-full → verify-emulator',
    () async {
      final rollbackCode = await runCatalogImportCli([
        '--rollback-catalog',
        '--emulator',
      ]);
      expect(rollbackCode, 0);

      final importCode = await runCatalogImportCli([
        '--import-full',
        '--write',
        '--emulator',
      ]);
      expect(importCode, 0);

      final verifyCode = await runCatalogImportCli([
        '--verify-emulator',
        '--emulator',
      ]);
      expect(verifyCode, 0);

      final summary = File(
        'tools/catalog_import/out/emulator_verification/summary.json',
      );
      expect(summary.existsSync(), isTrue);
    },
    timeout: const Timeout(Duration(minutes: 25)),
    skip: !hasDataset || !hasEmulator,
  );
}
