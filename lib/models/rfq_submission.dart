import 'request_type.dart';
import 'request_urgency.dart';

/// Customer RFQ metadata when creating or updating a request.
class RfqSubmission {
  const RfqSubmission({
    this.notes,
    this.deliveryAddress,
    this.deliveryCity,
    this.urgency = RequestUrgency.normal,
    this.requiredDeliveryDate,
    this.expiresAt,
    this.requestType = RequestType.regular,
    this.tenderDuration = const Duration(hours: 24),
    this.expirationDays = 14,
  });

  final String? notes;
  final String? deliveryAddress;
  final String? deliveryCity;
  final RequestUrgency urgency;
  final DateTime? requiredDeliveryDate;
  final DateTime? expiresAt;
  final RequestType requestType;
  final Duration tenderDuration;
  final int expirationDays;

  DateTime resolveExpiresAt() {
    return expiresAt ??
        DateTime.now().add(Duration(days: expirationDays));
  }
}
