import 'package:construction_rfq/models/quote_status.dart';
import 'package:construction_rfq/utils/hebrew_strings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pending approval status label', () {
    expect(
      QuoteRequestStatus.pendingApproval.firestoreValue,
      'ממתין לאישור רכש',
    );
    expect(
      QuoteRequestStatusExtension.fromFirestore('ממתין לאישור רכש'),
      QuoteRequestStatus.pendingApproval,
    );
  });

  test('procurement approval button label', () {
    expect(HebrewStrings.submitForProcurementApproval, 'שלח לאישור רכש');
    expect(HebrewStrings.submitRequest, 'שליחה לספקים');
  });
}
