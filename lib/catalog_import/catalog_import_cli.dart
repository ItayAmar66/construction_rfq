import 'dart:io';

import 'catalog_import_pipeline.dart';
import 'emulator_rest_firestore_backend.dart';
import 'import_config.dart';

/// Native VM catalog import CLI (no Flutter Web / Chrome).
Future<int> runCatalogImportCli(List<String> args) async {
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
      return 3;
    }
    final refuseRollback = CatalogImportSafety.refuseRollbackReason(config);
    if (refuseRollback != null) {
      stderr.writeln('REFUSED: $refuseRollback');
      return 3;
    }
    final refuseVerify = CatalogImportSafety.refuseVerifyReason(config);
    if (refuseVerify != null) {
      stderr.writeln('REFUSED: $refuseVerify');
      return 3;
    }
  }

  if (!config.pathsExist &&
      !config.rollbackCatalog &&
      !config.verifyEmulator) {
    stderr.writeln('ERROR: Catalog dataset not found at ${config.dataRoot}');
    return 1;
  }

  EmulatorRestFirestoreBackend? backend;
  if (needsFirestore) {
    backend = EmulatorRestFirestoreBackend(
      projectId: EmulatorRestFirestoreBackend.defaultProjectId,
      emulatorMode: config.requireEmulator,
    );
    stdout.writeln(
      'Using Firestore emulator REST API (FIRESTORE_EMULATOR_HOST=${Platform.environment['FIRESTORE_EMULATOR_HOST']})',
    );
  }

  try {
    final result = await CatalogImportPipeline(
      config,
      backend: backend,
    ).run();

    stdout.writeln('');
    stdout.writeln(result.ok ? 'Pipeline: PASS' : 'Pipeline: FAIL');
    return result.ok ? 0 : 2;
  } finally {
    backend?.close();
  }
}

