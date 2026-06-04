import 'package:construction_rfq/models/catalog/catalog_category.dart';
import 'package:construction_rfq/models/catalog/catalog_image.dart';
import 'package:construction_rfq/models/catalog/catalog_list_query.dart';
import 'package:construction_rfq/models/catalog/catalog_meta.dart';
import 'package:construction_rfq/models/catalog/catalog_product.dart';
import 'package:construction_rfq/repositories/catalog/catalog_firestore_converter.dart';
import 'package:construction_rfq/repositories/catalog/memory_catalog_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Firestore converter round-trip for category and product', () {
    const category = CatalogCategory(
      id: '7',
      name: 'חיפוי',
      parentId: '2',
      pathIds: ['2', '7'],
      pathNames: ['דבקים', 'חיפוי'],
      depth: 1,
      hasProducts: true,
      nameLower: 'חיפוי',
    );

    final catMap = CatalogFirestoreConverter.categoryToMap(category);
    final catBack =
        CatalogFirestoreConverter.categoryFromDoc('7', catMap);
    expect(catBack.name, category.name);
    expect(catBack.pathIds, category.pathIds);

    final product = const CatalogProduct(
      id: '11',
      name: 'דבק פיקס',
      categoryIds: ['7'],
      primaryCategoryId: '7',
      categoryPathNames: ['חיפוי'],
      unitType: 'UNIT',
      searchTokens: ['דבק'],
      nameLower: 'דבק פיקס',
      legacyCategory: 'חיפוי',
      image: CatalogImage(localPath: 'assets/images/x.webp'),
    );

    final prodMap = CatalogFirestoreConverter.productToMap(product);
    final prodBack =
        CatalogFirestoreConverter.productFromDoc('11', prodMap);
    expect(prodBack.name, product.name);
    expect(prodBack.primaryCategoryId, '7');
    expect(prodBack.toLegacyProductMap()['category'], 'חיפוי');
  });

  test('MemoryCatalogRepository pagination cursor', () async {
    final products = List.generate(
      10,
      (i) => CatalogProduct(
        id: '$i',
        name: 'Product $i',
        primaryCategoryId: '1',
        categoryIds: ['1'],
        nameLower: 'product $i',
        isActive: true,
      ),
    );

    final repo = MemoryCatalogRepository(
      meta: const CatalogMeta(version: 'test', productCount: 10),
      categories: const [
        CatalogCategory(id: '1', name: 'Cat', nameLower: 'cat'),
      ],
      products: products,
    );

    final page1 = await repo.listProducts(
      const CatalogListQuery(limit: 4, primaryCategoryId: '1'),
    );
    expect(page1.items.length, 4);
    expect(page1.hasMore, isTrue);

    final parts = page1.nextCursor!.split('|');
    final page2 = await repo.listProducts(
      CatalogListQuery(
        limit: 4,
        primaryCategoryId: '1',
        startAfterNameLower: parts[0],
        startAfterId: parts[1],
      ),
    );
    expect(page2.items.length, 4);
  });
}
