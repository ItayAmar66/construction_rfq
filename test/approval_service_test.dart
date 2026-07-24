import 'package:construction_rfq/models/quote_request.dart';
import 'package:construction_rfq/models/quote_status.dart';
import 'package:construction_rfq/models/supplier_quote.dart';
import 'package:construction_rfq/models/supplier_quote_item.dart';
import 'package:construction_rfq/services/approval_service.dart';
import 'package:construction_rfq/utils/supplier_quote_status.dart';
import 'package:flutter_test/flutter_test.dart';

QuoteRequest _request({
  String? approvedQuoteId,
  QuoteRequestStatus status = QuoteRequestStatus.quotesReceived,
}) {
  return QuoteRequest(
    id: 'req',
    customerId: 'c1',
    customerName: 'C',
    customerPhone: '050',
    customerCity: 'TLV',
    customerType: 'commercial',
    status: status,
    createdAt: DateTime(2024),
    approvedQuoteId: approvedQuoteId,
  );
}

SupplierQuote _quote({
  String status = SupplierQuoteStatus.sent,
  String id = 'q1',
  String quoteRequestId = 'req',
}) {
  return SupplierQuote(
    id: id,
    quoteRequestId: quoteRequestId,
    supplierId: 's1',
    supplierName: 'S',
    supplierType: 'commercial',
    deliveryTime: '2d',
    totalPrice: 10,
    status: status,
    createdAt: DateTime(2024),
    items: const [],
  );
}

// The request's customer is 'c1'; with no org/memberships, canApprove falls
// back to customerId == actorUid, so 'c1' is the authorized actor.
const _authorized = 'c1';

void main() {
  group('validateApproval', () {
    test('rejects an unauthorized actor', () {
      expect(
        () => ApprovalService.validateApproval(
          request: _request(),
          quote: _quote(),
          actorUid: 'other',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('accepts the happy path for the authorized customer', () {
      expect(
        () => ApprovalService.validateApproval(
          request: _request(),
          quote: _quote(),
          actorUid: _authorized,
        ),
        returnsNormally,
      );
    });

    test('rejects when a different quote was already approved', () {
      // Double-order guard: another quote is already the approved one.
      expect(
        () => ApprovalService.validateApproval(
          request: _request(approvedQuoteId: 'other-quote'),
          quote: _quote(id: 'q1'),
          actorUid: _authorized,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('rejects a quote that belongs to another request', () {
      expect(
        () => ApprovalService.validateApproval(
          request: _request(),
          quote: _quote(quoteRequestId: 'different-request'),
          actorUid: _authorized,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('rejects approval when the request is in a locked status', () {
      expect(
        () => ApprovalService.validateApproval(
          request: _request(status: QuoteRequestStatus.shipped),
          quote: _quote(),
          actorUid: _authorized,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('allows idempotent re-approval of the already-ordered quote', () {
      // ordered + approvedQuoteId == quote.id is the carve-out to the lock.
      expect(
        () => ApprovalService.validateApproval(
          request: _request(
            status: QuoteRequestStatus.ordered,
            approvedQuoteId: 'q1',
          ),
          quote: _quote(id: 'q1', status: SupplierQuoteStatus.approved),
          actorUid: _authorized,
        ),
        returnsNormally,
      );
    });

    test('rejects approving a quote in a non-approvable status', () {
      expect(
        () => ApprovalService.validateApproval(
          request: _request(),
          quote: _quote(status: SupplierQuoteStatus.outdated),
          actorUid: _authorized,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('validateRejection', () {
    test('accepts the happy path for the authorized customer', () {
      expect(
        () => ApprovalService.validateRejection(
          request: _request(),
          quote: _quote(),
          actorUid: _authorized,
        ),
        returnsNormally,
      );
    });

    test('rejects an unauthorized actor', () {
      expect(
        () => ApprovalService.validateRejection(
          request: _request(),
          quote: _quote(),
          actorUid: 'other',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('cannot reject once a quote has been approved', () {
      // Guards the reject-after-approve race that would undo an order.
      expect(
        () => ApprovalService.validateRejection(
          request: _request(approvedQuoteId: 'q1'),
          quote: _quote(id: 'q1'),
          actorUid: _authorized,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('cannot reject when the request is locked or closed', () {
      expect(
        () => ApprovalService.validateRejection(
          request: _request(status: QuoteRequestStatus.shipped),
          quote: _quote(),
          actorUid: _authorized,
        ),
        throwsA(isA<Exception>()),
      );
      expect(
        () => ApprovalService.validateRejection(
          request: _request(status: QuoteRequestStatus.closed),
          quote: _quote(),
          actorUid: _authorized,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('rejects a quote that belongs to another request', () {
      expect(
        () => ApprovalService.validateRejection(
          request: _request(),
          quote: _quote(quoteRequestId: 'different-request'),
          actorUid: _authorized,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('cannot reject a quote that is not in the sent status', () {
      expect(
        () => ApprovalService.validateRejection(
          request: _request(),
          quote: _quote(status: SupplierQuoteStatus.approved),
          actorUid: _authorized,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  test('alternative warning when quote has alternatives', () {
    const items = [
      SupplierQuoteItem(
        id: 'i1',
        supplierQuoteId: 'q1',
        productId: 'p1',
        productName: 'Alt',
        requestedQuantity: 1,
        unitPrice: 1,
        totalItemPrice: 1,
        isAlternative: true,
      ),
    ];
    expect(ApprovalService.hasAlternativeLines(items), isTrue);
    expect(ApprovalService.alternativeWarningMessage(items), contains('חלופ'));
  });
}
