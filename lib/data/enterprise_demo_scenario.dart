import '../models/quote_request.dart';
import '../models/quote_request_item.dart';
import '../models/quote_status.dart';
import '../models/supplier_quote.dart';
import '../models/supplier_quote_item.dart';
import '../services/mock_store.dart';
import '../utils/supplier_quote_status.dart';

/// Pre-built enterprise walkthrough data for demo mode only.
abstract final class EnterpriseDemoScenario {
  static const compareRequestId = 'demo-enterprise-compare';
  static const fulfilledRequestId = 'demo-enterprise-fulfilled';
  static const exactQuoteId = 'demo-quote-exact';
  static const altQuoteId = 'demo-quote-alt';
  static const approvedQuoteId = 'demo-quote-approved';

  static const catalogLineId = 'demo-catalog-line';
  static const manualLineId = 'demo-manual-line';

  /// Idempotent seed for investor / QA walkthrough.
  static void seedIfNeeded(MockStore store) {
    if (store.quoteRequests.any((r) => r.id == compareRequestId)) {
      return;
    }

    final now = DateTime.now();
    final compareCreated = now.subtract(const Duration(days: 2));
    final fulfilledCreated = now.subtract(const Duration(days: 7));

    const catalogItem = QuoteRequestItem(
      id: catalogLineId,
      quoteRequestId: compareRequestId,
      productId: '11',
      productName: 'דבק פיקס — לבן',
      category: 'חיפוי',
      unitType: 'שק',
      quantity: 2,
      variantId: 'v1',
      categoryId: '7',
      categoryPath: 'דבקים › חיפוי',
      sku: 'FX-1',
      isCatalogMatched: true,
    );

    const manualItem = QuoteRequestItem(
      id: manualLineId,
      quoteRequestId: compareRequestId,
      productId: 'manual-demo-block',
      productName: 'בלוק 20',
      category: 'בלוקים',
      unitType: 'יחידה',
      quantity: 3,
      isCatalogMatched: false,
    );

    store.quoteRequests.add(
      QuoteRequest(
        id: compareRequestId,
        customerId: MockStore.demoCustomer.id,
        customerName: MockStore.demoCustomer.fullName,
        customerPhone: MockStore.demoCustomer.phone,
        customerCity: MockStore.demoCustomer.city,
        customerType: MockStore.demoCustomer.userType.value,
        status: QuoteRequestStatus.quotesReceived,
        notes: 'תרחיש הדגמה — השוואת הצעות',
        createdAt: compareCreated,
        updatedAt: compareCreated.add(const Duration(hours: 6)),
        items: const [catalogItem, manualItem],
        supplierIdsResponded: [
          MockStore.demoSupplier.id,
          'demo-supplier-2',
        ],
      ),
    );

    store.supplierQuotes.addAll([
      SupplierQuote(
        id: exactQuoteId,
        quoteRequestId: compareRequestId,
        supplierId: MockStore.demoSupplier.id,
        supplierName: MockStore.demoSupplier.fullName,
        supplierType: MockStore.demoSupplier.userType.value,
        deliveryTime: '2 ימים',
        totalPrice: 50,
        subtotal: 50,
        totalInclVat: 50,
        status: SupplierQuoteStatus.sent,
        createdAt: compareCreated.add(const Duration(hours: 2)),
        items: const [
          SupplierQuoteItem(
            id: 'demo-qi-exact-catalog',
            supplierQuoteId: exactQuoteId,
            productId: '11',
            productName: 'דבק פיקס — לבן',
            requestedQuantity: 2,
            unitPrice: 10,
            totalItemPrice: 20,
            requestItemId: catalogLineId,
            variantId: 'v1',
            isExactMatch: true,
          ),
          SupplierQuoteItem(
            id: 'demo-qi-exact-manual',
            supplierQuoteId: exactQuoteId,
            productId: 'manual-demo-block',
            productName: 'בלוק 20',
            requestedQuantity: 3,
            unitPrice: 10,
            totalItemPrice: 30,
            requestItemId: manualLineId,
          ),
        ],
      ),
      SupplierQuote(
        id: altQuoteId,
        quoteRequestId: compareRequestId,
        supplierId: 'demo-supplier-2',
        supplierName: 'ספק חלופות לדוגמה',
        supplierType: 'commercial',
        deliveryTime: '4 ימים',
        totalPrice: 42,
        subtotal: 42,
        totalInclVat: 42,
        status: SupplierQuoteStatus.sent,
        createdAt: compareCreated.add(const Duration(hours: 4)),
        items: const [
          SupplierQuoteItem(
            id: 'demo-qi-alt-catalog',
            supplierQuoteId: altQuoteId,
            productId: '11',
            productName: 'דבק דומה',
            requestedQuantity: 2,
            unitPrice: 9,
            totalItemPrice: 18,
            requestItemId: catalogLineId,
            variantId: 'v1',
            quotedName: 'דבק דומה',
            quotedSku: 'ALT-1',
            isAlternative: true,
            supplierNotes: 'חלופה מאושרת להדגמה',
          ),
        ],
      ),
      SupplierQuote(
        id: approvedQuoteId,
        quoteRequestId: fulfilledRequestId,
        supplierId: MockStore.demoSupplier.id,
        supplierName: MockStore.demoSupplier.fullName,
        supplierType: MockStore.demoSupplier.userType.value,
        deliveryTime: '3 ימים',
        totalPrice: 120,
        subtotal: 120,
        totalInclVat: 120,
        status: SupplierQuoteStatus.shipped,
        createdAt: fulfilledCreated.add(const Duration(days: 1)),
        items: const [
          SupplierQuoteItem(
            id: 'demo-qi-approved',
            supplierQuoteId: approvedQuoteId,
            productId: '11',
            productName: 'דבק פיקס — לבן',
            requestedQuantity: 4,
            unitPrice: 30,
            totalItemPrice: 120,
            requestItemId: 'demo-fulfilled-catalog',
            variantId: 'v1',
            isExactMatch: true,
          ),
        ],
      ),
    ]);

    store.quoteRequests.add(
      QuoteRequest(
        id: fulfilledRequestId,
        customerId: MockStore.demoCustomer.id,
        customerName: MockStore.demoCustomer.fullName,
        customerPhone: MockStore.demoCustomer.phone,
        customerCity: MockStore.demoCustomer.city,
        customerType: MockStore.demoCustomer.userType.value,
        status: QuoteRequestStatus.shipped,
        notes: 'תרחיש הדגמה — הזמנה מאושרת בדרך',
        createdAt: fulfilledCreated,
        updatedAt: now.subtract(const Duration(hours: 3)),
        items: const [
          QuoteRequestItem(
            id: 'demo-fulfilled-catalog',
            quoteRequestId: fulfilledRequestId,
            productId: '11',
            productName: 'דבק פיקס — לבן',
            category: 'חיפוי',
            unitType: 'שק',
            quantity: 4,
            variantId: 'v1',
            categoryId: '7',
            isCatalogMatched: true,
          ),
          QuoteRequestItem(
            id: 'demo-fulfilled-manual',
            quoteRequestId: fulfilledRequestId,
            productId: 'manual-fulfilled',
            productName: 'מלט',
            category: 'צמנט',
            unitType: 'שק',
            quantity: 5,
            isCatalogMatched: false,
          ),
        ],
        supplierIdsResponded: [MockStore.demoSupplier.id],
        approvedQuoteId: approvedQuoteId,
      ),
    );

  }
}
