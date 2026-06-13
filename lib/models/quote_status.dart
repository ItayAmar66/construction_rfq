enum QuoteRequestStatus {
  draft,
  pendingApproval,
  procurementApproved,
  procurementRejected,
  sent,
  quotesReceived,
  ordered,
  shipped,
  completed,
  cancelled,
  closed,
}

extension QuoteRequestStatusExtension on QuoteRequestStatus {
  String get firestoreValue {
    switch (this) {
      case QuoteRequestStatus.draft:
        return 'טיוטה';
      case QuoteRequestStatus.pendingApproval:
        return 'ממתין לאישור רכש';
      case QuoteRequestStatus.procurementApproved:
        return 'אושר על ידי רכש';
      case QuoteRequestStatus.procurementRejected:
        return 'נדחה על ידי רכש';
      case QuoteRequestStatus.sent:
        return 'נשלח';
      case QuoteRequestStatus.quotesReceived:
        return 'התקבלו הצעות';
      case QuoteRequestStatus.ordered:
        return 'הוזמנה';
      case QuoteRequestStatus.shipped:
        return 'נשלחה';
      case QuoteRequestStatus.completed:
        return 'הושלמה';
      case QuoteRequestStatus.cancelled:
        return 'בוטלה';
      case QuoteRequestStatus.closed:
        return 'נסגר';
    }
  }

  String get label => firestoreValue;
  String get value => firestoreValue;

  static QuoteRequestStatus fromFirestore(String? raw) {
    if (raw == null || raw.isEmpty) return QuoteRequestStatus.draft;
    switch (raw) {
      case 'נשלח':
      case 'sent':
        return QuoteRequestStatus.sent;
      case 'התקבלו הצעות':
      case 'quotesReceived':
        return QuoteRequestStatus.quotesReceived;
      case 'הוזמנה':
      case 'ordered':
        return QuoteRequestStatus.ordered;
      case 'נשלחה':
      case 'shipped':
        return QuoteRequestStatus.shipped;
      case 'הושלמה':
      case 'completed':
        return QuoteRequestStatus.completed;
      case 'בוטלה':
      case 'cancelled':
        return QuoteRequestStatus.cancelled;
      case 'נסגר':
      case 'closed':
        return QuoteRequestStatus.closed;
      case 'טיוטה':
      case 'draft':
        return QuoteRequestStatus.draft;
      case 'ממתין לאישור רכש':
      case 'pendingApproval':
        return QuoteRequestStatus.pendingApproval;
      case 'אושר על ידי רכש':
      case 'procurementApproved':
        return QuoteRequestStatus.procurementApproved;
      case 'נדחה על ידי רכש':
      case 'procurementRejected':
        return QuoteRequestStatus.procurementRejected;
      default:
        return QuoteRequestStatus.draft;
    }
  }

  static List<String> openForSupplierFirestoreValues() => [
        QuoteRequestStatus.sent.firestoreValue,
        QuoteRequestStatus.quotesReceived.firestoreValue,
        'sent',
        'quotesReceived',
      ];

  static const editableStatuses = {
    QuoteRequestStatus.draft,
    QuoteRequestStatus.pendingApproval,
    QuoteRequestStatus.procurementRejected,
    QuoteRequestStatus.sent,
    QuoteRequestStatus.quotesReceived,
  };

  static const lockedStatuses = {
    QuoteRequestStatus.ordered,
    QuoteRequestStatus.shipped,
    QuoteRequestStatus.completed,
    QuoteRequestStatus.cancelled,
  };

  bool get isEditable => editableStatuses.contains(this);
  bool get isLocked => lockedStatuses.contains(this);
}
