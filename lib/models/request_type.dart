enum RequestType {
  regular,
  tender,
}

extension RequestTypeExtension on RequestType {
  String get firestoreValue {
    switch (this) {
      case RequestType.regular:
        return 'regular';
      case RequestType.tender:
        return 'tender';
    }
  }

  String get label {
    switch (this) {
      case RequestType.regular:
        return 'בקשת הצעת מחיר רגילה';
      case RequestType.tender:
        return 'מכרז';
    }
  }

  static RequestType fromFirestore(String? raw) {
    if (raw == 'tender') return RequestType.tender;
    return RequestType.regular;
  }
}
