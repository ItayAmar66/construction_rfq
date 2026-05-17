enum QuoteRequestStatus {
  draft,
  sent,
  quotesReceived,
  ordered,
  shipped,
  closed,
}

extension QuoteRequestStatusExtension on QuoteRequestStatus {
  /// Value persisted in Firestore.
  String get firestoreValue {
    switch (this) {
      case QuoteRequestStatus.draft:
        return 'טיוטה';
      case QuoteRequestStatus.sent:
        return 'נשלח';
      case QuoteRequestStatus.quotesReceived:
        return 'התקבלו הצעות';
      case QuoteRequestStatus.ordered:
        return 'הוזמנה';
      case QuoteRequestStatus.shipped:
        return 'נשלחה';
      case QuoteRequestStatus.closed:
        return 'נסגר';
    }
  }

  String get label => firestoreValue;

  /// Alias used when writing documents.
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
      case 'נסגר':
      case 'closed':
        return QuoteRequestStatus.closed;
      case 'טיוטה':
      case 'draft':
        return QuoteRequestStatus.draft;
      default:
        return QuoteRequestStatus.draft;
    }
  }

  /// Statuses where suppliers may still submit a quote.
  static List<String> openForSupplierFirestoreValues() => [
        QuoteRequestStatus.sent.firestoreValue,
        QuoteRequestStatus.quotesReceived.firestoreValue,
        'sent',
        'quotesReceived',
      ];
}
