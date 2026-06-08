import '../utils/firestore_parsing.dart';
import 'catalog/catalog_rfq_line_draft.dart';
import 'product.dart';

class QuoteRequestItem {
  const QuoteRequestItem({
    required this.id,
    required this.quoteRequestId,
    required this.productId,
    required this.productName,
    required this.category,
    required this.unitType,
    required this.quantity,
    this.notes,
    this.variantId,
    this.categoryId,
    this.categoryPath,
    this.sku,
    this.packagingLabel,
    this.variantName,
    this.catalogProductName,
    this.imagePath,
    this.attributesSnapshot = const {},
    this.sourceCatalogVersion,
    this.isCatalogMatched = false,
  });

  final String id;
  final String quoteRequestId;
  final String productId;
  final String productName;
  final String category;
  final String unitType;
  final int quantity;
  final String? notes;
  final String? variantId;
  final String? categoryId;
  final String? categoryPath;
  final String? sku;
  final String? packagingLabel;
  final String? variantName;
  final String? catalogProductName;
  final String? imagePath;
  final Map<String, String> attributesSnapshot;
  final String? sourceCatalogVersion;
  final bool isCatalogMatched;

  factory QuoteRequestItem.fromMap(String id, Map<String, dynamic> map) {
    return QuoteRequestItem.fromEmbedded(
      requestId: FirestoreParsing.parseString(map['quoteRequestId']),
      map: map,
      index: 0,
      idOverride: id,
    );
  }

  factory QuoteRequestItem.fromEmbedded({
    required String requestId,
    required Map<String, dynamic> map,
    required int index,
    String? idOverride,
  }) {
    final productId = FirestoreParsing.parseString(map['productId']);
    final attrsRaw = map['attributesSnapshot'];
    final attributes = attrsRaw is Map
        ? attrsRaw.map((k, v) => MapEntry(k.toString(), v.toString()))
        : const <String, String>{};

    return QuoteRequestItem(
      id: idOverride ??
          FirestoreParsing.parseString(
            map['id'],
            defaultValue: '${requestId}_${index}_$productId',
          ),
      quoteRequestId: requestId,
      productId: productId,
      productName: FirestoreParsing.parseString(map['productName']),
      category: FirestoreParsing.parseString(map['category']),
      unitType: FirestoreParsing.parseString(map['unitType']),
      quantity: FirestoreParsing.parseInt(map['quantity']),
      notes: FirestoreParsing.parseNullableString(map['notes']),
      variantId: FirestoreParsing.parseNullableString(map['variantId']),
      categoryId: FirestoreParsing.parseNullableString(map['categoryId']),
      categoryPath: FirestoreParsing.parseNullableString(map['categoryPath']),
      sku: FirestoreParsing.parseNullableString(map['sku']),
      packagingLabel:
          FirestoreParsing.parseNullableString(map['packagingLabel']),
      variantName: FirestoreParsing.parseNullableString(map['variantName']),
      catalogProductName:
          FirestoreParsing.parseNullableString(map['catalogProductName']),
      imagePath: FirestoreParsing.parseNullableString(map['imagePath']),
      attributesSnapshot: attributes,
      sourceCatalogVersion:
          FirestoreParsing.parseNullableString(map['sourceCatalogVersion']),
      isCatalogMatched: FirestoreParsing.parseBool(map['isCatalogMatched']),
    );
  }

  factory QuoteRequestItem.fromCatalogDraft(
    CatalogRfqLineDraft draft, {
    required String lineId,
    String quoteRequestId = '',
  }) {
    final unit = draft.unitType.isNotEmpty
        ? draft.unitType
        : (draft.packagingLabel.isNotEmpty ? draft.packagingLabel : '');
    return QuoteRequestItem(
      id: lineId,
      quoteRequestId: quoteRequestId,
      productId: draft.productId,
      productName: draft.displayName,
      category: draft.categoryPath.isNotEmpty
          ? draft.categoryPath
          : draft.categoryId,
      unitType: unit,
      quantity: draft.quantity,
      notes: draft.notes.isEmpty ? null : draft.notes,
      variantId: draft.variantId,
      categoryId: draft.categoryId,
      categoryPath: draft.categoryPath,
      sku: draft.sku.isEmpty ? null : draft.sku,
      packagingLabel:
          draft.packagingLabel.isEmpty ? null : draft.packagingLabel,
      variantName: draft.variantName.isEmpty ? null : draft.variantName,
      catalogProductName:
          draft.productName.isEmpty ? null : draft.productName,
      imagePath: draft.imagePath,
      attributesSnapshot: draft.attributesSnapshot,
      sourceCatalogVersion: draft.sourceCatalogVersion,
      isCatalogMatched: true,
    );
  }

  factory QuoteRequestItem.fromLegacyProduct({
    required Product product,
    required int quantity,
    required String lineId,
    String quoteRequestId = '',
    String? notes,
  }) {
    return QuoteRequestItem(
      id: lineId,
      quoteRequestId: quoteRequestId,
      productId: product.id,
      productName: product.name,
      category: product.category,
      unitType: product.unitType,
      quantity: quantity,
      notes: notes,
      isCatalogMatched: false,
    );
  }

  QuoteRequestItem copyWith({
    int? quantity,
    String? notes,
    bool updateNotes = false,
  }) {
    return QuoteRequestItem(
      id: id,
      quoteRequestId: quoteRequestId,
      productId: productId,
      productName: productName,
      category: category,
      unitType: unitType,
      quantity: quantity ?? this.quantity,
      notes: updateNotes ? notes : this.notes,
      variantId: variantId,
      categoryId: categoryId,
      categoryPath: categoryPath,
      sku: sku,
      packagingLabel: packagingLabel,
      variantName: variantName,
      catalogProductName: catalogProductName,
      imagePath: imagePath,
      attributesSnapshot: attributesSnapshot,
      sourceCatalogVersion: sourceCatalogVersion,
      isCatalogMatched: isCatalogMatched,
    );
  }

  Map<String, dynamic> toEmbeddedMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'productId': productId,
      'productName': productName,
      'category': category,
      'unitType': unitType,
      'quantity': quantity,
      if (notes != null) 'notes': notes,
      if (variantId != null && variantId!.isNotEmpty) 'variantId': variantId,
      if (categoryId != null && categoryId!.isNotEmpty)
        'categoryId': categoryId,
      if (categoryPath != null && categoryPath!.isNotEmpty)
        'categoryPath': categoryPath,
      if (sku != null && sku!.isNotEmpty) 'sku': sku,
      if (packagingLabel != null && packagingLabel!.isNotEmpty)
        'packagingLabel': packagingLabel,
      if (variantName != null && variantName!.isNotEmpty)
        'variantName': variantName,
      if (catalogProductName != null && catalogProductName!.isNotEmpty)
        'catalogProductName': catalogProductName,
      if (imagePath != null && imagePath!.isNotEmpty) 'imagePath': imagePath,
      if (attributesSnapshot.isNotEmpty)
        'attributesSnapshot': attributesSnapshot,
      if (sourceCatalogVersion != null && sourceCatalogVersion!.isNotEmpty)
        'sourceCatalogVersion': sourceCatalogVersion,
      'isCatalogMatched': isCatalogMatched,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'quoteRequestId': quoteRequestId,
      'productId': productId,
      'productName': productName,
      'category': category,
      'unitType': unitType,
      'quantity': quantity,
      'notes': notes,
      if (variantId != null) 'variantId': variantId,
      if (categoryId != null) 'categoryId': categoryId,
      if (categoryPath != null) 'categoryPath': categoryPath,
      if (sku != null) 'sku': sku,
      if (packagingLabel != null) 'packagingLabel': packagingLabel,
      if (variantName != null) 'variantName': variantName,
      if (catalogProductName != null) 'catalogProductName': catalogProductName,
      if (imagePath != null) 'imagePath': imagePath,
      if (attributesSnapshot.isNotEmpty)
        'attributesSnapshot': attributesSnapshot,
      if (sourceCatalogVersion != null)
        'sourceCatalogVersion': sourceCatalogVersion,
      'isCatalogMatched': isCatalogMatched,
    };
  }
}
