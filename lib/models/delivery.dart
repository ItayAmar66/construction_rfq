import 'quote_request.dart';
import 'quote_status.dart';
import 'receipt_status.dart';

/// Lifecycle stage of a physical delivery, derived from the underlying order
/// (its [QuoteRequest] status plus shipment/receipt timestamps). This is a real
/// delivery lifecycle — not a raw RFQ status — so the UI can reason about it
/// independently of the procurement funnel.
enum DeliveryStage {
  /// Order approved, supplier has not dispatched it yet.
  awaitingShipment,

  /// Dispatched and on the way, within its expected arrival window.
  inTransit,

  /// Dispatched but past its expected arrival date without confirmed receipt.
  delayed,

  /// Delivered and confirmed complete by the contractor.
  delivered,

  /// Delivered but the contractor reported discrepancies on receipt.
  deliveredWithIssues,
}

extension DeliveryStageX on DeliveryStage {
  bool get isOpen =>
      this == DeliveryStage.awaitingShipment ||
      this == DeliveryStage.inTransit ||
      this == DeliveryStage.delayed;

  bool get isClosed => !isOpen;

  bool get needsAttention =>
      this == DeliveryStage.delayed ||
      this == DeliveryStage.deliveredWithIssues;

  /// 0..1 progress used by linear indicators.
  double get progress {
    switch (this) {
      case DeliveryStage.awaitingShipment:
        return 0.2;
      case DeliveryStage.inTransit:
        return 0.6;
      case DeliveryStage.delayed:
        return 0.6;
      case DeliveryStage.delivered:
      case DeliveryStage.deliveredWithIssues:
        return 1;
    }
  }

  String get label {
    switch (this) {
      case DeliveryStage.awaitingShipment:
        return 'ממתין למשלוח';
      case DeliveryStage.inTransit:
        return 'בדרך';
      case DeliveryStage.delayed:
        return 'באיחור';
      case DeliveryStage.delivered:
        return 'סופק';
      case DeliveryStage.deliveredWithIssues:
        return 'סופק עם חריגות';
    }
  }
}

/// The kind of a timeline milestone — the UI maps this to an icon/colour so the
/// model stays free of Flutter dependencies.
enum DeliveryEventKind { ordered, shipped, expected, delivered, issue }

class DeliveryEvent {
  const DeliveryEvent({
    required this.kind,
    required this.title,
    this.subtitle,
    this.date,
    this.done = false,
    this.isCurrent = false,
  });

  final DeliveryEventKind kind;
  final String title;
  final String? subtitle;
  final DateTime? date;
  final bool done;
  final bool isCurrent;
}

/// A view-model unifying the shipment lifecycle for a single order. Built from a
/// [QuoteRequest] and, when available, the approved quote's supplier + total so
/// the same object drives contractor and supplier delivery surfaces.
class Delivery {
  const Delivery({
    required this.request,
    required this.stage,
    this.supplierName,
    this.amount,
  });

  final QuoteRequest request;
  final DeliveryStage stage;
  final String? supplierName;
  final double? amount;

  String get id => request.id;
  String get title =>
      request.projectName?.trim().isNotEmpty == true
          ? request.projectName!.trim()
          : request.customerName;
  String get contractorName => request.customerName;
  String? get projectLocation =>
      (request.projectLocation ?? request.siteName)?.trim();
  DateTime? get shippedAt => request.shippedAt;
  DateTime? get expectedDeliveryDate => request.expectedDeliveryDate;
  DateTime? get receivedAt => request.receivedAt;
  String? get trackingReference => request.trackingReference;
  String? get carrierName => request.carrierName;

  int get itemCount => request.items.length;

  /// Whole days remaining until (or overdue past) the expected arrival, or null
  /// when there is no target date or the delivery is already closed.
  int? get daysToEta {
    final eta = expectedDeliveryDate;
    if (eta == null || stage.isClosed) return null;
    final now = DateTime.now();
    final target = DateTime(eta.year, eta.month, eta.day);
    final today = DateTime(now.year, now.month, now.day);
    return target.difference(today).inDays;
  }

  bool get isOverdue => (daysToEta ?? 1) < 0;

  /// Ordered timeline milestones for the shipment.
  List<DeliveryEvent> get timeline {
    final events = <DeliveryEvent>[];
    final shipped = request.shippedAt != null ||
        stage != DeliveryStage.awaitingShipment;
    final received = request.receivedAt != null &&
        (stage == DeliveryStage.delivered ||
            stage == DeliveryStage.deliveredWithIssues);

    events.add(DeliveryEvent(
      kind: DeliveryEventKind.ordered,
      title: 'ההזמנה אושרה',
      done: true,
      isCurrent: stage == DeliveryStage.awaitingShipment,
    ));

    events.add(DeliveryEvent(
      kind: DeliveryEventKind.shipped,
      title: shipped ? 'נשלח מהספק' : 'ממתין למשלוח מהספק',
      subtitle: carrierName,
      date: request.shippedAt,
      done: shipped,
      isCurrent: stage == DeliveryStage.inTransit ||
          stage == DeliveryStage.delayed,
    ));

    if (expectedDeliveryDate != null && !received) {
      events.add(DeliveryEvent(
        kind: DeliveryEventKind.expected,
        title: isOverdue ? 'צפי הגעה חלף' : 'צפי הגעה',
        date: expectedDeliveryDate,
        done: false,
        isCurrent: stage == DeliveryStage.delayed,
      ));
    }

    if (stage == DeliveryStage.deliveredWithIssues) {
      events.add(DeliveryEvent(
        kind: DeliveryEventKind.issue,
        title: 'התקבל עם חריגות',
        subtitle: request.receiptNotes,
        date: request.receivedAt,
        done: true,
        isCurrent: true,
      ));
    } else {
      events.add(DeliveryEvent(
        kind: DeliveryEventKind.delivered,
        title: received ? 'התקבל אצל הקבלן' : 'ממתין לאישור קבלה',
        date: request.receivedAt,
        done: received,
        isCurrent: stage == DeliveryStage.delivered,
      ));
    }

    return events;
  }

  /// Derives the delivery stage from an order's request state.
  static DeliveryStage stageFor(QuoteRequest r) {
    switch (r.receiptStatus) {
      case ReceiptStatus.receivedFull:
        return DeliveryStage.delivered;
      case ReceiptStatus.receivedWithIssues:
        return DeliveryStage.deliveredWithIssues;
      case ReceiptStatus.pendingReceipt:
      case null:
        break;
    }
    if (r.status == QuoteRequestStatus.receivedFull) {
      return DeliveryStage.delivered;
    }
    if (r.status == QuoteRequestStatus.receivedWithIssues) {
      return DeliveryStage.deliveredWithIssues;
    }
    final inTransit = r.status == QuoteRequestStatus.shipped ||
        r.status == QuoteRequestStatus.pendingReceipt ||
        r.shippedAt != null;
    if (inTransit) {
      final eta = r.expectedDeliveryDate;
      if (eta != null) {
        final now = DateTime.now();
        final target = DateTime(eta.year, eta.month, eta.day);
        final today = DateTime(now.year, now.month, now.day);
        if (target.difference(today).inDays < 0) return DeliveryStage.delayed;
      }
      return DeliveryStage.inTransit;
    }
    return DeliveryStage.awaitingShipment;
  }

  /// Statuses that represent a real (present or past) delivery.
  static const trackedStatuses = <QuoteRequestStatus>{
    QuoteRequestStatus.ordered,
    QuoteRequestStatus.shipped,
    QuoteRequestStatus.pendingReceipt,
    QuoteRequestStatus.receivedFull,
    QuoteRequestStatus.receivedWithIssues,
  };

  static bool isDelivery(QuoteRequest r) => trackedStatuses.contains(r.status);

  factory Delivery.fromRequest(
    QuoteRequest request, {
    String? supplierName,
    double? amount,
  }) {
    return Delivery(
      request: request,
      stage: stageFor(request),
      supplierName: supplierName,
      amount: amount,
    );
  }
}
