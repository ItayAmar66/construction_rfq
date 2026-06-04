import '../utils/firestore_parsing.dart';

class SupplierQuoteItem {
  const SupplierQuoteItem({
    required this.id,
    required this.supplierQuoteId,
    required this.productId,
    required this.productName,
    required this.requestedQuantity,
    required this.unitPrice,
    required this.totalItemPrice,
    this.notes,
    this.requestItemId,
    this.variantId,
    this.quotedName,
    this.quotedSku,
    this.isExactMatch = false,
    this.isAlternative = false,
    this.supplierNotes,
  });

  final String id;
  final String supplierQuoteId;
  final String productId;
  final String productName;
  final int requestedQuantity;
  final double unitPrice;
  final double totalItemPrice;
  final String? notes;
  final String? requestItemId;
  final String? variantId;
  final String? quotedName;
  final String? quotedSku;
  final bool isExactMatch;
  final bool isAlternative;
  final String? supplierNotes;

  String get displayName =>
      (quotedName != null && quotedName!.isNotEmpty) ? quotedName! : productName;

  factory SupplierQuoteItem.fromMap(String id, Map<String, dynamic> map) {
    return SupplierQuoteItem.fromEmbedded(
      quoteId: FirestoreParsing.parseString(map['supplierQuoteId']),
      map: map,
      index: 0,
      idOverride: id,
    );
  }

  factory SupplierQuoteItem.fromEmbedded({
    required String quoteId,
    required Map<String, dynamic> map,
    required int index,
    String? idOverride,
  }) {
    final productId = FirestoreParsing.parseString(map['productId']);
    final supplierNotes = FirestoreParsing.parseNullableString(
      map['supplierNotes'],
    );
    return SupplierQuoteItem(
      id: idOverride ??
          FirestoreParsing.parseString(
            map['id'],
            defaultValue: '${quoteId}_${index}_$productId',
          ),
      supplierQuoteId: quoteId,
      productId: productId,
      productName: FirestoreParsing.parseString(map['productName']),
      requestedQuantity: FirestoreParsing.parseInt(map['requestedQuantity']),
      unitPrice: FirestoreParsing.parseDouble(map['unitPrice']),
      totalItemPrice: FirestoreParsing.parseDouble(map['totalItemPrice']),
      notes: FirestoreParsing.parseNullableString(map['notes']) ?? supplierNotes,
      requestItemId: FirestoreParsing.parseNullableString(map['requestItemId']),
      variantId: FirestoreParsing.parseNullableString(map['variantId']),
      quotedName: FirestoreParsing.parseNullableString(map['quotedName']),
      quotedSku: FirestoreParsing.parseNullableString(map['quotedSku']),
      isExactMatch: FirestoreParsing.parseBool(map['isExactMatch']),
      isAlternative: FirestoreParsing.parseBool(map['isAlternative']),
      supplierNotes: supplierNotes,
    );
  }

  Map<String, dynamic> toEmbeddedMap() {
    return {
      'productId': productId,
      'productName': productName,
      'requestedQuantity': requestedQuantity,
      'unitPrice': unitPrice,
      'totalItemPrice': totalItemPrice,
      if (notes != null) 'notes': notes,
      if (requestItemId != null && requestItemId!.isNotEmpty)
        'requestItemId': requestItemId,
      if (variantId != null && variantId!.isNotEmpty) 'variantId': variantId,
      if (quotedName != null && quotedName!.isNotEmpty) 'quotedName': quotedName,
      if (quotedSku != null && quotedSku!.isNotEmpty) 'quotedSku': quotedSku,
      'isExactMatch': isExactMatch,
      'isAlternative': isAlternative,
      if (supplierNotes != null) 'supplierNotes': supplierNotes,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'supplierQuoteId': supplierQuoteId,
      'productId': productId,
      'productName': productName,
      'requestedQuantity': requestedQuantity,
      'unitPrice': unitPrice,
      'totalItemPrice': totalItemPrice,
      'notes': notes,
      if (requestItemId != null) 'requestItemId': requestItemId,
      if (variantId != null) 'variantId': variantId,
      if (quotedName != null) 'quotedName': quotedName,
      if (quotedSku != null) 'quotedSku': quotedSku,
      'isExactMatch': isExactMatch,
      'isAlternative': isAlternative,
      if (supplierNotes != null) 'supplierNotes': supplierNotes,
    };
  }
}
