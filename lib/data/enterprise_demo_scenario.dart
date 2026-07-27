import '../models/quote_request.dart';
import '../models/quote_request_item.dart';
import '../models/quote_status.dart';
import '../models/receipt_status.dart';
import '../models/supplier_quote.dart';
import '../models/supplier_quote_item.dart';
import '../services/mock_store.dart';
import '../utils/supplier_quote_status.dart';

/// Pre-built enterprise walkthrough data for demo mode only.
abstract final class EnterpriseDemoScenario {
  static const compareRequestId = 'demo-enterprise-compare';
  static const fulfilledRequestId = 'demo-enterprise-fulfilled';
  static const activeRequestId = 'demo-enterprise-active';
  static const exactQuoteId = 'demo-quote-exact';
  static const altQuoteId = 'demo-quote-alt';
  static const approvedQuoteId = 'demo-quote-approved';

  static const catalogLineId = 'demo-catalog-line';
  static const manualLineId = 'demo-manual-line';
  static const activeCatalogLineId = 'demo-active-catalog';
  static const activeManualLineId = 'demo-active-manual';

  static const customerCompany = 'א.ב. בנייה בע״מ';
  static const projectSite = 'מגדלי הים החדש · אתר 12';

  /// Idempotent seed for investor / QA walkthrough.
  static void seedIfNeeded(MockStore store) {
    if (store.quoteRequests.any((r) => r.id == compareRequestId)) {
      return;
    }

    final now = DateTime.now();
    final compareCreated = now.subtract(const Duration(days: 2));
    final fulfilledCreated = now.subtract(const Duration(days: 7));
    final activeCreated = now.subtract(const Duration(hours: 4));

    const catalogItem = QuoteRequestItem(
      id: catalogLineId,
      quoteRequestId: compareRequestId,
      productId: '11',
      productName: 'דבק פיקס — לבן',
      category: 'חיפוי',
      unitType: 'שק',
      quantity: 220,
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
      quantity: 480,
      notes: 'לקומות 3–5',
      isCatalogMatched: false,
    );

    store.quoteRequests.addAll([
      QuoteRequest(
        id: activeRequestId,
        customerId: MockStore.demoCustomer.id,
        customerName: MockStore.demoCustomer.fullName,
        customerPhone: MockStore.demoCustomer.phone,
        customerCity: MockStore.demoCustomer.city,
        customerType: MockStore.demoCustomer.userType.value,
        status: QuoteRequestStatus.sent,
        notes: '$projectSite — שלד קומה 4',
        createdAt: activeCreated,
        updatedAt: activeCreated,
        items: const [
          QuoteRequestItem(
            id: activeCatalogLineId,
            quoteRequestId: activeRequestId,
            productId: '11',
            productName: 'דבק פיקס — לבן',
            category: 'חיפוי',
            unitType: 'שק',
            quantity: 260,
            variantId: 'v1',
            categoryId: '7',
            categoryPath: 'דבקים › חיפוי',
            sku: 'FX-1',
            isCatalogMatched: true,
          ),
          QuoteRequestItem(
            id: activeManualLineId,
            quoteRequestId: activeRequestId,
            productId: 'manual-cement',
            productName: 'מלט פורטלנד',
            category: 'צמנט',
            unitType: 'שק',
            quantity: 350,
            notes: 'אספקה לעגלה ביום שלישי',
            isCatalogMatched: false,
          ),
        ],
      ),
      QuoteRequest(
        id: compareRequestId,
        customerId: MockStore.demoCustomer.id,
        customerName: MockStore.demoCustomer.fullName,
        customerPhone: MockStore.demoCustomer.phone,
        customerCity: MockStore.demoCustomer.city,
        customerType: MockStore.demoCustomer.userType.value,
        status: QuoteRequestStatus.quotesReceived,
        notes: '$projectSite — השוואת הצעות גימור',
        createdAt: compareCreated,
        updatedAt: compareCreated.add(const Duration(hours: 6)),
        items: const [catalogItem, manualItem],
        supplierIdsResponded: [
          MockStore.demoSupplier.id,
          MockStore.demoSupplierAlt.id,
        ],
      ),
    ]);

    store.supplierQuotes.addAll([
      SupplierQuote(
        id: exactQuoteId,
        quoteRequestId: compareRequestId,
        supplierId: MockStore.demoSupplier.id,
        supplierName: MockStore.demoSupplier.fullName,
        supplierType: MockStore.demoSupplier.userType.value,
        deliveryTime: '2 ימי עסקים',
        totalPrice: 15960,
        subtotal: 15960,
        totalInclVat: 15960,
        status: SupplierQuoteStatus.sent,
        createdAt: compareCreated.add(const Duration(hours: 2)),
        items: const [
          SupplierQuoteItem(
            id: 'demo-qi-exact-catalog',
            supplierQuoteId: exactQuoteId,
            productId: '11',
            productName: 'דבק פיקס — לבן',
            requestedQuantity: 220,
            unitPrice: 42,
            totalItemPrice: 9240,
            requestItemId: catalogLineId,
            variantId: 'v1',
            isExactMatch: true,
          ),
          SupplierQuoteItem(
            id: 'demo-qi-exact-manual',
            supplierQuoteId: exactQuoteId,
            productId: 'manual-demo-block',
            productName: 'בלוק 20',
            requestedQuantity: 480,
            unitPrice: 14,
            totalItemPrice: 6720,
            requestItemId: manualLineId,
          ),
        ],
      ),
      SupplierQuote(
        id: altQuoteId,
        quoteRequestId: compareRequestId,
        supplierId: MockStore.demoSupplierAlt.id,
        supplierName: MockStore.demoSupplierAlt.fullName,
        supplierType: MockStore.demoSupplierAlt.userType.value,
        deliveryTime: '4 ימי עסקים',
        totalPrice: 8360,
        subtotal: 8360,
        totalInclVat: 8360,
        status: SupplierQuoteStatus.sent,
        createdAt: compareCreated.add(const Duration(hours: 4)),
        items: const [
          SupplierQuoteItem(
            id: 'demo-qi-alt-catalog',
            supplierQuoteId: altQuoteId,
            productId: '11',
            productName: 'דבק דומה',
            requestedQuantity: 220,
            unitPrice: 38,
            totalItemPrice: 8360,
            requestItemId: catalogLineId,
            variantId: 'v1',
            quotedName: 'דבק Ultra Fix',
            quotedSku: 'UF-200',
            isAlternative: true,
            supplierNotes: 'חלופה מאושרת — זמינות מיידית',
          ),
        ],
      ),
      SupplierQuote(
        id: approvedQuoteId,
        quoteRequestId: fulfilledRequestId,
        supplierId: MockStore.demoSupplier.id,
        supplierName: MockStore.demoSupplier.fullName,
        supplierType: MockStore.demoSupplier.userType.value,
        deliveryTime: '3 ימי עסקים',
        totalPrice: 7680,
        subtotal: 7680,
        totalInclVat: 7680,
        status: SupplierQuoteStatus.shipped,
        createdAt: fulfilledCreated.add(const Duration(days: 1)),
        items: const [
          SupplierQuoteItem(
            id: 'demo-qi-approved',
            supplierQuoteId: approvedQuoteId,
            productId: '11',
            productName: 'דבק פיקס — לבן',
            requestedQuantity: 240,
            unitPrice: 32,
            totalItemPrice: 7680,
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
        status: QuoteRequestStatus.pendingReceipt,
        notes: '$projectSite — הזמנה מאושרת בדרך',
        createdAt: fulfilledCreated,
        updatedAt: now.subtract(const Duration(hours: 3)),
        shippedAt: now.subtract(const Duration(hours: 3)),
        shippedByUid: MockStore.demoSupplier.id,
        receiptStatus: ReceiptStatus.pendingReceipt,
        items: const [
          QuoteRequestItem(
            id: 'demo-fulfilled-catalog',
            quoteRequestId: fulfilledRequestId,
            productId: '11',
            productName: 'דבק פיקס — לבן',
            category: 'חיפוי',
            unitType: 'שק',
            quantity: 240,
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
            quantity: 300,
            isCatalogMatched: false,
          ),
        ],
        supplierIdsResponded: [MockStore.demoSupplier.id],
        approvedQuoteId: approvedQuoteId,
      ),
    );
  }
}
