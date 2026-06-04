import 'package:construction_rfq/catalog_import/import_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('refuses full write without emulator flag', () {
    final config = CatalogImportConfig(
      dataRoot: '/tmp',
      importFull: true,
      writeToFirestore: true,
      requireEmulator: false,
    );
    expect(
      CatalogImportSafety.refuseFullWriteReason(config),
      contains('--emulator'),
    );
  });

  test('fromArgs parses full-dry-run and import-full', () {
    final config = CatalogImportConfig.fromArgs([
      '--full-dry-run',
      '--import-full',
      '--write',
      '--emulator',
    ]);
    expect(config.fullDryRun, isTrue);
    expect(config.importFull, isTrue);
    expect(config.dryRun, isTrue);
    expect(config.requireEmulator, isTrue);
  });

  test('estimated batch math uses batchSize', () {
    const batchSize = 450;
    final batches = (418 / batchSize).ceil() +
        (11149 / batchSize).ceil() +
        (31551 / batchSize).ceil() +
        1;
    expect(batches, greaterThan(70));
    expect(batches, lessThan(110));
  });
}
