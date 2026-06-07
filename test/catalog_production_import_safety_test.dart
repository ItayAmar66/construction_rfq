import 'dart:io';

import 'package:construction_rfq/catalog_import/catalog_import_cli.dart';
import 'package:construction_rfq/catalog_import/import_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const project = CatalogImportProduction.requiredProjectId;

  CatalogImportConfig productionWriteConfig({
    bool production = true,
    String? firebaseProjectId = project,
    String? confirmProductionImport = project,
    bool write = true,
    bool importFull = true,
  }) {
    return CatalogImportConfig(
      dataRoot: '/tmp',
      importFull: importFull,
      writeToFirestore: write,
      productionMode: production,
      firebaseProjectId: firebaseProjectId,
      confirmProductionImport: confirmProductionImport,
      firestoreTarget: 'production',
    );
  }

  group('production write guards', () {
    test('blocked without --production', () {
      final config = productionWriteConfig(production: false);
      expect(
        CatalogImportSafety.refuseProductionWriteReason(config),
        contains('--production'),
      );
    });

    test('blocked without --project', () {
      final config = productionWriteConfig(firebaseProjectId: null);
      expect(
        CatalogImportSafety.refuseProductionWriteReason(config),
        contains('--project'),
      );
    });

    test('blocked without confirmation flag', () {
      final config = productionWriteConfig(confirmProductionImport: null);
      expect(
        CatalogImportSafety.refuseProductionWriteReason(config),
        contains('--confirm-production-import'),
      );
    });

    test('wrong project is rejected', () {
      final config = productionWriteConfig(firebaseProjectId: 'wrong-project');
      expect(
        CatalogImportSafety.refuseProductionWriteReason(config),
        contains('mismatch'),
      );
    });

    test('all flags present allows production write', () {
      final config = productionWriteConfig();
      expect(CatalogImportSafety.refuseProductionWriteReason(config), isNull);
      expect(config.allowsFullFirestoreWrite, isTrue);
    });
  });

  group('production verify guards', () {
    test('verify-only does not require write flag', () {
      final config = CatalogImportConfig(
        dataRoot: '/tmp',
        verifyProduction: true,
        productionMode: true,
        firebaseProjectId: project,
        writeToFirestore: false,
      );
      expect(CatalogImportSafety.refuseVerifyReason(config), isNull);
      expect(CatalogImportSafety.refuseProductionWriteReason(config), isNull);
    });

    test('verify-only blocked without --production', () {
      final config = CatalogImportConfig(
        dataRoot: '/tmp',
        verifyProduction: true,
        productionMode: false,
        firebaseProjectId: project,
      );
      expect(
        CatalogImportSafety.refuseVerifyReason(config),
        contains('--production'),
      );
    });
  });

  group('production config parsing', () {
    test('config.full_import.production.json parses correctly', () {
      final path =
          '${Directory.current.path}/tools/catalog_import/config.full_import.production.json';
      final config = CatalogImportConfig.fromArgs([
        '--config=$path',
        '--production',
        '--project=$project',
      ]);

      expect(config.firestoreTarget, 'production');
      expect(config.productionMode, isTrue);
      expect(config.firebaseProjectId, project);
      expect(config.requireEmulator, isFalse);
      expect(config.importFull, isTrue);
      expect(config.batchSize, 150);
      expect(config.collections.categories, 'catalogCategories');
      expect(config.collections.variants, 'catalogVariants');
      expect(config.dataRoot, '/Users/itayamar/catalog-working');
    });
  });

  group('emulator path unchanged', () {
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

    test('fromArgs parses emulator full-dry-run', () {
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
      expect(config.productionMode, isFalse);
    });

    test('CLI refuses production write without confirmation', () async {
      final code = await runCatalogImportCli([
        '--import-full',
        '--write',
        '--production',
        '--project=$project',
      ]);
      expect(code, 3);
    });
  });
}
