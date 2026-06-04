// =============================================================================
// Catalog import CLI — validate, dry-run, emulator import, rollback, verify
// =============================================================================
//
// Validate:
//   flutter run -t lib/dev/catalog_import_main.dart -d chrome -- --validate
//
// Demo dry-run:
//   flutter run -t lib/dev/catalog_import_main.dart -d chrome -- --dry-run
//
// Full dry-run (no Firestore writes):
//   flutter run -t lib/dev/catalog_import_main.dart -d chrome -- --full-dry-run
//
// Demo emulator import:
//   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 \
//   flutter run -t lib/dev/catalog_import_main.dart -d chrome -- --import-demo --write --emulator
//
// Full emulator import (refuses production):
//   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 \
//   flutter run -t lib/dev/catalog_import_main.dart -d chrome -- --import-full --write --emulator
//
// Resume full import:
//   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 \
//   flutter run -t lib/dev/catalog_import_main.dart -d chrome -- --import-full --write --emulator --resume
//
// Rollback catalog (emulator only):
//   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 \
//   flutter run -t lib/dev/catalog_import_main.dart -d chrome -- --rollback-catalog --emulator
//
// Verify emulator import:
//   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 \
//   flutter run -t lib/dev/catalog_import_main.dart -d chrome -- --verify-emulator --emulator
//
// See CATALOG_IMPORT_GUIDE.md
// =============================================================================

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:construction_rfq/catalog_import/catalog_import_pipeline.dart';
import 'package:construction_rfq/catalog_import/import_config.dart';
import 'package:construction_rfq/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = CatalogImportConfig.fromArgs(
    args,
    log: (msg) => stdout.writeln(msg),
  );

  final needsFirestore = config.writeToFirestore ||
      config.rollbackCatalog ||
      config.verifyEmulator;

  if (needsFirestore) {
    final refuseFull = CatalogImportSafety.refuseFullWriteReason(config);
    if (refuseFull != null) {
      stderr.writeln('REFUSED: $refuseFull');
      exit(3);
    }
    final refuseRollback = CatalogImportSafety.refuseRollbackReason(config);
    if (refuseRollback != null) {
      stderr.writeln('REFUSED: $refuseRollback');
      exit(3);
    }
    final refuseVerify = CatalogImportSafety.refuseVerifyReason(config);
    if (refuseVerify != null) {
      stderr.writeln('REFUSED: $refuseVerify');
      exit(3);
    }
  }

  if (!config.pathsExist &&
      !config.rollbackCatalog &&
      !config.verifyEmulator) {
    stderr.writeln('ERROR: Catalog dataset not found at ${config.dataRoot}');
    exit(1);
  }

  FirebaseFirestore? firestore;
  if (needsFirestore) {
    stdout.writeln('Initializing Firebase...');
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    firestore = FirebaseFirestore.instance;
    final host = Platform.environment['FIRESTORE_EMULATOR_HOST'];
    if (host != null && host.isNotEmpty) {
      final parts = host.split(':');
      firestore.useFirestoreEmulator(
        parts.first,
        int.tryParse(parts.length > 1 ? parts[1] : '8080') ?? 8080,
      );
      stdout.writeln('Using Firestore emulator at $host');
    } else if (config.writeToFirestore && config.importFull) {
      stderr.writeln('REFUSED: Cannot run full import without emulator host.');
      exit(3);
    }
  }

  final result = await CatalogImportPipeline(
    config,
    firestore: firestore,
  ).run();

  stdout.writeln('');
  stdout.writeln(result.ok ? 'Pipeline: PASS' : 'Pipeline: FAIL');
  exit(result.ok ? 0 : 2);
}
