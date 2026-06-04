// Native catalog import CLI.
//
// Preferred (macOS VM, no Chrome):
//   flutter run -d macos -t tool/catalog_import_main.dart -- --import-full --write --emulator
//
// Plain `dart run` is not supported on this Flutter package (SDK FFI). Use flutter run -d macos
// or: flutter test test/catalog_emulator_gate_cli_test.dart (inside emulators:exec).

import 'dart:io';

import 'package:construction_rfq/catalog_import/catalog_import_cli.dart';

Future<void> main(List<String> args) async {
  final code = await runCatalogImportCli(args);
  exit(code);
}
