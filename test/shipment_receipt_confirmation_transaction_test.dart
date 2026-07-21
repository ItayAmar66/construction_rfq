import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/models/app_user.dart';
import 'package:construction_rfq/models/quote_request.dart';
import 'package:construction_rfq/models/quote_request_item.dart';
import 'package:construction_rfq/models/quote_status.dart';
import 'package:construction_rfq/models/receipt_checklist_item.dart';
import 'package:construction_rfq/models/receipt_status.dart';
import 'package:construction_rfq/models/user_type.dart';
import 'package:construction_rfq/services/quote_service.dart';
import 'package:construction_rfq/utils/constants.dart';
import 'package:construction_rfq/utils/shipment_receipt_helpers.dart';
import 'package:construction_rfq/utils/shipment_receipt_validation.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// Real (non-demo) confirmShipmentReceipt flow against a fake Firestore —
/// exercises the transactional/idempotent write path that MockStore-backed
/// demo-mode tests (test/shipment_receipt_confirmation_test.dart) never hit.
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

  QuoteRequestItem line(String id, {int qty = 2}) => QuoteRequestItem(
        id: id,
        quoteRequestId: '',
        productId: 'p_$id',
        productName: 'Product $id',
        category: 'Cat',
        unitType: 'יחידה',
        quantity: qty,
      );

  Future<({QuoteService service, String requestId, FakeFirebaseFirestore firestore})>
      seedPendingReceipt() async {
    final firestore = FakeFirebaseFirestore();
    final service = QuoteService(firestore: firestore);

    final requestId = await service.submitQuoteRequest(
      customer: customer,
      requestItems: [line('a'), line('b')],
      submitStatus: QuoteRequestStatus.sent,
    );
    final quoteId = await service.submitSupplierQuote(
      supplier: supplier,
      quoteRequestId: requestId,
      deliveryTime: '2 ימים',
      lines: [
        SupplierQuoteLineInput(
          productId: 'p_a',
          productName: 'Product a',
          requestedQuantity: 2,
          unitPrice: 10,
          totalItemPrice: 20,
        ),
        SupplierQuoteLineInput(
          productId: 'p_b',
          productName: 'Product b',
          requestedQuantity: 2,
          unitPrice: 10,
          totalItemPrice: 20,
        ),
      ],
    );
    await service.approveCustomerQuote(
      quoteId: quoteId,
      requestId: requestId,
      actorUid: customer.id,
    );
    await service.markSupplierOrderShipped(
      quoteId: quoteId,
      requestId: requestId,
      supplierId: supplier.id,
    );
    return (service: service, requestId: requestId, firestore: firestore);
  }

  test('authorized confirmation persists the checklist and final status', () async {
    final seeded = await seedPendingReceipt();
    final requestDoc = await seeded.firestore
        .collection(AppConstants.quoteRequestsCollection)
        .doc(seeded.requestId)
        .get();
    final checklist = ShipmentReceiptHelpers.initialChecklistFromRequest(
      QuoteRequest.fromMap(requestDoc.id, requestDoc.data()!),
    );

    await seeded.service.confirmShipmentReceipt(
      requestId: seeded.requestId,
      actorUid: customer.id,
      checklist: checklist,
      fullReceipt: true,
    );

    final updated = await seeded.firestore
        .collection(AppConstants.quoteRequestsCollection)
        .doc(seeded.requestId)
        .get();
    expect(updated.data()!['receiptStatus'], ReceiptStatus.receivedFull.firestoreValue);
    expect(updated.data()!['status'], QuoteRequestStatus.receivedFull.firestoreValue);
  });

  test('duplicate confirmation is rejected with a distinct exception', () async {
    final seeded = await seedPendingReceipt();
    final requestDoc = await seeded.firestore
        .collection(AppConstants.quoteRequestsCollection)
        .doc(seeded.requestId)
        .get();
    final checklist = ShipmentReceiptHelpers.initialChecklistFromRequest(
      QuoteRequest.fromMap(requestDoc.id, requestDoc.data()!),
    );

    await seeded.service.confirmShipmentReceipt(
      requestId: seeded.requestId,
      actorUid: customer.id,
      checklist: checklist,
      fullReceipt: true,
    );

    expect(
      () => seeded.service.confirmShipmentReceipt(
        requestId: seeded.requestId,
        actorUid: customer.id,
        checklist: checklist,
        fullReceipt: true,
      ),
      throwsA(isA<ShipmentReceiptAlreadyConfirmedException>()),
    );
  });

  // fake_cloud_firestore's runTransaction is a _DummyTransaction — it runs
  // the handler once with no read-conflict detection or retry, so it can't
  // exercise genuine two-tab contention (both calls would just "succeed"
  // against the fake regardless of transaction correctness). The real
  // contention behavior — second writer's re-read observes the first
  // writer's already-final status and is rejected — is instead verified
  // against the actual Firestore emulator in
  // test/firestore/medium_data_integrity_fixes.emulator.test.js ("exactly
  // one of two concurrent receipt confirmations succeeds"). What's
  // verified here is the sequential case the transaction body itself is
  // responsible for: a second confirmation attempt after the first has
  // already landed sees the fresh (post-write) state and is rejected —
  // see 'duplicate confirmation is rejected with a distinct exception'.
}
