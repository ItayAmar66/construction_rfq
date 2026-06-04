import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/quote_request.dart';
import '../models/request_urgency.dart';

/// Prefill cart RFQ fields after duplicating a request.
class RfqPrefill {
  const RfqPrefill({
    this.notes,
    this.deliveryAddress,
    this.deliveryCity,
    this.urgency = RequestUrgency.normal,
    this.requiredDeliveryDate,
    this.expirationDays = 14,
    this.sourceRequestId,
  });

  final String? notes;
  final String? sourceRequestId;
  final String? deliveryAddress;
  final String? deliveryCity;
  final RequestUrgency urgency;
  final DateTime? requiredDeliveryDate;
  final int expirationDays;

  factory RfqPrefill.fromRequest(QuoteRequest request) {
    return RfqPrefill(
      notes: request.notes,
      deliveryAddress: request.deliveryAddress,
      deliveryCity: request.deliveryCity ?? request.customerCity,
      urgency: request.urgency,
      requiredDeliveryDate: request.requiredDeliveryDate,
      expirationDays: 14,
      sourceRequestId: request.id,
    );
  }
}

class RfqPrefillNotifier extends StateNotifier<RfqPrefill?> {
  RfqPrefillNotifier() : super(null);

  void set(RfqPrefill prefill) => state = prefill;

  void clear() => state = null;
}

final rfqPrefillProvider =
    StateNotifierProvider<RfqPrefillNotifier, RfqPrefill?>(
  (ref) => RfqPrefillNotifier(),
);
