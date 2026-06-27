import '../models/receipt_checklist_item.dart';
import '../models/receipt_status.dart';

class ShipmentReceiptValidationException implements Exception {
  ShipmentReceiptValidationException(this.message);
  final String message;

  @override
  String toString() => message;
}

abstract final class ShipmentReceiptValidation {
  static bool isFullReceipt(List<ReceiptChecklistItem> items) {
    if (items.isEmpty) return false;
    return items.every(
      (item) =>
          item.condition == ReceiptItemCondition.ok &&
          item.receivedQuantity == item.orderedQuantity,
    );
  }

  static bool hasIssues(List<ReceiptChecklistItem> items) => !isFullReceipt(items);

  static ReceiptStatus resolveStatus(List<ReceiptChecklistItem> items) {
    return isFullReceipt(items)
        ? ReceiptStatus.receivedFull
        : ReceiptStatus.receivedWithIssues;
  }

  static void validateItems(List<ReceiptChecklistItem> items) {
    if (items.isEmpty) {
      throw ShipmentReceiptValidationException('יש לכלול לפחות פריט אחד');
    }
    for (final item in items) {
      if (item.receivedQuantity < 0) {
        throw ShipmentReceiptValidationException(
          'כמות שהתקבלה לא יכולה להיות שלילית (${item.productName})',
        );
      }
      if (item.receivedQuantity != item.orderedQuantity &&
          item.condition == ReceiptItemCondition.ok) {
        throw ShipmentReceiptValidationException(
          'כאשר הכמות שונה מההזמנה יש לבחור סטטוס חריג (${item.productName})',
        );
      }
      if (item.condition.isIssue &&
          (item.issueNotes == null || item.issueNotes!.trim().isEmpty) &&
          item.condition != ReceiptItemCondition.missingQuantity) {
        throw ShipmentReceiptValidationException(
          'יש להוסיף הערות לפריט עם חריגה (${item.productName})',
        );
      }
    }
  }

  static void validateFullReceiptSubmit(List<ReceiptChecklistItem> items) {
    validateItems(items);
    if (!isFullReceipt(items)) {
      throw ShipmentReceiptValidationException(
        'אישור קבלה מלאה אפשרי רק כשכל הפריטים תקינים והכמויות תואמות',
      );
    }
  }

  static void validateIssueReceiptSubmit(List<ReceiptChecklistItem> items) {
    validateItems(items);
    if (!hasIssues(items)) {
      throw ShipmentReceiptValidationException(
        'דיווח חריגה דורש לפחות פריט אחד עם חריגה',
      );
    }
  }

  static List<ReceiptChecklistItem> markAllOk(
    List<ReceiptChecklistItem> items,
  ) {
    return items
        .map(
          (item) => item.copyWith(
            receivedQuantity: item.orderedQuantity,
            condition: ReceiptItemCondition.ok,
            issueNotes: '',
            updateIssueNotes: true,
          ),
        )
        .toList();
  }
}
