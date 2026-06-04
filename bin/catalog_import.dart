import 'dart:io';

import 'package:construction_rfq/catalog_import/catalog_import_cli.dart';

Future<void> main(List<String> args) async {
  exit(await runCatalogImportCli(args));
}
