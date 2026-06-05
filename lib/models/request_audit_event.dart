/// Lightweight lifecycle audit event (client-side foundation only).
enum RequestAuditEventType {
  draftCreated,
  sent,
  supplierQuoted,
  quoteApproved,
  shipped,
}

class RequestAuditEvent {
  const RequestAuditEvent({
    required this.type,
    required this.at,
    required this.label,
    this.detail,
  });

  final RequestAuditEventType type;
  final DateTime at;
  final String label;
  final String? detail;
}
