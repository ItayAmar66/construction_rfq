import 'package:construction_rfq/models/quote_request_item.dart';
import 'package:construction_rfq/models/supplier_quote_item.dart';
import 'package:construction_rfq/utils/hebrew_strings.dart';
import 'package:construction_rfq/utils/supplier_catalog_match_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Supplier quote regression', () {
    test('exact match item passes validation', () {
      final err = SupplierCatalogMatchValidation.missingAlternativeNote(
        item: const QuoteRequestItem(
          id: 'l1',
          quoteRequestId: '',
          productId: 'p1',
          productName: 'דבק',
          category: 'c',
          unitType: 'שק',
          quantity: 1,
          isCatalogMatched: true,
        ),
        isExactMatch: true,
        includeInQuote: true,
        unitPrice: 10,
        supplierNotes: '',
      );
      expect(err, isNull);
    });

    test('alternative without note fails validation', () {
      final err = SupplierCatalogMatchValidation.missingAlternativeNote(
        item: const QuoteRequestItem(
          id: 'l1',
          quoteRequestId: '',
          productId: 'p1',
          productName: 'דבק',
          category: 'c',
          unitType: 'שק',
          quantity: 1,
          isCatalogMatched: true,
        ),
        isExactMatch: false,
        includeInQuote: true,
        unitPrice: 10,
        supplierNotes: '',
      );
      expect(err, isNotNull);
    });

    test('alternative warning copy present for customer', () {
      expect(
        HebrewStrings.alternativeApprovalWarning(2),
        contains('חלופות'),
      );
    });

    test('supplier quote item embeds match flags', () {
      const item = SupplierQuoteItem(
        id: 'qi1',
        supplierQuoteId: 'q1',
        productId: 'p1',
        productName: 'דבק',
        requestedQuantity: 1,
        unitPrice: 10,
        totalItemPrice: 10,
        isExactMatch: false,
        isAlternative: true,
        quotedName: 'חלופה',
      );
      final map = item.toEmbeddedMap();
      expect(map['isAlternative'], isTrue);
      expect(map['isExactMatch'], isFalse);
    });
  });
}
