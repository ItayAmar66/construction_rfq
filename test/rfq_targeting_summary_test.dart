import 'package:construction_rfq/models/quote_request_item.dart';
import 'package:construction_rfq/utils/supplier_targeting_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('customerTargetingSummary', () {
    test('open copy when no catalog categories or invites', () {
      const items = [
        QuoteRequestItem(
          id: 'm1',
          quoteRequestId: '',
          productId: 'p1',
          productName: 'Manual',
          category: 'כללי',
          unitType: 'יח',
          quantity: 1,
        ),
      ];

      final summary = SupplierTargetingHelpers.customerTargetingSummary(
        items: items,
      );

      expect(summary.mode, CustomerTargetingMode.open);
      expect(summary.title, 'פתוח לכל הספקים');
      expect(summary.detail, contains('כל הספקים'));
    });

    test('category match copy when catalog lines have categories', () {
      const items = [
        QuoteRequestItem(
          id: 'c1',
          quoteRequestId: '',
          productId: 'p1',
          productName: 'Catalog',
          category: 'חיפוי',
          unitType: 'שק',
          quantity: 2,
          categoryId: '7',
          isCatalogMatched: true,
        ),
      ];

      final summary = SupplierTargetingHelpers.customerTargetingSummary(
        items: items,
      );

      expect(summary.mode, CustomerTargetingMode.categoryMatch);
      expect(summary.title, 'מתאים לתחומי הקטלוג');
      expect(summary.detail, contains('קטגוריות'));
    });

    test('invited copy when invite list exists', () {
      const items = [
        QuoteRequestItem(
          id: 'c1',
          quoteRequestId: '',
          productId: 'p1',
          productName: 'Catalog',
          category: 'חיפוי',
          unitType: 'שק',
          quantity: 1,
          categoryId: '7',
          isCatalogMatched: true,
        ),
      ];

      final summary = SupplierTargetingHelpers.customerTargetingSummary(
        items: items,
        invitedSupplierIds: const ['sup-1', 'sup-2'],
      );

      expect(summary.mode, CustomerTargetingMode.invited);
      expect(summary.title, 'ספקים מוזמנים');
      expect(summary.detail, contains('2'));
    });

    test('invited copy shows supplier names when provided', () {
      const items = [
        QuoteRequestItem(
          id: 'm1',
          quoteRequestId: '',
          productId: 'p1',
          productName: 'Manual',
          category: 'כללי',
          unitType: 'יח',
          quantity: 1,
        ),
      ];

      final summary = SupplierTargetingHelpers.customerTargetingSummary(
        items: items,
        invitedSupplierNames: const ['ספק ענק QA A', 'ספק ענק QA B'],
      );

      expect(summary.mode, CustomerTargetingMode.invited);
      expect(summary.detail, contains('ספק ענק QA A'));
      expect(summary.supplierNames, hasLength(2));
    });
  });
}
