import '../models/quote_request.dart';
import '../models/quote_status.dart';
import '../models/request_audit_event.dart';
import '../models/supplier_quote.dart';
import '../utils/request_audit_trail.dart';

/// Combined audit/history read model for enterprise views.
class EnterpriseAuditEntry {
  const EnterpriseAuditEntry({
    required this.at,
    required this.label,
    required this.type,
    this.detail,
    this.actor,
  });

  final DateTime at;
  final String label;
  final RequestAuditEventType type;
  final String? detail;
  final String? actor;
}

class EnterpriseAuditReadModel {
  const EnterpriseAuditReadModel({
    required this.requestId,
    required this.entries,
    required this.currentStatusLabel,
  });

  final String requestId;
  final List<EnterpriseAuditEntry> entries;
  final String currentStatusLabel;

  int get eventCount => entries.length;

  bool get hasQuotes =>
      entries.any((e) => e.type == RequestAuditEventType.supplierQuoted);

  bool get isFulfilled => entries.any(
        (e) =>
            e.type == RequestAuditEventType.shipped ||
            e.type == RequestAuditEventType.quoteApproved,
      );
}

abstract final class EnterpriseAuditReadModelBuilder {
  static EnterpriseAuditReadModel build({
    required QuoteRequest request,
    List<SupplierQuote> quotes = const [],
  }) {
    final events = RequestAuditTrail.build(request: request, quotes: quotes);
    final entries = events
        .map(
          (event) => EnterpriseAuditEntry(
            at: event.at,
            label: event.label,
            type: event.type,
            detail: event.detail,
            actor: event.detail,
          ),
        )
        .toList();

    return EnterpriseAuditReadModel(
      requestId: request.id,
      entries: entries,
      currentStatusLabel: request.status.label,
    );
  }
}
