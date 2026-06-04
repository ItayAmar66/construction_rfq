import 'package:construction_rfq/models/catalog/catalog_rfq_line_draft.dart';
import 'package:construction_rfq/models/quote_request_item.dart';
import 'package:construction_rfq/models/supplier_quote_item.dart';
import 'package:construction_rfq/utils/hebrew_strings.dart';
import 'package:construction_rfq/widgets/catalog/customer_quote_line_match_card.dart';
import 'package:construction_rfq/widgets/catalog/quote_match_summary_chips.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

QuoteRequestItem _catalogRequestLine() {
  return QuoteRequestItem.fromCatalogDraft(
    const CatalogRfqLineDraft(
      variantId: 'v1',
      productId: '11',
      categoryId: '7',
      categoryPath: 'דבקים › חיפוי',
      displayName: 'דבק פיקס — לבן',
      sku: 'FX-1',
      unitType: 'שק',
      quantity: 2,
    ),
    lineId: 'req-line-catalog',
  );
}

QuoteRequestItem _manualRequestLine() {
  return const QuoteRequestItem(
    id: 'req-line-manual',
    quoteRequestId: '',
    productId: 'manual-1',
    productName: 'בלוק 20',
    category: 'בלוקים',
    unitType: 'יחידה',
    quantity: 3,
    isCatalogMatched: false,
  );
}

SupplierQuoteItem _exactQuoteItem() {
  return const SupplierQuoteItem(
    id: 'qi-exact',
    supplierQuoteId: 'q-1',
    productId: '11',
    productName: 'דבק פיקס — לבן',
    requestedQuantity: 2,
    unitPrice: 10,
    totalItemPrice: 20,
    requestItemId: 'req-line-catalog',
    variantId: 'v1',
    quotedName: 'דבק פיקס — לבן',
    quotedSku: 'FX-1',
    isExactMatch: true,
  );
}

SupplierQuoteItem _alternativeQuoteItem() {
  return const SupplierQuoteItem(
    id: 'qi-alt',
    supplierQuoteId: 'q-1',
    productId: '11',
    productName: 'דבק דומה',
    requestedQuantity: 2,
    unitPrice: 9,
    totalItemPrice: 18,
    requestItemId: 'req-line-catalog',
    quotedName: 'דבק דומה',
    quotedSku: 'SUB-1',
    isAlternative: true,
    supplierNotes: 'מלאי מוגבל',
  );
}

SupplierQuoteItem _manualQuoteItem() {
  return const SupplierQuoteItem(
    id: 'qi-manual',
    supplierQuoteId: 'q-1',
    productId: 'manual-1',
    productName: 'בלוק 20',
    requestedQuantity: 3,
    unitPrice: 5,
    totalItemPrice: 15,
    requestItemId: 'req-line-manual',
  );
}

void main() {
  group('Supplier quote catalog context widgets', () {
    testWidgets('compact line shows exact match badge', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomerQuoteLineMatchCard(
              quoteItem: _exactQuoteItem(),
              requestLine: _catalogRequestLine(),
              compact: true,
            ),
          ),
        ),
      );

      expect(find.text(HebrewStrings.exactMatchBadge), findsOneWidget);
      expect(find.textContaining('FX-1'), findsOneWidget);
    });

    testWidgets('compact line shows alternative badge and notes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomerQuoteLineMatchCard(
              quoteItem: _alternativeQuoteItem(),
              requestLine: _catalogRequestLine(),
              compact: true,
            ),
          ),
        ),
      );

      expect(find.text(HebrewStrings.alternativeMatchBadge), findsOneWidget);
      expect(find.textContaining('מלאי מוגבל'), findsOneWidget);
    });

    testWidgets('manual line has no catalog badges', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomerQuoteLineMatchCard(
              quoteItem: _manualQuoteItem(),
              requestLine: _manualRequestLine(),
              compact: true,
            ),
          ),
        ),
      );

      expect(find.text('בלוק 20'), findsOneWidget);
      expect(find.text(HebrewStrings.exactMatchBadge), findsNothing);
      expect(find.text(HebrewStrings.alternativeMatchBadge), findsNothing);
      expect(find.text(HebrewStrings.catalogMatchedBadge), findsNothing);
    });

    testWidgets('summary chips show exact and alternative counts', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuoteMatchSummaryChips(
              items: [
                _exactQuoteItem(),
                _alternativeQuoteItem(),
                _manualQuoteItem(),
              ],
              requestItems: [_catalogRequestLine(), _manualRequestLine()],
            ),
          ),
        ),
      );

      expect(find.text(HebrewStrings.exactMatchBadge), findsOneWidget);
      expect(find.text(HebrewStrings.alternativeMatchBadge), findsOneWidget);
      expect(find.textContaining('ידני'), findsOneWidget);
    });
  });
}
