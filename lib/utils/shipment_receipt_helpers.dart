import '../models/quote_request.dart';
import '../models/receipt_checklist_item.dart';

abstract final class ShipmentReceiptHelpers {
  static List<ReceiptChecklistItem> initialChecklistFromRequest(
    QuoteRequest request,
  ) {
    if (request.receiptChecklist.isNotEmpty) {
      return request.receiptChecklist;
    }
    return request.items
        .map(
          (item) => ReceiptChecklistItem(
            itemId: item.id,
            productId: item.productId,
            variantId: item.variantId,
            productName: item.productName,
            orderedQuantity: item.quantity,
            receivedQuantity: item.quantity,
            unit: item.unitType,
          ),
        )
        .toList();
  }
}
