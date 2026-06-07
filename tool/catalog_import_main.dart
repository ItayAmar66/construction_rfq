// Native catalog import CLI.
//
// Preferred (no macOS sandbox — reliable file access):
//   bash tools/catalog_import/run_import_cli.sh --import-full --full-dry-run --production \
//     --project=construction-rfq-itay-20-2eee0
//
// Alternative (requires Debug rebuild; DebugProfile disables sandbox):
//   flutter run -d macos -t tool/catalog_import_main.dart -- --import-full --write --emulator
//
// Plain `dart run` is not supported on this Flutter package (SDK FFI). Use run_import_cli.sh
// or: flutter test test/catalog_emulator_gate_cli_test.dart (inside emulators:exec).

import 'dart:io';

import 'package:construction_rfq/catalog_import/catalog_import_cli.dart';

Future<void> main(List<String> args) async {
  final code = await runCatalogImportCli(args);
  exit(code);
}
