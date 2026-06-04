import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:construction_rfq/catalog_import/catalog_import_pipeline.dart';
import 'package:construction_rfq/catalog_import/import_config.dart';
import 'package:construction_rfq/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs full emulator import + verification when emulator env is set.
///
/// Run manually:
///   firebase emulators:start --only firestore &
///   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 \
///   flutter test test/catalog_emulator_integration_test.dart
void main() {
  final dataRoot = Platform.environment['CATALOG_DATA_ROOT'] ??
      '/Users/itayamar/catalog-working';
  final hasDataset = File('$dataRoot/normalized/products.jsonl').existsSync();
  final hasEmulator = CatalogImportSafety.isEmulatorHostConfigured;

  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Emulator rollback → full import → verify',
    () async {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      final firestore = FirebaseFirestore.instance;
      final host = Platform.environment['FIRESTORE_EMULATOR_HOST']!;
      final parts = host.split(':');
      firestore.useFirestoreEmulator(
        parts.first,
        int.tryParse(parts.length > 1 ? parts[1] : '8080') ?? 8080,
      );

      final base = CatalogImportConfig(
        dataRoot: dataRoot,
        outputDir: 'tools/catalog_import/out',
        requireEmulator: true,
        writeToFirestore: true,
        log: (_) {},
      );

      final rollback = await CatalogImportPipeline(
        base.copyWith(rollbackCatalog: true),
        firestore: firestore,
      ).run();
      expect(rollback.ok, isTrue);

      final import = await CatalogImportPipeline(
        base.copyWith(
          importFull: true,
          dryRun: false,
          rollbackCatalog: false,
        ),
        firestore: firestore,
      ).run();
      expect(import.ok, isTrue);
      expect(import.importResult?.dryRun, isFalse);

      final verify = await CatalogImportPipeline(
        base.copyWith(
          verifyEmulator: true,
          writeToFirestore: false,
          importFull: false,
        ),
        firestore: firestore,
      ).run();
      expect(verify.ok, isTrue);
      expect(verify.verification?.passed, isTrue);
    },
    timeout: const Timeout(Duration(minutes: 15)),
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
