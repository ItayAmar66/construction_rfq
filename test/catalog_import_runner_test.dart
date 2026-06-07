import 'dart:io';

import 'package:construction_rfq/catalog_import/catalog_import_cli.dart';
import 'package:flutter_test/flutter_test.dart';

/// VM runner for catalog import CLI (no macOS app sandbox).
///
/// Invoked by [tools/catalog_import/run_import_cli.sh] with
/// `CATALOG_IMPORT_CLI_ARGS` set to the CLI argument string.
void main() {
  test('parseCatalogImportCliArgsString splits quoted args', () {
    expect(
      parseCatalogImportCliArgsString(
        '--project=construction-rfq-itay-20-2eee0 --full-dry-run',
      ),
      [
        '--project=construction-rfq-itay-20-2eee0',
        '--full-dry-run',
      ],
    );
  });

  test(
    'catalog import CLI runner',
    () async {
      final raw = Platform.environment['CATALOG_IMPORT_CLI_ARGS'] ?? '';
      final args = parseCatalogImportCliArgsString(raw);
      if (args.isEmpty) {
        fail(
          'CATALOG_IMPORT_CLI_ARGS is empty. '
          'Use tools/catalog_import/run_import_cli.sh',
        );
      }

      final code = await runCatalogImportCli(args);
      expect(
        code,
        0,
        reason: 'catalog import CLI exited with code $code',
      );
    },
    timeout: const Timeout(Duration(minutes: 30)),
    skip: Platform.environment['CATALOG_IMPORT_CLI_ARGS'] == null,
  );
}
