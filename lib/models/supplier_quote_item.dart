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
  });

  final String id;
  final String supplierQuoteId;
  final String productId;
  final String productName;
  final int requestedQuantity;
  final double unitPrice;
  final double totalItemPrice;
  final String? notes;

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
      notes: FirestoreParsing.parseNullableString(map['notes']),
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
    };
  }
}
