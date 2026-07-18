import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/delivery.dart';
import '../models/quote_request.dart';
import '../models/supplier_quote.dart';
import 'providers.dart';
import 'supplier_hierarchy_providers.dart';

/// User-selectable slice of a delivery list.
enum DeliveryFilter { all, active, delayed, delivered }

extension DeliveryFilterX on DeliveryFilter {
  String get label {
    switch (this) {
      case DeliveryFilter.all:
        return 'הכל';
      case DeliveryFilter.active:
        return 'פעילים';
      case DeliveryFilter.delayed:
        return 'חריגות';
      case DeliveryFilter.delivered:
        return 'הושלמו';
    }
  }

  bool matches(Delivery d) {
    switch (this) {
      case DeliveryFilter.all:
        return true;
      case DeliveryFilter.active:
        return d.stage.isOpen;
      case DeliveryFilter.delayed:
        return d.stage.needsAttention;
      case DeliveryFilter.delivered:
        return d.stage == DeliveryStage.delivered ||
            d.stage == DeliveryStage.deliveredWithIssues;
    }
  }
}

/// Orders open deliveries (attention first) ahead of completed ones.
int compareDeliveries(Delivery a, Delivery b) {
  int rank(Delivery d) {
    switch (d.stage) {
      case DeliveryStage.delayed:
        return 0;
      case DeliveryStage.deliveredWithIssues:
        return 1;
      case DeliveryStage.awaitingShipment:
        return 2;
      case DeliveryStage.inTransit:
        return 3;
      case DeliveryStage.delivered:
        return 4;
    }
  }

  final byRank = rank(a).compareTo(rank(b));
  if (byRank != 0) return byRank;

  // Within open groups sort by soonest expected arrival; within closed groups
  // sort by most recent receipt.
  if (a.stage.isOpen) {
    final ae = a.expectedDeliveryDate ?? a.shippedAt ?? a.request.createdAt;
    final be = b.expectedDeliveryDate ?? b.shippedAt ?? b.request.createdAt;
    return ae.compareTo(be);
  }
  final ar = a.receivedAt ?? a.request.sortDate;
  final br = b.receivedAt ?? b.request.sortDate;
  return br.compareTo(ar);
}

List<Delivery> _buildDeliveries(
  List<QuoteRequest> requests,
  List<SupplierQuote> quotes,
) {
  final quoteById = {for (final q in quotes) q.id: q};
  final deliveries = <Delivery>[];
  for (final r in requests) {
    if (!Delivery.isDelivery(r)) continue;
    final approved =
        r.approvedQuoteId != null ? quoteById[r.approvedQuoteId] : null;
    deliveries.add(Delivery.fromRequest(
      r,
      supplierName: approved?.supplierName,
      amount: approved?.displayTotal,
    ));
  }
  deliveries.sort(compareDeliveries);
  return deliveries;
}

/// Cross-project deliveries for the signed-in contractor.
final customerDeliveriesProvider = Provider<List<Delivery>>((ref) {
  final requests = ref.watch(customerRequestsProvider).valueOrNull ?? [];
  final quotes = ref.watch(customerReceivedQuotesProvider).valueOrNull ?? [];
  return _buildDeliveries(requests, quotes);
});

/// Cross-contractor deliveries for the signed-in supplier.
final supplierDeliveriesProvider = Provider<List<Delivery>>((ref) {
  final requests = ref.watch(supplierAllRequestsProvider).valueOrNull ?? [];
  final sent = ref.watch(supplierSentQuotesProvider).valueOrNull ?? [];
  final toFulfill =
      ref.watch(supplierOrdersToFulfillProvider).valueOrNull ?? [];
  final history = ref.watch(supplierOrderHistoryProvider).valueOrNull ?? [];
  return _buildDeliveries(requests, [...sent, ...toFulfill, ...history]);
});

/// Compact live counts for dashboard badges/summaries.
class DeliverySummary {
  const DeliverySummary({
    required this.active,
    required this.delayed,
    required this.awaitingShipment,
    required this.delivered,
  });

  final int active;
  final int delayed;
  final int awaitingShipment;
  final int delivered;

  int get attention => delayed;
  int get total => active + delivered;
}

DeliverySummary summarizeDeliveries(List<Delivery> deliveries) {
  var active = 0, delayed = 0, awaiting = 0, delivered = 0;
  for (final d in deliveries) {
    switch (d.stage) {
      case DeliveryStage.awaitingShipment:
        awaiting++;
        active++;
        break;
      case DeliveryStage.inTransit:
        active++;
        break;
      case DeliveryStage.delayed:
        active++;
        delayed++;
        break;
      case DeliveryStage.delivered:
        delivered++;
        break;
      case DeliveryStage.deliveredWithIssues:
        delivered++;
        delayed++;
        break;
    }
  }
  return DeliverySummary(
    active: active,
    delayed: delayed,
    awaitingShipment: awaiting,
    delivered: delivered,
  );
}

final customerDeliverySummaryProvider = Provider<DeliverySummary>((ref) {
  return summarizeDeliveries(ref.watch(customerDeliveriesProvider));
});

final supplierDeliverySummaryProvider = Provider<DeliverySummary>((ref) {
  return summarizeDeliveries(ref.watch(supplierDeliveriesProvider));
});
