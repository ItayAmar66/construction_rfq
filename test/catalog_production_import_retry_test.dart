import 'dart:convert';
import 'dart:io';

import 'package:construction_rfq/catalog_import/catalog_firestore_backend.dart';
import 'package:construction_rfq/catalog_import/catalog_importer.dart';
import 'package:construction_rfq/catalog_import/firestore_batch_retry.dart';
import 'package:construction_rfq/catalog_import/full_catalog_builder.dart';
import 'package:construction_rfq/catalog_import/import_checkpoint.dart';
import 'package:construction_rfq/catalog_import/import_config.dart';
import 'package:construction_rfq/models/catalog/catalog_category.dart';
import 'package:construction_rfq/models/catalog/catalog_product.dart';
import 'package:construction_rfq/models/catalog/catalog_variant.dart';
import 'package:construction_rfq/utils/catalog_constants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('FirestoreBatchRetryPolicy', () {
    test('429 triggers retry and eventually succeeds', () async {
      var attempts = 0;
      final sleeps = <Duration>[];
      final client = MockClient((request) async {
        attempts++;
        if (attempts < 3) {
          return http.Response('Quota exceeded', 429, headers: {'retry-after': '1'});
        }
        return http.Response('{}', 200);
      });

      final policy = FirestoreBatchRetryPolicy.production(
        maxAttempts: 5,
        baseDelayMs: 10,
        maxDelayMs: 100,
        sleep: (d) async => sleeps.add(d),
      );

      final response = await policy.postWithRetry(
        client: client,
        uri: Uri.parse('https://example.com/batchWrite'),
        headers: const {'Content-Type': 'application/json'},
        body: '{}',
        operation: 'batchWrite test',
      );

      expect(response.statusCode, 200);
      expect(attempts, 3);
      expect(sleeps.length, 2);
    });

    test('max retries exceeded reports cleanly', () async {
      final client = MockClient((_) async {
        return http.Response('Quota exceeded', 429);
      });

      final policy = FirestoreBatchRetryPolicy.production(
        maxAttempts: 3,
        baseDelayMs: 1,
        maxDelayMs: 5,
        sleep: (_) async {},
      );

      expect(
        () => policy.postWithRetry(
          client: client,
          uri: Uri.parse('https://example.com/batchWrite'),
          headers: const {},
          body: '{}',
          operation: 'batchWrite test',
        ),
        throwsA(isA<HttpException>().having(
          (e) => e.message,
          'message',
          contains('429'),
        )),
      );
    });

    test('respects Retry-After header', () {
      final policy = FirestoreBatchRetryPolicy.production(baseDelayMs: 1000);
      final response = http.Response('', 429, headers: {'retry-after': '7'});
      expect(
        policy.delayBeforeRetry(attempt: 1, response: response).inSeconds,
        7,
      );
    });
  });

  group('production config parsing', () {
    test('config.full_import.production.json includes throttle and resume', () {
      final path =
          '${Directory.current.path}/tools/catalog_import/config.full_import.production.json';
      final config = CatalogImportConfig.fromArgs([
        '--config=$path',
        '--production',
        '--project=${CatalogImportProduction.requiredProjectId}',
      ]);

      expect(config.batchSize, 150);
      expect(config.resume, isTrue);
      expect(config.batchDelayMs, 500);
      expect(config.maxRetryAttempts, 10);
      expect(config.retryBaseDelayMs, 1000);
      expect(config.retryMaxDelayMs, 120000);
    });

    test('emulator target has zero batch delay and no retry policy', () {
      final config = CatalogImportConfig(
        dataRoot: '/tmp',
        requireEmulator: true,
      );
      expect(config.batchDelayMs, 0);
      expect(config.writeRetryPolicy.maxAttempts, 1);
    });
  });

  group('resume upsert', () {
    test('resume continues without duplicating doc ids in skipped phase', () async {
      final backend = _CountingBackend();
      final outDir = Directory.systemTemp.createTempSync('catalog_import_test');
      addTearDown(() => outDir.deleteSync(recursive: true));

      final checkpointPath = '${outDir.path}/import_checkpoint.json';
      await ImportCheckpoint.save(
        checkpointPath,
        ImportCheckpoint(
          importVersion: 'catalog-full-v1',
          phase: 'variants',
          skipped: 2,
          total: 4,
          updatedAt: DateTime.now().toUtc(),
        ),
      );

      final config = CatalogImportConfig(
        dataRoot: '/tmp',
        importFull: true,
        writeToFirestore: true,
        dryRun: false,
        importVersion: 'catalog-full-v1',
        resume: true,
        batchSize: 2,
        outputDir: outDir.path,
        log: (_) {},
      );

      final importer = CatalogImporter(config: config, backend: backend);
      await importer.runFullImport(
        _tinyPayload(),
      );

      expect(backend.writeCounts[CatalogConstants.categoriesCollection], isNull);
      expect(backend.writeCounts[CatalogConstants.productsCollection], isNull);
      expect(
        backend.writeCounts[CatalogConstants.variantsCollection],
        2,
      );
      expect(backend.uniqueIds[CatalogConstants.variantsCollection]?.length, 2);
    });
  });
}

FullCatalogPayload _tinyPayload() {
  return FullCatalogPayload(
    categories: [
      CatalogCategory(id: 'c1', name: 'Cat', parentId: null, sortOrder: 0),
    ],
    products: [
      CatalogProduct(
        id: 'p1',
        name: 'Prod',
        primaryCategoryId: 'c1',
        categoryIds: ['c1'],
        isActive: true,
      ),
    ],
    variants: [
      CatalogVariant(
        id: 'v1',
        productId: 'p1',
        name: 'V1',
        skuLower: 'sku1',
        categoryIds: ['c1'],
        sortOrder: 0,
      ),
      CatalogVariant(
        id: 'v2',
        productId: 'p1',
        name: 'V2',
        skuLower: 'sku2',
        categoryIds: ['c1'],
        sortOrder: 1,
      ),
      CatalogVariant(
        id: 'v3',
        productId: 'p1',
        name: 'V3',
        skuLower: 'sku3',
        categoryIds: ['c1'],
        sortOrder: 2,
      ),
      CatalogVariant(
        id: 'v4',
        productId: 'p1',
        name: 'V4',
        skuLower: 'sku4',
        categoryIds: ['c1'],
        sortOrder: 3,
      ),
    ],
  );
}

class _CountingBackend implements CatalogFirestoreBackend {
  final writeCounts = <String, int>{};
  final uniqueIds = <String, Set<String>>{};

  @override
  Future<void> batchSet(
    String collection,
    List<MapEntry<String, Map<String, dynamic>>> docs,
  ) async {
    writeCounts[collection] = (writeCounts[collection] ?? 0) + docs.length;
    uniqueIds.putIfAbsent(collection, () => {}).addAll(docs.map((e) => e.key));
  }

  @override
  Future<bool> deleteDocument(String collection, String docId) async => false;

  @override
  Future<int> deleteAllInCollection(
    String collection, {
    void Function(String collection, int deleted)? onProgress,
  }) async =>
      0;

  @override
  Future<int> countCollection(String collection) async => 0;

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
    int pageSize = 500,
    String? pageToken,
  }) async =>
      (docs: <MapEntry<String, Map<String, dynamic>>>[], nextPageToken: null);

  @override
  Future<List<MapEntry<String, Map<String, dynamic>>>> runStructuredQuery(
    Map<String, dynamic> queryBody,
  ) async =>
      [];

  @override
  Future<void> setDocument(
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) async {
    await batchSet(collection, [MapEntry(docId, data)]);
  }
}
