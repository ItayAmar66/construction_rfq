import '../utils/firestore_parsing.dart';

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
  });

  final String id;
  final String quoteRequestId;
  final String productId;
  final String productName;
  final String category;
  final String unitType;
  final int quantity;
  final String? notes;

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
    );
  }

  Map<String, dynamic> toEmbeddedMap() {
    return {
      'productId': productId,
      'productName': productName,
      'category': category,
      'unitType': unitType,
      'quantity': quantity,
      if (notes != null) 'notes': notes,
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
    };
  }
}
