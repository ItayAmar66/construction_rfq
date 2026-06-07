import 'package:construction_rfq/catalog_import/catalog_firestore_backend.dart';
import 'package:construction_rfq/catalog_import/catalog_production_light_verifier.dart';
import 'package:construction_rfq/catalog_import/import_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const project = CatalogImportProduction.requiredProjectId;

  group('light verify config', () {
    test('parses --verify-production-light as read-only', () {
      final config = CatalogImportConfig.fromArgs([
        '--verify-production-light',
        '--production',
        '--project=$project',
      ]);
      expect(config.verifyProductionLight, isTrue);
      expect(config.verifyProduction, isFalse);
      expect(config.writeToFirestore, isFalse);
      expect(config.importFull, isFalse);
      expect(CatalogImportSafety.refuseVerifyReason(config), isNull);
      expect(CatalogImportSafety.refuseVerifyWriteConflict(config), isNull);
      expect(CatalogImportSafety.refuseProductionWriteReason(config), isNull);
    });

    test('light verify with production config clears write', () {
      final config = CatalogImportConfig.fromArgs([
        '--verify-production-light',
        '--production',
        '--project=$project',
        '--config=tools/catalog_import/config.full_import.production.json',
      ]);
      expect(config.writeToFirestore, isFalse);
      expect(config.batchSize, 50);
      expect(config.batchDelayMs, 4000);
      expect(config.maxRetries, 15);
    });

    test('verify-production-light + write is refused', () {
      final config = CatalogImportConfig.fromArgs([
        '--verify-production-light',
        '--write',
        '--production',
        '--project=$project',
      ]);
      expect(
        CatalogImportSafety.refuseVerifyWriteConflict(config),
        contains('read-only'),
      );
    });
  });

  group('light verify behavior', () {
    test('does not call full count loops', () async {
      final backend = _RecordingBackend();
      final config = CatalogImportConfig(
        dataRoot: '/tmp',
        verifyProductionLight: true,
        productionMode: true,
        firebaseProjectId: project,
        outputDir: 'tools/catalog_import/out/test_light',
      );

      final result = await CatalogProductionLightVerifier(
        config: config,
        backend: backend,
      ).run();

      expect(backend.countCollectionCalls, 0);
      expect(backend.listCollectionPageCalls, 3);
      expect(backend.runStructuredQueryCalls, 1);
      expect(result.passed, isTrue);
      expect(result.warnings, isNotEmpty);
    });
  });
}

class _RecordingBackend implements CatalogFirestoreBackend {
  int countCollectionCalls = 0;
  int listCollectionPageCalls = 0;
  int runStructuredQueryCalls = 0;

  @override
  Future<void> batchSet(
    String collection,
    List<MapEntry<String, Map<String, dynamic>>> docs,
  ) async {}

  @override
  Future<int> countCollection(String collection) async {
    countCollectionCalls++;
    return 999;
  }

  @override
  Future<int> deleteAllInCollection(
    String collection, {
    void Function(String collection, int deleted)? onProgress,
  }) async =>
      0;

  @override
  Future<bool> deleteDocument(String collection, String docId) async => false;

  @override
  Future<Map<String, dynamic>?> getDocument(
    String collection,
    String docId,
  ) async =>
      null;

  @override
  Future<({List<MapEntry<String, Map<String, dynamic>>> docs, String? nextPageToken})>
      listCollectionPage(
    String collection, {
    int? pageSize,
    String? pageToken,
  }) async {
    listCollectionPageCalls++;
    return (
      docs: [MapEntry('sample', {'id': collection})],
      nextPageToken: null,
    );
  }

  @override
  Future<List<MapEntry<String, Map<String, dynamic>>>> runStructuredQuery(
    Map<String, dynamic> queryBody,
  ) async {
    runStructuredQueryCalls++;
    return [
      MapEntry(
        'v1',
        {
          'displayNameLower': 'test',
          'skuLower': 'sku',
          'categoryIds': ['c1'],
          'searchTokens': ['test'],
          'isActive': true,
        },
      ),
    ];
  }

  @override
  Future<void> setDocument(
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) async {}
}
