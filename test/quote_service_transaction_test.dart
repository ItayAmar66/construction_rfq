import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/models/app_user.dart';
import 'package:construction_rfq/models/quote_request_item.dart';
import 'package:construction_rfq/models/quote_status.dart';
import 'package:construction_rfq/models/request_type.dart';
import 'package:construction_rfq/models/user_type.dart';
import 'package:construction_rfq/services/quote_service.dart';
import 'package:construction_rfq/utils/constants.dart';
import 'package:construction_rfq/utils/supplier_quote_doc_id.dart';
import 'package:construction_rfq/utils/supplier_quote_status.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// Real (non-demo) QuoteService flows against a fake Firestore.
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

  group('approveCustomerQuote', () {
    test('places the order atomically: quote approved, request ordered', () async {
      final firestore = FakeFirebaseFirestore();
      final service = QuoteService(firestore: firestore);

      final requestId = await service.submitQuoteRequest(
        customer: customer,
        requestItems: [line('a')],
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
        ],
      );

      await service.approveCustomerQuote(
        quoteId: quoteId,
        requestId: requestId,
        actorUid: customer.id,
      );

      final requestDoc = await firestore
          .collection(AppConstants.quoteRequestsCollection)
          .doc(requestId)
          .get();
      expect(requestDoc.data()!['status'], QuoteRequestStatus.ordered.firestoreValue);
      expect(requestDoc.data()!['approvedQuoteId'], quoteId);

      final quoteDoc = await firestore
          .collection(AppConstants.supplierQuotesCollection)
          .doc(quoteId)
          .get();
      expect(quoteDoc.data()!['status'], SupplierQuoteStatus.approved);
    });

    test('an unauthorized approver still fails (order not placed)', () async {
      final firestore = FakeFirebaseFirestore();
      final service = QuoteService(firestore: firestore);

      final requestId = await service.submitQuoteRequest(
        customer: customer,
        requestItems: [line('a')],
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
        ],
      );

      await expectLater(
        service.approveCustomerQuote(
          quoteId: quoteId,
          requestId: requestId,
          actorUid: 'someone-else',
        ),
        throwsA(isA<Exception>()),
      );

      final requestDoc = await firestore
          .collection(AppConstants.quoteRequestsCollection)
          .doc(requestId)
          .get();
      expect(requestDoc.data()!['status'], isNot(QuoteRequestStatus.ordered.firestoreValue),
          reason: 'a rejected approval must not place the order');
    });
  });

  group('submitTenderCounterBid', () {
    test('resubmitting a tender bid creates a new version and outdates the prior one',
        () async {
      final firestore = FakeFirebaseFirestore();
      final service = QuoteService(firestore: firestore);

      final requestId = await service.submitQuoteRequest(
        customer: customer,
        requestItems: [line('a')],
        requestType: RequestType.tender,
        submitStatus: QuoteRequestStatus.sent,
      );

      Future<String> bid(double unitPrice) => service.submitTenderCounterBid(
            supplier: supplier,
            quoteRequestId: requestId,
            deliveryTime: '3 ימים',
            supplierOrgId: 'supplier-org-1',
            lines: [
              SupplierQuoteLineInput(
                productId: 'p_a',
                productName: 'Product a',
                requestedQuantity: 2,
                unitPrice: unitPrice,
                totalItemPrice: unitPrice * 2,
              ),
            ],
          );

      final firstQuoteId = await bid(100);
      final expectedFirstId = SupplierQuoteDocId.forTenderBid(
        quoteRequestId: requestId,
        supplierId: supplier.id,
        supplierOrgId: 'supplier-org-1',
        bidVersion: 1,
      );
      expect(firstQuoteId, expectedFirstId);

      final secondQuoteId = await bid(90);
      final expectedSecondId = SupplierQuoteDocId.forTenderBid(
        quoteRequestId: requestId,
        supplierId: supplier.id,
        supplierOrgId: 'supplier-org-1',
        bidVersion: 2,
      );
      expect(secondQuoteId, expectedSecondId);
      expect(secondQuoteId, isNot(firstQuoteId));

      final firstDoc = await firestore
          .collection(AppConstants.supplierQuotesCollection)
          .doc(firstQuoteId)
          .get();
      expect(firstDoc.data()!['status'], SupplierQuoteStatus.outdated,
          reason: 'the superseded version must be marked outdated');

      final secondDoc = await firestore
          .collection(AppConstants.supplierQuotesCollection)
          .doc(secondQuoteId)
          .get();
      expect(secondDoc.data()!['status'], SupplierQuoteStatus.sent);
      expect(secondDoc.data()!['bidVersion'], 2);

      final allBids = await firestore
          .collection(AppConstants.supplierQuotesCollection)
          .where('requestId', isEqualTo: requestId)
          .get();
      expect(allBids.docs.length, 2,
          reason: 'bid history is preserved, not overwritten in place');

      final requestDoc = await firestore
          .collection(AppConstants.quoteRequestsCollection)
          .doc(requestId)
          .get();
      // 90 * 2 units, +17% VAT.
      expect(requestDoc.data()!['lowestBid'], closeTo(210.6, 0.001));
    });
  });
}
