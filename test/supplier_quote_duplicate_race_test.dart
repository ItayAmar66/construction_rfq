import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/models/app_user.dart';
import 'package:construction_rfq/models/quote_request_item.dart';
import 'package:construction_rfq/models/quote_status.dart';
import 'package:construction_rfq/models/user_type.dart';
import 'package:construction_rfq/services/quote_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression coverage for the "duplicate quote race" workflow bug: a
/// second submission for the same supplier/request must always surface the
/// same friendly "already submitted" business message — whether it's
/// rejected by the pre-check (this fake has no security-rule simulation, so
/// that's the path exercised here) or, in real Firestore, by the
/// server-side duplicate-create rule after a genuine concurrent race (see
/// SupplierQuoteRepository.submitSupplierQuote's permission-denied catch).
void main() {
  setUp(() => AppMode.isDemoMode = false);

  final customer = AppUser(
    id: 'customer-1',
    fullName: 'לקוח פרטי',
    email: 'customer@test.com',
    phone: '050',
    userType: UserType.privateCustomer,
    city: 'תל אביב',
    createdAt: DateTime(2026),
  );

  final supplier = AppUser(
    id: 'supplier-1',
    fullName: 'ספק',
    email: 'supplier@test.com',
    phone: '050',
    userType: UserType.commercialSupplier,
    city: 'חיפה',
    createdAt: DateTime(2026),
  );

  test('a second submission for the same supplier/request gets the friendly message',
      () async {
    final firestore = FakeFirebaseFirestore();
    final service = QuoteService(firestore: firestore);

    final requestId = await service.submitQuoteRequest(
      customer: customer,
      requestItems: [
        QuoteRequestItem(
          id: 'a',
          quoteRequestId: '',
          productId: 'p_a',
          productName: 'Product a',
          category: 'Cat',
          unitType: 'יחידה',
          quantity: 2,
        ),
      ],
      submitStatus: QuoteRequestStatus.sent,
    );

    final line = SupplierQuoteLineInput(
      productId: 'p_a',
      productName: 'Product a',
      requestedQuantity: 2,
      unitPrice: 10,
      totalItemPrice: 20,
    );

    await service.submitSupplierQuote(
      supplier: supplier,
      quoteRequestId: requestId,
      deliveryTime: '2 ימים',
      lines: [line],
      supplierOrgId: 'supplier-org-1',
    );

    await expectLater(
      service.submitSupplierQuote(
        supplier: supplier,
        quoteRequestId: requestId,
        deliveryTime: '2 ימים',
        lines: [line],
        supplierOrgId: 'supplier-org-1',
      ),
      throwsA(
        predicate((e) => e.toString().contains('כבר נשלחה הצעה מטעם הספק הזה')),
      ),
    );
  });
}
