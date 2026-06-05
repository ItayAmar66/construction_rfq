import 'package:construction_rfq/models/quote_request.dart';
import 'package:construction_rfq/models/quote_request_item.dart';
import 'package:construction_rfq/models/quote_status.dart';
import 'package:construction_rfq/models/supplier_quote.dart';
import 'package:construction_rfq/models/supplier_quote_item.dart';
import 'package:construction_rfq/utils/quote_comparison_matrix.dart';
import 'package:construction_rfq/utils/supplier_quote_status.dart';
import 'package:construction_rfq/widgets/catalog/quote_comparison_matrix.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('matrix renders row headers and cell status', (tester) async {
    const requestItems = [
      QuoteRequestItem(
        id: 'r1',
        quoteRequestId: 'req',
        productId: 'p1',
        productName: 'Catalog line',
        category: 'c',
        unitType: 'u',
        quantity: 1,
        isCatalogMatched: true,
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
        totalPrice: 10,
        status: SupplierQuoteStatus.sent,
        createdAt: DateTime(2024),
        items: const [
          SupplierQuoteItem(
            id: 'qi1',
            supplierQuoteId: 'q1',
            productId: 'p1',
            productName: 'Catalog line',
            requestedQuantity: 1,
            unitPrice: 10,
            totalItemPrice: 10,
            requestItemId: 'r1',
            isExactMatch: true,
          ),
        ],
      ),
    ];

    final data = buildQuoteComparisonMatrix(
      requestItems: requestItems,
      quotes: quotes,
    );

    final request = QuoteRequest(
      id: 'req',
      customerId: 'c1',
      customerName: 'Customer',
      customerPhone: '050',
      customerCity: 'TLV',
      customerType: 'commercial',
      status: QuoteRequestStatus.sent,
      createdAt: DateTime(2024),
      items: requestItems,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuoteComparisonMatrix(data: data, request: request),
        ),
      ),
    );

    expect(find.text('מטריצת השוואה'), findsOneWidget);
    expect(find.text('Catalog line'), findsOneWidget);
    expect(find.text('מדויק'), findsOneWidget);
    expect(find.text('סה״כ'), findsOneWidget);
    expect(find.text('התאמות'), findsOneWidget);
    expect(find.text('הנמוך ביותר'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
  });
}
