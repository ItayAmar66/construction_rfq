import 'package:construction_rfq/models/quote_request_item.dart';
import 'package:construction_rfq/models/supplier_quote.dart';
import 'package:construction_rfq/models/supplier_quote_item.dart';
import 'package:construction_rfq/utils/quote_comparison_matrix.dart';
import 'package:construction_rfq/utils/supplier_quote_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildQuoteComparisonMatrix', () {
    const requestItems = [
      QuoteRequestItem(
        id: 'r1',
        quoteRequestId: 'req',
        productId: 'p1',
        productName: 'Catalog line',
        category: 'c',
        unitType: 'u',
        quantity: 2,
        isCatalogMatched: true,
      ),
      QuoteRequestItem(
        id: 'r2',
        quoteRequestId: 'req',
        productId: 'p2',
        productName: 'Manual line',
        category: 'c',
        unitType: 'u',
        quantity: 1,
      ),
    ];

    final quotes = [
      SupplierQuote(
        id: 'q1',
        quoteRequestId: 'req',
        supplierId: 's1',
        supplierName: 'Supplier A',
        supplierType: 'commercial',
        deliveryTime: '3d',
        totalPrice: 30,
        status: SupplierQuoteStatus.sent,
        createdAt: DateTime(2024),
        items: const [
          SupplierQuoteItem(
            id: 'qi1',
            supplierQuoteId: 'q1',
            productId: 'p1',
            productName: 'Catalog line',
            requestedQuantity: 2,
            unitPrice: 10,
            totalItemPrice: 20,
            requestItemId: 'r1',
            isExactMatch: true,
          ),
          SupplierQuoteItem(
            id: 'qi2',
            supplierQuoteId: 'q1',
            productId: 'p2',
            productName: 'Manual line',
            requestedQuantity: 1,
            unitPrice: 10,
            totalItemPrice: 10,
            requestItemId: 'r2',
          ),
        ],
      ),
      SupplierQuote(
        id: 'q2',
        quoteRequestId: 'req',
        supplierId: 's2',
        supplierName: 'Supplier B',
        supplierType: 'commercial',
        deliveryTime: '5d',
        totalPrice: 18,
        status: SupplierQuoteStatus.sent,
        createdAt: DateTime(2024),
        items: const [
          SupplierQuoteItem(
            id: 'qi3',
            supplierQuoteId: 'q2',
            productId: 'p1',
            productName: 'Alt',
            requestedQuantity: 2,
            unitPrice: 9,
            totalItemPrice: 18,
            requestItemId: 'r1',
            isAlternative: true,
          ),
        ],
      ),
    ];

    test('builds rows and columns from request and quotes', () {
      final matrix = buildQuoteComparisonMatrix(
        requestItems: requestItems,
        quotes: quotes,
      );

      expect(matrix.rowCount, 2);
      expect(matrix.columnCount, 2);
      expect(
        matrix.cells['q1']!['r1']!.status,
        QuoteMatrixCellStatus.exact,
      );
      expect(
        matrix.cells['q2']!['r1']!.status,
        QuoteMatrixCellStatus.alternative,
      );
      expect(
        matrix.cells['q2']!['r2']!.status,
        QuoteMatrixCellStatus.missing,
      );
    });
  });
}
