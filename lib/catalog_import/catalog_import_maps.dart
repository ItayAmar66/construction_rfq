import '../models/catalog/catalog_category.dart';
import '../models/catalog/catalog_meta.dart';
import '../models/catalog/catalog_product.dart';
import '../models/catalog/catalog_variant.dart';
import '../repositories/catalog/catalog_firestore_converter.dart';

/// Plain maps for emulator REST import (no FieldValue / Timestamp).
abstract final class CatalogImportMaps {
  static Map<String, dynamic> category(CatalogCategory c) =>
      CatalogFirestoreConverter.categoryToMap(c);

  static Map<String, dynamic> product(CatalogProduct p) {
    final map = Map<String, dynamic>.from(
      CatalogFirestoreConverter.productToMap(p),
    );
    map['updatedAt'] = DateTime.now().toUtc().toIso8601String();
    return map;
  }

  static Map<String, dynamic> variant(CatalogVariant v) =>
      CatalogFirestoreConverter.variantToMap(v);

  static Map<String, dynamic> meta(CatalogMeta m) => {
        'version': m.version,
        'productCount': m.productCount,
        'variantCount': m.variantCount,
        'categoryCount': m.categoryCount,
        'importedAt':
            (m.importedAt ?? DateTime.now().toUtc()).toIso8601String(),
        'imageBasePath': m.imageBasePath,
        'searchMode': m.searchMode,
        'isDemoSlice': m.isDemoSlice,
      };
}
