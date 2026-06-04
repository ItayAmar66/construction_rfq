// =============================================================================
// Catalog import CLI — validate, dry-run, or demo Firestore import
// =============================================================================
//
// Validate + dry-run (tests also cover this):
//   flutter test test/catalog_import_test.dart
//
// Dry-run export:
//   flutter run -t lib/dev/catalog_import_main.dart -d chrome -- --dry-run
//
// Validate only:
//   flutter run -t lib/dev/catalog_import_main.dart -d chrome -- --validate
//
// Demo Firestore import (use emulator):
//   FIRESTORE_EMULATOR_HOST=localhost:8080 \
//   flutter run -t lib/dev/catalog_import_main.dart -d chrome -- --import-demo --write
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

  if (!config.pathsExist) {
    stderr.writeln('ERROR: Catalog dataset not found at ${config.dataRoot}');
    exit(1);
  }

  FirebaseFirestore? firestore;
  if (config.writeToFirestore) {
    stdout.writeln('Initializing Firebase for demo import...');
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
    } else {
      stderr.writeln(
        'WARNING: FIRESTORE_EMULATOR_HOST not set. '
        'Client writes to catalog collections are blocked by security rules.',
      );
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
