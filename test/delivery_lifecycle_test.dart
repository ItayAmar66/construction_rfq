import 'package:construction_rfq/models/delivery.dart';
import 'package:construction_rfq/models/quote_request.dart';
import 'package:construction_rfq/models/quote_status.dart';
import 'package:construction_rfq/models/receipt_status.dart';
import 'package:construction_rfq/providers/delivery_providers.dart';
import 'package:flutter_test/flutter_test.dart';

// Dates chosen far from any plausible "now" so the DateTime.now()-based
// branches (delayed / overdue) are deterministic regardless of the wall clock.
final _farPast = DateTime(2000, 1, 1);
final _farFuture = DateTime(2999, 1, 1);

QuoteRequest _req({
  required QuoteRequestStatus status,
  ReceiptStatus? receiptStatus,
  DateTime? shippedAt,
  DateTime? expectedDeliveryDate,
  DateTime? receivedAt,
}) {
  return QuoteRequest(
    id: 'r1',
    customerId: 'c1',
    customerName: 'קבלן',
    customerPhone: '050',
    customerCity: 'תל אביב',
    customerType: 'commercial',
    status: status,
    createdAt: DateTime(2024, 1, 1),
    receiptStatus: receiptStatus,
    shippedAt: shippedAt,
    expectedDeliveryDate: expectedDeliveryDate,
    receivedAt: receivedAt,
  );
}

Delivery _delivery(DeliveryStage stage) =>
    Delivery(request: _req(status: QuoteRequestStatus.ordered), stage: stage);

void main() {
  group('Delivery.stageFor', () {
    test('receiptStatus takes precedence over order status', () {
      expect(
        Delivery.stageFor(_req(
          status: QuoteRequestStatus.shipped,
          receiptStatus: ReceiptStatus.receivedFull,
        )),
        DeliveryStage.delivered,
      );
      expect(
        Delivery.stageFor(_req(
          status: QuoteRequestStatus.shipped,
          receiptStatus: ReceiptStatus.receivedWithIssues,
        )),
        DeliveryStage.deliveredWithIssues,
      );
    });

    test('maps received order statuses when no receiptStatus set', () {
      expect(
        Delivery.stageFor(_req(status: QuoteRequestStatus.receivedFull)),
        DeliveryStage.delivered,
      );
      expect(
        Delivery.stageFor(_req(status: QuoteRequestStatus.receivedWithIssues)),
        DeliveryStage.deliveredWithIssues,
      );
    });

    test('ordered but not shipped is awaitingShipment', () {
      expect(
        Delivery.stageFor(_req(status: QuoteRequestStatus.ordered)),
        DeliveryStage.awaitingShipment,
      );
    });

    test('shipped within its ETA window is inTransit', () {
      expect(
        Delivery.stageFor(_req(
          status: QuoteRequestStatus.shipped,
          expectedDeliveryDate: _farFuture,
        )),
        DeliveryStage.inTransit,
      );
    });

    test('shipped past its ETA without receipt is delayed', () {
      expect(
        Delivery.stageFor(_req(
          status: QuoteRequestStatus.shipped,
          expectedDeliveryDate: _farPast,
        )),
        DeliveryStage.delayed,
      );
    });

    test('a shippedAt timestamp alone puts an ordered request in transit', () {
      expect(
        Delivery.stageFor(_req(
          status: QuoteRequestStatus.ordered,
          shippedAt: DateTime(2024, 6, 1),
        )),
        DeliveryStage.inTransit,
      );
    });
  });

  group('DeliveryStageX', () {
    test('open vs closed partition', () {
      expect(DeliveryStage.awaitingShipment.isOpen, isTrue);
      expect(DeliveryStage.inTransit.isOpen, isTrue);
      expect(DeliveryStage.delayed.isOpen, isTrue);
      expect(DeliveryStage.delivered.isClosed, isTrue);
      expect(DeliveryStage.deliveredWithIssues.isClosed, isTrue);
    });

    test('needsAttention only for delayed and deliveredWithIssues', () {
      expect(DeliveryStage.delayed.needsAttention, isTrue);
      expect(DeliveryStage.deliveredWithIssues.needsAttention, isTrue);
      expect(DeliveryStage.inTransit.needsAttention, isFalse);
      expect(DeliveryStage.delivered.needsAttention, isFalse);
    });

    test('progress increases through the lifecycle', () {
      expect(DeliveryStage.awaitingShipment.progress, 0.2);
      expect(DeliveryStage.inTransit.progress, 0.6);
      expect(DeliveryStage.delayed.progress, 0.6);
      expect(DeliveryStage.delivered.progress, 1);
      expect(DeliveryStage.deliveredWithIssues.progress, 1);
    });
  });

  group('Delivery.daysToEta / isOverdue', () {
    test('is null when there is no ETA', () {
      final d = Delivery(
        request: _req(status: QuoteRequestStatus.shipped),
        stage: DeliveryStage.inTransit,
      );
      expect(d.daysToEta, isNull);
      expect(d.isOverdue, isFalse); // (null ?? 1) < 0 == false
    });

    test('is null once the delivery is closed even with an ETA', () {
      final d = Delivery(
        request: _req(
          status: QuoteRequestStatus.receivedFull,
          expectedDeliveryDate: _farPast,
        ),
        stage: DeliveryStage.delivered,
      );
      expect(d.daysToEta, isNull);
      expect(d.isOverdue, isFalse);
    });

    test('past ETA on an open delivery is overdue', () {
      final d = Delivery(
        request: _req(
          status: QuoteRequestStatus.shipped,
          expectedDeliveryDate: _farPast,
        ),
        stage: DeliveryStage.delayed,
      );
      expect(d.daysToEta, lessThan(0));
      expect(d.isOverdue, isTrue);
    });

    test('future ETA on an open delivery is not overdue', () {
      final d = Delivery(
        request: _req(
          status: QuoteRequestStatus.shipped,
          expectedDeliveryDate: _farFuture,
        ),
        stage: DeliveryStage.inTransit,
      );
      expect(d.daysToEta, greaterThan(0));
      expect(d.isOverdue, isFalse);
    });
  });

  group('Delivery.isDelivery', () {
    test('true for ordered/shipped/receipt statuses, false for earlier ones',
        () {
      expect(
        Delivery.isDelivery(_req(status: QuoteRequestStatus.ordered)),
        isTrue,
      );
      expect(
        Delivery.isDelivery(_req(status: QuoteRequestStatus.pendingReceipt)),
        isTrue,
      );
      expect(
        Delivery.isDelivery(_req(status: QuoteRequestStatus.quotesReceived)),
        isFalse,
      );
      expect(
        Delivery.isDelivery(_req(status: QuoteRequestStatus.draft)),
        isFalse,
      );
    });
  });

  group('summarizeDeliveries', () {
    test('classifies each stage into the right counters', () {
      final summary = summarizeDeliveries([
        _delivery(DeliveryStage.awaitingShipment),
        _delivery(DeliveryStage.inTransit),
        _delivery(DeliveryStage.delayed),
        _delivery(DeliveryStage.delivered),
        _delivery(DeliveryStage.deliveredWithIssues),
      ]);
      // active = awaiting + inTransit + delayed
      expect(summary.active, 3);
      expect(summary.awaitingShipment, 1);
      // delayed counts the delayed stage AND deliveredWithIssues
      expect(summary.delayed, 2);
      // delivered = delivered + deliveredWithIssues
      expect(summary.delivered, 2);
      expect(summary.attention, 2);
      expect(summary.total, summary.active + summary.delivered);
    });

    test('empty input yields all-zero summary', () {
      final summary = summarizeDeliveries(const []);
      expect(summary.active, 0);
      expect(summary.delayed, 0);
      expect(summary.awaitingShipment, 0);
      expect(summary.delivered, 0);
    });
  });

  group('compareDeliveries', () {
    test('ranks attention-worthy deliveries ahead of completed ones', () {
      final list = [
        _delivery(DeliveryStage.delivered),
        _delivery(DeliveryStage.inTransit),
        _delivery(DeliveryStage.delayed),
        _delivery(DeliveryStage.deliveredWithIssues),
        _delivery(DeliveryStage.awaitingShipment),
      ]..sort(compareDeliveries);
      expect(
        list.map((d) => d.stage).toList(),
        [
          DeliveryStage.delayed,
          DeliveryStage.deliveredWithIssues,
          DeliveryStage.awaitingShipment,
          DeliveryStage.inTransit,
          DeliveryStage.delivered,
        ],
      );
    });

    test('open deliveries sort by soonest expected arrival', () {
      final sooner = Delivery(
        request: _req(
          status: QuoteRequestStatus.shipped,
          expectedDeliveryDate: DateTime(2024, 3, 1),
        ),
        stage: DeliveryStage.inTransit,
      );
      final later = Delivery(
        request: _req(
          status: QuoteRequestStatus.shipped,
          expectedDeliveryDate: DateTime(2024, 9, 1),
        ),
        stage: DeliveryStage.inTransit,
      );
      final list = [later, sooner]..sort(compareDeliveries);
      expect(list.first, same(sooner));
    });
  });

  group('DeliveryFilterX.matches', () {
    test('all matches every stage', () {
      for (final stage in DeliveryStage.values) {
        expect(DeliveryFilter.all.matches(_delivery(stage)), isTrue);
      }
    });

    test('active matches only open stages', () {
      expect(
        DeliveryFilter.active.matches(_delivery(DeliveryStage.inTransit)),
        isTrue,
      );
      expect(
        DeliveryFilter.active.matches(_delivery(DeliveryStage.delivered)),
        isFalse,
      );
    });

    test('delayed matches attention stages', () {
      expect(
        DeliveryFilter.delayed.matches(_delivery(DeliveryStage.delayed)),
        isTrue,
      );
      expect(
        DeliveryFilter.delayed
            .matches(_delivery(DeliveryStage.deliveredWithIssues)),
        isTrue,
      );
      expect(
        DeliveryFilter.delayed.matches(_delivery(DeliveryStage.inTransit)),
        isFalse,
      );
    });

    test('delivered matches both delivered variants', () {
      expect(
        DeliveryFilter.delivered.matches(_delivery(DeliveryStage.delivered)),
        isTrue,
      );
      expect(
        DeliveryFilter.delivered
            .matches(_delivery(DeliveryStage.deliveredWithIssues)),
        isTrue,
      );
      expect(
        DeliveryFilter.delivered.matches(_delivery(DeliveryStage.delayed)),
        isFalse,
      );
    });
  });
}
