import 'package:construction_rfq/catalog_import/catalog_firestore_backend.dart';
import 'package:construction_rfq/catalog_import/catalog_production_light_verifier.dart';
import 'package:construction_rfq/catalog_import/catalog_variant_light_verify_fields.dart';
import 'package:construction_rfq/catalog_import/import_config.dart';
import 'package:construction_rfq/models/catalog/catalog_variant.dart';
import 'package:construction_rfq/repositories/catalog/catalog_firestore_converter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CatalogVariantLightVerifyFields', () {
    test('passes SKU-less active variant with required search fields', () {
      final errors = CatalogVariantLightVerifyFields.errorsForActiveSample({
        'displayNameLower': 'דבק לבן',
        'categoryIds': ['7'],
        'searchTokens': ['דבק', 'לבן'],
        'isActive': true,
      });
      expect(errors, isEmpty);
    });

    test('passes when skuLower is empty string', () {
      final errors = CatalogVariantLightVerifyFields.errorsForActiveSample({
        'displayNameLower': 'דבק לבן',
        'skuLower': '',
        'categoryIds': ['7'],
        'searchTokens': ['דבק'],
        'isActive': true,
      });
      expect(errors, isEmpty);
    });

    test('passes when skuLower is present for SKU variant', () {
      final errors = CatalogVariantLightVerifyFields.errorsForActiveSample({
        'displayNameLower': 'דבק fx-1',
        'skuLower': 'fx-1',
        'categoryIds': ['7'],
        'searchTokens': ['דבק', 'fx-1'],
        'isActive': true,
      });
      expect(errors, isEmpty);
    });

    test('fails when displayNameLower missing', () {
      final errors = CatalogVariantLightVerifyFields.errorsForActiveSample({
        'categoryIds': ['7'],
        'searchTokens': ['דבק'],
        'isActive': true,
      });
      expect(errors, anyElement(contains('displayNameLower')));
    });

    test('fails when searchTokens missing', () {
      final errors = CatalogVariantLightVerifyFields.errorsForActiveSample({
        'displayNameLower': 'דבק',
        'categoryIds': ['7'],
        'isActive': true,
      });
      expect(errors, anyElement(contains('searchTokens')));
    });

    test('fails when categoryIds missing', () {
      final errors = CatalogVariantLightVerifyFields.errorsForActiveSample({
        'displayNameLower': 'דבק',
        'searchTokens': ['דבק'],
        'isActive': true,
      });
      expect(errors, anyElement(contains('categoryIds')));
    });

    test('fails when isActive missing or false', () {
      expect(
        CatalogVariantLightVerifyFields.errorsForActiveSample({
          'displayNameLower': 'דבק',
          'categoryIds': ['7'],
          'searchTokens': ['דבק'],
        }),
        anyElement(contains('isActive')),
      );
      expect(
        CatalogVariantLightVerifyFields.errorsForActiveSample({
          'displayNameLower': 'דבק',
          'categoryIds': ['7'],
          'searchTokens': ['דבק'],
          'isActive': false,
        }),
        anyElement(contains('isActive != true')),
      );
    });
  });

  group('variant import map', () {
    test('writes skuLower empty string for SKU-less variant', () {
      const variant = CatalogVariant(
        id: '1',
        productId: '11',
        name: 'לבן',
        nameLower: 'לבן',
        displayName: 'דבק — לבן',
        displayNameLower: 'דבק לבן',
        categoryIds: ['7'],
        searchTokens: ['דבק', 'לבן'],
        isActiveInIndex: true,
      );
      final map = CatalogFirestoreConverter.variantToMap(variant);
      expect(map.containsKey('skuLower'), isTrue);
      expect(map['skuLower'], '');
    });
  });

  group('CatalogProductionLightVerifier', () {
    test('passes when active sample has no skuLower field', () async {
      final backend = _SkuLessRecordingBackend();
      final config = CatalogImportConfig(
        dataRoot: '/tmp',
        verifyProductionLight: true,
        productionMode: true,
        firebaseProjectId: CatalogImportProduction.requiredProjectId,
        outputDir: 'tools/catalog_import/out/test_light_skuless',
      );

      final result = await CatalogProductionLightVerifier(
        config: config,
        backend: backend,
      ).run();

      expect(result.passed, isTrue);
      expect(result.errors, isEmpty);
    });
  });
}

class _SkuLessRecordingBackend implements CatalogFirestoreBackend {
  @override
  Future<void> batchSet(
    String collection,
    List<MapEntry<String, Map<String, dynamic>>> docs,
  ) async {}

  @override
  Future<int> countCollection(String collection) async => 0;

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
    return (
      docs: [MapEntry('sample', {'id': collection})],
      nextPageToken: null,
    );
  }

  @override
  Future<List<MapEntry<String, Map<String, dynamic>>>> runStructuredQuery(
    Map<String, dynamic> queryBody,
  ) async {
    return [
      MapEntry(
        'v-skuless',
        {
          'displayNameLower': 'פריט ללא מקט',
          'categoryIds': ['7'],
          'searchTokens': ['פריט'],
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
