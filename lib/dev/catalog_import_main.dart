// =============================================================================
// DEPRECATED: Use native CLI instead of Flutter Web / Chrome
// =============================================================================
//
//   dart run tool/catalog_import_main.dart --import-full --write --emulator
//
// `flutter run -d chrome` fails with Platform._environment on web.
// =============================================================================

import 'dart:io';

import 'package:construction_rfq/catalog_import/catalog_import_cli.dart';

Future<void> main(List<String> args) async {
  stderr.writeln(
    'NOTE: lib/dev/catalog_import_main.dart delegates to native CLI. '
    'Prefer: dart run tool/catalog_import_main.dart',
  );
  final code = await runCatalogImportCli(args);
  exit(code);
}
