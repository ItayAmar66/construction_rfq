import 'dart:io';

import 'catalog_firestore_backend.dart';
import 'catalog_import_pipeline.dart';
import 'emulator_rest_firestore_backend.dart';
import 'firestore_rest_catalog_backend_base.dart';
import 'firestore_batch_retry.dart';
import 'import_config.dart';
import 'production_firestore_rest_backend.dart';

/// Parses a shell-style argument string (supports quoted tokens).
List<String> parseCatalogImportCliArgsString(String raw) {
  if (raw.trim().isEmpty) return const [];

  final args = <String>[];
  final buffer = StringBuffer();
  var inSingle = false;
  var inDouble = false;
  var escape = false;

  for (var i = 0; i < raw.length; i++) {
    final ch = raw[i];
    if (escape) {
      buffer.write(ch);
      escape = false;
      continue;
    }
    if (ch == r'\' && inDouble) {
      escape = true;
      continue;
    }
    if (ch == "'" && !inDouble) {
      inSingle = !inSingle;
      continue;
    }
    if (ch == '"' && !inSingle) {
      inDouble = !inDouble;
      continue;
    }
    if (ch == ' ' && !inSingle && !inDouble) {
      if (buffer.isNotEmpty) {
        args.add(buffer.toString());
        buffer.clear();
      }
      continue;
    }
    buffer.write(ch);
  }

  if (buffer.isNotEmpty) {
    args.add(buffer.toString());
  }
  return args;
}

/// Native VM catalog import CLI (no Flutter Web / Chrome).
Future<int> runCatalogImportCli(List<String> args) async {
  final config = CatalogImportConfig.fromArgs(
    args,
    log: (msg) => stdout.writeln(msg),
  );

  final needsFirestoreWrite = config.writeToFirestore || config.rollbackCatalog;
  final needsFirestoreRead = config.isVerifyMode;
  final needsFirestore = needsFirestoreWrite || needsFirestoreRead;

  if (needsFirestoreWrite) {
    final refuseFull = CatalogImportSafety.refuseFullWriteReason(config);
    if (refuseFull != null) {
      stderr.writeln('REFUSED: $refuseFull');
      return 3;
    }
  }

  if (config.isProductionTarget && !config.writeToFirestore) {
    final refuseDryRun = CatalogImportSafety.refuseProductionDryRunReason(config);
    if (refuseDryRun != null &&
        (config.fullDryRun || config.validateOnly || config.importFull)) {
      stderr.writeln('REFUSED: $refuseDryRun');
      return 3;
    }
  }

  if (needsFirestore) {
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
      !config.isVerifyMode) {
    stderr.writeln('ERROR: Catalog dataset not found at ${config.dataRoot}');
    return 1;
  }

  CatalogFirestoreBackend? backend;
  if (needsFirestore) {
    if (config.isProductionTarget) {
      final projectId = config.firebaseProjectId ??
          CatalogImportProduction.requiredProjectId;
      backend = await ProductionFirestoreRestBackend.open(
        projectId: projectId,
        retryPolicy: config.writeRetryPolicy,
      );
      stdout.writeln(
        'Using production Firestore REST API (project=$projectId, ADC auth, '
        'batchSize=${config.batchSize}, batchDelayMs=${config.batchDelayMs}, '
        'maxRetries=${config.maxRetryAttempts})',
      );
    } else {
      backend = EmulatorRestFirestoreBackend(
        projectId: EmulatorRestFirestoreBackend.defaultProjectId,
        emulatorMode: config.requireEmulator,
      );
      stdout.writeln(
        'Using Firestore emulator REST API (FIRESTORE_EMULATOR_HOST=${Platform.environment['FIRESTORE_EMULATOR_HOST']})',
      );
    }
  } else if (config.isProductionTarget &&
      (config.fullDryRun || config.validateOnly)) {
    stdout.writeln(
      'Production dry-run/validate (local only, no Firestore connection). '
      'Target project: ${config.firebaseProjectId ?? "(unset — pass --project=${CatalogImportProduction.requiredProjectId})"}',
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
    if (backend is FirestoreRestCatalogBackendBase) {
      backend.close();
    }
  }
}
