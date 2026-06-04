import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/catalog/catalog_category.dart';
import '../../models/catalog/catalog_image.dart';
import '../../models/catalog/catalog_meta.dart';
import '../../models/catalog/catalog_product.dart';
import '../../models/catalog/catalog_variant.dart';
import '../../utils/firestore_parsing.dart';

/// Maps catalog domain models ↔ Firestore documents.
abstract final class CatalogFirestoreConverter {
  static CatalogCategory categoryFromDoc(String id, Map<String, dynamic> data) {
    return CatalogCategory(
      id: id,
      name: FirestoreParsing.parseString(data['name']),
      parentId: FirestoreParsing.parseNullableString(data['parentId']),
      pathIds: FirestoreParsing.parseStringList(data['pathIds']),
      pathNames: FirestoreParsing.parseStringList(data['pathNames']),
      depth: FirestoreParsing.parseInt(data['depth']),
      hasProducts: FirestoreParsing.parseBool(data['hasProducts']),
      sortOrder: FirestoreParsing.parseInt(data['sortOrder']),
      productCount: FirestoreParsing.parseInt(data['productCount']),
      isActive: FirestoreParsing.parseBool(data['isActive'], defaultValue: true),
      nameLower: FirestoreParsing.parseString(
        data['nameLower'],
        defaultValue: FirestoreParsing.parseString(data['name']).toLowerCase(),
      ),
    );
  }

  static Map<String, dynamic> categoryToMap(CatalogCategory c) => {
        'name': c.name,
        'nameLower': c.nameLower.isEmpty ? c.name.toLowerCase() : c.nameLower,
        if (c.parentId != null) 'parentId': c.parentId,
        'pathIds': c.pathIds,
        'pathNames': c.pathNames,
        'depth': c.depth,
        'hasProducts': c.hasProducts,
        'sortOrder': c.sortOrder,
        'productCount': c.productCount,
        'isActive': c.isActive,
      };

  static CatalogProduct productFromDoc(String id, Map<String, dynamic> data) {
    final specsRaw = data['specs'];
    final specs = <String, String>{};
    if (specsRaw is Map) {
      specsRaw.forEach((k, v) {
        if (v != null) specs[k.toString()] = v.toString();
      });
    }

    return CatalogProduct(
      id: id,
      name: FirestoreParsing.parseString(data['name']),
      aka: FirestoreParsing.parseStringList(data['aka']),
      searchTokens: FirestoreParsing.parseStringList(data['searchTokens']),
      categoryIds: FirestoreParsing.parseStringList(data['categoryIds']),
      primaryCategoryId:
          FirestoreParsing.parseString(data['primaryCategoryId']),
      categoryPathNames:
          FirestoreParsing.parseStringList(data['categoryPathNames']),
      brand: FirestoreParsing.parseString(data['brand']),
      sku: FirestoreParsing.parseString(data['sku']),
      unitType: FirestoreParsing.parseString(data['unitType']),
      packagingLabel: FirestoreParsing.parseString(data['packagingLabel']),
      descriptionPlain: FirestoreParsing.parseString(data['descriptionPlain']),
      descriptionHtml: FirestoreParsing.parseNullableString(data['descriptionHtml']),
      specs: specs,
      isActive: FirestoreParsing.parseBool(data['isActive'], defaultValue: true),
      variantCount: FirestoreParsing.parseInt(data['variantCount']),
      defaultVariantId:
          FirestoreParsing.parseNullableString(data['defaultVariantId']),
      image: CatalogImage.fromMap(
        data['image'] is Map<String, dynamic>
            ? data['image'] as Map<String, dynamic>
            : _legacyImageFields(data),
      ),
      relatedProductIds:
          FirestoreParsing.parseStringList(data['relatedProductIds']),
      nameLower: FirestoreParsing.parseString(
        data['nameLower'],
        defaultValue: FirestoreParsing.parseString(data['name']).toLowerCase(),
      ),
      legacyCategory: FirestoreParsing.parseString(
        data['legacyCategory'],
        defaultValue: FirestoreParsing.parseString(data['category']),
      ),
      legacyVariant: FirestoreParsing.parseString(
        data['legacyVariant'],
        defaultValue: FirestoreParsing.parseString(data['variant']),
      ),
      updatedAt: FirestoreParsing.parseDate(data['updatedAt']),
    );
  }

  static Map<String, dynamic> _legacyImageFields(Map<String, dynamic> data) {
    if (data['imageUrl'] == null && data['imageThumbUrl'] == null) {
      return {};
    }
    return {
      'url': data['imageUrl'],
      'thumbUrl': data['imageThumbUrl'],
      'localPath': data['imageLocalPath'],
    };
  }

  static Map<String, dynamic> productToMap(
    CatalogProduct p, {
    bool forImport = false,
  }) {
    return {
      'name': p.name,
      'nameLower': p.nameLower.isEmpty ? p.name.toLowerCase() : p.nameLower,
      'aka': p.aka,
      'searchTokens': p.searchTokens,
      'categoryIds': p.categoryIds,
      'primaryCategoryId': p.primaryCategoryId,
      'categoryPathNames': p.categoryPathNames,
      if (p.brand.isNotEmpty) 'brand': p.brand,
      if (p.sku.isNotEmpty) 'sku': p.sku,
      'unitType': p.unitType,
      if (p.packagingLabel.isNotEmpty) 'packagingLabel': p.packagingLabel,
      'descriptionPlain': p.descriptionPlain,
      if (p.descriptionHtml != null) 'descriptionHtml': p.descriptionHtml,
      if (p.specs.isNotEmpty) 'specs': p.specs,
      'isActive': p.isActive,
      'variantCount': p.variantCount,
      if (p.defaultVariantId != null) 'defaultVariantId': p.defaultVariantId,
      'image': p.image.toMap(),
      'imageUrl': p.image.url,
      'imageThumbUrl': p.image.thumbUrl,
      if (p.image.localPath != null) 'imageLocalPath': p.image.localPath,
      if (p.relatedProductIds.isNotEmpty)
        'relatedProductIds': p.relatedProductIds,
      'legacyCategory': p.legacyCategory,
      'legacyVariant': p.legacyVariant,
      'category': p.legacyCategory,
      'variant': p.legacyVariant,
      'updatedAt': forImport
          ? FieldValue.serverTimestamp()
          : (p.updatedAt != null ? Timestamp.fromDate(p.updatedAt!) : null),
    };
  }

  static CatalogVariant variantFromDoc(String id, Map<String, dynamic> data) {
    final name = FirestoreParsing.parseString(data['name']);
    final nameLower = FirestoreParsing.parseString(
      data['nameLower'],
      defaultValue: name.toLowerCase(),
    );
    final displayName = FirestoreParsing.parseString(data['displayName']);
    return CatalogVariant(
      id: id,
      productId: FirestoreParsing.parseString(data['productId']),
      name: name,
      color: FirestoreParsing.parseNullableString(data['color']),
      sizeLabel: FirestoreParsing.parseString(data['sizeLabel']),
      status: FirestoreParsing.parseString(data['status'], defaultValue: 'Active'),
      sortOrder: FirestoreParsing.parseInt(data['sortOrder']),
      image: CatalogImage.fromMap(
        data['image'] is Map<String, dynamic>
            ? data['image'] as Map<String, dynamic>
            : _legacyImageFields(data),
      ),
      nameLower: nameLower,
      legacyKey: FirestoreParsing.parseNullableString(data['legacyKey']),
      displayName: displayName,
      displayNameLower: FirestoreParsing.parseString(
        data['displayNameLower'],
        defaultValue: displayName.isNotEmpty
            ? displayName.toLowerCase()
            : nameLower,
      ),
      skuLower: FirestoreParsing.parseString(data['skuLower']),
      categoryIds: FirestoreParsing.parseStringList(data['categoryIds']),
      primaryCategoryId:
          FirestoreParsing.parseString(data['primaryCategoryId']),
      categoryPathText: FirestoreParsing.parseString(data['categoryPathText']),
      searchTokens: FirestoreParsing.parseStringList(data['searchTokens']),
      searchAliases: FirestoreParsing.parseStringList(data['searchAliases']),
      isActiveInIndex: data.containsKey('isActive')
          ? FirestoreParsing.parseBool(data['isActive'], defaultValue: true)
          : FirestoreParsing.parseString(data['status'], defaultValue: 'Active')
              .toLowerCase() ==
              'active',
    );
  }

  static Map<String, dynamic> variantToMap(CatalogVariant v) => {
        'productId': v.productId,
        'name': v.name,
        'nameLower': v.nameLower.isEmpty ? v.name.toLowerCase() : v.nameLower,
        if (v.displayName.isNotEmpty) 'displayName': v.displayName,
        if (v.displayNameLower.isNotEmpty)
          'displayNameLower': v.displayNameLower,
        if (v.skuLower.isNotEmpty) 'skuLower': v.skuLower,
        'categoryIds': v.categoryIds,
        if (v.primaryCategoryId.isNotEmpty)
          'primaryCategoryId': v.primaryCategoryId,
        if (v.categoryPathText.isNotEmpty)
          'categoryPathText': v.categoryPathText,
        'searchTokens': v.searchTokens,
        if (v.searchAliases.isNotEmpty) 'searchAliases': v.searchAliases,
        'isActive': v.isActiveInIndex,
        if (v.color != null) 'color': v.color,
        'sizeLabel': v.sizeLabel,
        'status': v.status,
        'sortOrder': v.sortOrder,
        'image': v.image.toMap(),
        'imageUrl': v.image.url,
        'imageThumbUrl': v.image.thumbUrl,
        if (v.image.localPath != null) 'imageLocalPath': v.image.localPath,
        if (v.legacyKey != null) 'legacyKey': v.legacyKey,
      };

  static CatalogMeta metaFromDoc(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) {
      return const CatalogMeta(version: '');
    }
    return CatalogMeta(
      version: FirestoreParsing.parseString(data['version']),
      productCount: FirestoreParsing.parseInt(data['productCount']),
      variantCount: FirestoreParsing.parseInt(data['variantCount']),
      categoryCount: FirestoreParsing.parseInt(data['categoryCount']),
      importedAt: FirestoreParsing.parseDate(data['importedAt']),
      imageBasePath: FirestoreParsing.parseString(
        data['imageBasePath'],
        defaultValue: 'catalog/images',
      ),
      searchMode: FirestoreParsing.parseString(
        data['searchMode'],
        defaultValue: 'firestore',
      ),
      isDemoSlice: FirestoreParsing.parseBool(data['isDemoSlice']),
    );
  }

  static Map<String, dynamic> metaToMap(CatalogMeta m) => {
        'version': m.version,
        'productCount': m.productCount,
        'variantCount': m.variantCount,
        'categoryCount': m.categoryCount,
        'importedAt': m.importedAt != null
            ? Timestamp.fromDate(m.importedAt!)
            : FieldValue.serverTimestamp(),
        'imageBasePath': m.imageBasePath,
        'searchMode': m.searchMode,
        'isDemoSlice': m.isDemoSlice,
      };
}
