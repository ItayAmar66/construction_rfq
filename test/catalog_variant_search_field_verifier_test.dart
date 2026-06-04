import 'package:construction_rfq/catalog_import/catalog_variant_search_field_verifier.dart';
import 'package:construction_rfq/models/catalog/catalog_product.dart';
import 'package:construction_rfq/models/catalog/catalog_variant.dart';
import 'package:construction_rfq/repositories/catalog/catalog_firestore_converter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('valid enriched variant map passes', () {
    const variant = CatalogVariant(
      id: '1',
      productId: '11',
      name: 'לבן',
      nameLower: 'לבן',
      displayName: 'דבק — לבן',
      displayNameLower: 'דבק לבן',
      skuLower: 'fx-1',
      categoryIds: ['7'],
      searchTokens: ['דבק', 'לבן'],
      isActiveInIndex: true,
    );
    final map = CatalogFirestoreConverter.variantToMap(variant);
    expect(CatalogVariantSearchFieldVerifier.errorsForMap(map), isEmpty);
  });

  test('missing searchTokens fails', () {
    final errors = CatalogVariantSearchFieldVerifier.errorsForMap({
      'productId': '11',
      'name': 'x',
      'nameLower': 'x',
      'isActive': true,
      'categoryIds': [],
      'searchTokens': [],
    });
    expect(errors, contains('searchTokens is empty'));
  });

  test('verifyAll counts failures', () {
    const good = CatalogVariant(
      id: '1',
      productId: '11',
      name: 'a',
      nameLower: 'a',
      displayName: 'A',
      displayNameLower: 'a',
      categoryIds: ['1'],
      searchTokens: ['a'],
    );
    const bad = CatalogVariant(
      id: '2',
      productId: '11',
      name: 'b',
      nameLower: 'b',
      categoryIds: [],
    );
    final report = CatalogVariantSearchFieldVerifier.verifyAll([good, bad]);
    expect(report.variantsChecked, 2);
    expect(report.variantsFailed, 1);
    expect(report.passed, isFalse);
  });
}
