import 'dart:io';

import 'package:construction_rfq/catalog_import/catalog_import_pipeline.dart';
import 'package:construction_rfq/catalog_import/emulator_rest_firestore_backend.dart';
import 'package:construction_rfq/catalog_import/import_config.dart';
import 'package:flutter_test/flutter_test.dart';

/// Full emulator gate via native REST backend (no Flutter Web).
///
/// Run with emulator:
///   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 \
///   flutter test test/catalog_emulator_integration_test.dart
void main() {
  final dataRoot = Platform.environment['CATALOG_DATA_ROOT'] ??
      '/Users/itayamar/catalog-working';
  final hasDataset = File('$dataRoot/normalized/products.jsonl').existsSync();
  final hasEmulator = CatalogImportSafety.isEmulatorHostConfigured;

  test(
    'Emulator rollback → full import → verify (REST)',
    () async {
      final backend = EmulatorRestFirestoreBackend(
        projectId: EmulatorRestFirestoreBackend.defaultProjectId,
        emulatorMode: true,
      );

      final base = CatalogImportConfig(
        dataRoot: dataRoot,
        outputDir: 'tools/catalog_import/out',
        requireEmulator: true,
        writeToFirestore: true,
        log: (_) {},
      );

      try {
        final rollback = await CatalogImportPipeline(
          base.copyWith(rollbackCatalog: true),
          backend: backend,
        ).run();
        expect(rollback.ok, isTrue);

        final import = await CatalogImportPipeline(
          base.copyWith(
            importFull: true,
            dryRun: false,
            rollbackCatalog: false,
          ),
          backend: backend,
        ).run();
        expect(import.ok, isTrue);
        expect(import.importResult?.dryRun, isFalse);

        final verify = await CatalogImportPipeline(
          base.copyWith(
            verifyEmulator: true,
            writeToFirestore: false,
            importFull: false,
          ),
          backend: backend,
        ).run();
        expect(verify.ok, isTrue);
        expect(verify.verification?.passed, isTrue);
        expect(verify.verification?.categoryCount, 418);
        expect(verify.verification?.productCount, 11149);
        expect(verify.verification?.variantCount, 31551);
      } finally {
        backend.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 20)),
    skip: !hasDataset || !hasEmulator,
  );
}

extension on CatalogImportConfig {
  CatalogImportConfig copyWith({
    bool? rollbackCatalog,
    bool? importFull,
    bool? dryRun,
    bool? verifyEmulator,
    bool? writeToFirestore,
  }) {
    return CatalogImportConfig(
      dataRoot: dataRoot,
      outputDir: outputDir,
      rollbackCatalog: rollbackCatalog ?? this.rollbackCatalog,
      importFull: importFull ?? this.importFull,
      dryRun: dryRun ?? this.dryRun,
      verifyEmulator: verifyEmulator ?? this.verifyEmulator,
      writeToFirestore: writeToFirestore ?? this.writeToFirestore,
      requireEmulator: requireEmulator,
      log: log,
    );
  }
}
