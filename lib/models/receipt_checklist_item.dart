import '../utils/firestore_parsing.dart';

enum ReceiptItemCondition {
  ok,
  missingQuantity,
  damaged,
  wrongItem,
  notReceived,
}

extension ReceiptItemConditionExtension on ReceiptItemCondition {
  String get firestoreValue {
    switch (this) {
      case ReceiptItemCondition.ok:
        return 'ok';
      case ReceiptItemCondition.missingQuantity:
        return 'missing_quantity';
      case ReceiptItemCondition.damaged:
        return 'damaged';
      case ReceiptItemCondition.wrongItem:
        return 'wrong_item';
      case ReceiptItemCondition.notReceived:
        return 'not_received';
    }
  }

  String get label {
    switch (this) {
      case ReceiptItemCondition.ok:
        return 'התקבל תקין';
      case ReceiptItemCondition.missingQuantity:
        return 'חסרה כמות';
      case ReceiptItemCondition.damaged:
        return 'מוצר פגום';
      case ReceiptItemCondition.wrongItem:
        return 'מוצר לא תואם';
      case ReceiptItemCondition.notReceived:
        return 'לא התקבל';
    }
  }

  static ReceiptItemCondition fromFirestore(String? raw) {
    switch (raw) {
      case 'missing_quantity':
        return ReceiptItemCondition.missingQuantity;
      case 'damaged':
        return ReceiptItemCondition.damaged;
      case 'wrong_item':
        return ReceiptItemCondition.wrongItem;
      case 'not_received':
        return ReceiptItemCondition.notReceived;
      case 'ok':
      default:
        return ReceiptItemCondition.ok;
    }
  }

  bool get isIssue => this != ReceiptItemCondition.ok;
}

class ReceiptChecklistItem {
  const ReceiptChecklistItem({
    required this.itemId,
    required this.productName,
    required this.orderedQuantity,
    required this.receivedQuantity,
    this.productId,
    this.variantId,
    this.unit,
    this.condition = ReceiptItemCondition.ok,
    this.issueNotes,
  });

  final String itemId;
  final String? productId;
  final String? variantId;
  final String productName;
  final int orderedQuantity;
  final int receivedQuantity;
  final String? unit;
  final ReceiptItemCondition condition;
  final String? issueNotes;

  ReceiptChecklistItem copyWith({
    int? receivedQuantity,
    ReceiptItemCondition? condition,
    String? issueNotes,
    bool updateIssueNotes = false,
  }) {
    return ReceiptChecklistItem(
      itemId: itemId,
      productId: productId,
      variantId: variantId,
      productName: productName,
      orderedQuantity: orderedQuantity,
      receivedQuantity: receivedQuantity ?? this.receivedQuantity,
      unit: unit,
      condition: condition ?? this.condition,
      issueNotes: updateIssueNotes ? issueNotes : this.issueNotes,
    );
  }

  factory ReceiptChecklistItem.fromMap(Map<String, dynamic> map) {
    return ReceiptChecklistItem(
      itemId: FirestoreParsing.parseString(map['itemId']),
      productId: FirestoreParsing.parseNullableString(map['productId']),
      variantId: FirestoreParsing.parseNullableString(map['variantId']),
      productName: FirestoreParsing.parseString(map['productName']),
      orderedQuantity: FirestoreParsing.parseInt(map['orderedQuantity']),
      receivedQuantity: FirestoreParsing.parseInt(map['receivedQuantity']),
      unit: FirestoreParsing.parseNullableString(map['unit']),
      condition: ReceiptItemConditionExtension.fromFirestore(
        FirestoreParsing.parseNullableString(map['condition']),
      ),
      issueNotes: FirestoreParsing.parseNullableString(map['issueNotes']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      if (productId != null && productId!.isNotEmpty) 'productId': productId,
      if (variantId != null && variantId!.isNotEmpty) 'variantId': variantId,
      'productName': productName,
      'orderedQuantity': orderedQuantity,
      'receivedQuantity': receivedQuantity,
      if (unit != null && unit!.isNotEmpty) 'unit': unit,
      'condition': condition.firestoreValue,
      if (issueNotes != null && issueNotes!.isNotEmpty)
        'issueNotes': issueNotes,
    };
  }
}
