import '../models/catalog/catalog_category.dart';
import '../models/catalog/catalog_product.dart';
import '../models/catalog/catalog_variant.dart';
import '../repositories/catalog_search/memory_catalog_search_repository.dart';

/// In-memory catalog slice for demo / offline RFQ flows (matches enterprise demo SKUs).
abstract final class DemoCatalogSearchData {
  static const categories = <CatalogCategory>[
    CatalogCategory(id: '7', name: 'חיפוי', nameLower: 'חיפוי', sortOrder: 1),
    CatalogCategory(id: '3', name: 'בלוקים', nameLower: 'בלוקים', sortOrder: 2),
    CatalogCategory(id: '9', name: 'דבקים', nameLower: 'דבקים', sortOrder: 3),
  ];

  static const products = <CatalogProduct>[
    CatalogProduct(
      id: '11',
      name: 'דבק פיקס',
      primaryCategoryId: '7',
      categoryIds: ['7', '9'],
      sku: 'FX-1',
      unitType: 'שק',
      nameLower: 'דבק פיקס',
    ),
    CatalogProduct(
      id: '21',
      name: 'בלוק 20',
      primaryCategoryId: '3',
      categoryIds: ['3'],
      sku: 'BL-20',
      unitType: 'יחידה',
      nameLower: 'בלוק 20',
    ),
  ];

  static const variants = <CatalogVariant>[
    CatalogVariant(
      id: 'v1',
      productId: '11',
      name: 'לבן',
      displayName: 'דבק פיקס — לבן',
      displayNameLower: 'דבק פיקס לבן',
      categoryIds: ['7', '9'],
      primaryCategoryId: '7',
      categoryPathText: 'דבקים › חיפוי',
      searchTokens: ['דבק', 'פיקס', 'לבן', 'fx-1'],
      nameLower: 'לבן',
      skuLower: 'fx-1',
      sortOrder: 1,
    ),
    CatalogVariant(
      id: 'v2',
      productId: '11',
      name: 'אפור',
      displayName: 'דבק פיקס — אפור',
      displayNameLower: 'דבק פיקס אפור',
      categoryIds: ['7', '9'],
      primaryCategoryId: '7',
      categoryPathText: 'דבקים › חיפוי',
      searchTokens: ['דבק', 'פיקס', 'אפור'],
      nameLower: 'אפור',
      skuLower: 'fx-1',
      sortOrder: 2,
    ),
    CatalogVariant(
      id: 'v-block',
      productId: '21',
      name: 'רגיל',
      displayName: 'בלוק 20 — רגיל',
      displayNameLower: 'בלוק 20 רגיל',
      categoryIds: ['3'],
      primaryCategoryId: '3',
      categoryPathText: 'בלוקים',
      searchTokens: ['בלוק', '20'],
      nameLower: 'רגיל',
      skuLower: 'bl-20',
      sortOrder: 3,
    ),
  ];

  static MemoryCatalogSearchRepository repository() {
    return MemoryCatalogSearchRepository(
      categories: categories,
      products: products,
      variants: variants,
    );
  }
}
