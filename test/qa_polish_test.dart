import 'package:construction_rfq/models/quote_request.dart';
import 'package:construction_rfq/models/quote_status.dart';
import 'package:construction_rfq/models/request_type.dart';
import 'package:construction_rfq/utils/hebrew_strings.dart';
import 'package:construction_rfq/utils/supplier_quote_status.dart';
import 'package:construction_rfq/widgets/quote_status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

QuoteRequest _closedTender() {
  return QuoteRequest(
    id: 't1',
    customerId: 'c1',
    customerName: 'קבלן',
    customerPhone: '050',
    customerCity: 'תל אביב',
    customerType: 'commercialCustomer',
    status: QuoteRequestStatus.sent,
    createdAt: DateTime(2026, 1, 1),
    requestType: RequestType.tender,
    tenderClosed: true,
  );
}

void main() {
  test('catalog cart label uses סל', () {
    expect(HebrewStrings.catalogCartLabel, 'סל');
    expect(HebrewStrings.catalogCartWithCount(2), 'סל (2)');
  });

  test('supplier quote display labels', () {
    expect(
      SupplierQuoteStatus.displayLabel(SupplierQuoteStatus.sent),
      'ממתין להחלטת לקוח',
    );
    expect(
      SupplierQuoteStatus.displayLabel(SupplierQuoteStatus.approved),
      'זכית',
    );
    expect(
      SupplierQuoteStatus.displayLabel(SupplierQuoteStatus.notSelected),
      'לא נבחר',
    );
    expect(
      SupplierQuoteStatus.displayLabel(SupplierQuoteStatus.shipped),
      'נשלח/סופק',
    );
  });

  testWidgets('quote status badge shows display label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: QuoteStatusBadge(status: SupplierQuoteStatus.sent),
        ),
      ),
    );
    expect(find.text('ממתין להחלטת לקוח'), findsOneWidget);
  });

  test('closed tender is not active', () {
    expect(_closedTender().isTenderActive, isFalse);
  });
}
