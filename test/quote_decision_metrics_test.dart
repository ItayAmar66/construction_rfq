import 'package:construction_rfq/models/quote_request_item.dart';
import 'package:construction_rfq/models/supplier_quote_item.dart';
import 'package:construction_rfq/utils/quote_decision_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('computeQuoteDecisionMetrics', () {
    test('counts exact, alternative, and manual lines', () {
      const requestItems = [
        QuoteRequestItem(
          id: 'r1',
          quoteRequestId: '',
          productId: 'p1',
          productName: 'Catalog',
          category: 'c',
          unitType: 'u',
          quantity: 1,
          isCatalogMatched: true,
        ),
        QuoteRequestItem(
          id: 'r2',
          quoteRequestId: '',
          productId: 'p2',
          productName: 'Manual',
          category: 'c',
          unitType: 'u',
          quantity: 1,
        ),
      ];

      const quoteItems = [
        SupplierQuoteItem(
          id: 'q1',
          supplierQuoteId: 'sq',
          productId: 'p1',
          productName: 'Catalog',
          requestedQuantity: 1,
          unitPrice: 10,
          totalItemPrice: 10,
          requestItemId: 'r1',
          isExactMatch: true,
        ),
        SupplierQuoteItem(
          id: 'q2',
          supplierQuoteId: 'sq',
          productId: 'p2',
          productName: 'Manual',
          requestedQuantity: 1,
          unitPrice: 5,
          totalItemPrice: 5,
          requestItemId: 'r2',
        ),
      ];

      final metrics = computeQuoteDecisionMetrics(
        quoteItems: quoteItems,
        requestItems: requestItems,
        totalPrice: 15,
      );

      expect(metrics.exactCount, 1);
      expect(metrics.manualCount, 1);
      expect(metrics.totalPrice, 15);
    });
  });
}
