/// Customer RFQ urgency level.
enum RequestUrgency {
  normal,
  urgent,
  critical,
}

extension RequestUrgencyExtension on RequestUrgency {
  String get label {
    switch (this) {
      case RequestUrgency.normal:
        return 'רגיל';
      case RequestUrgency.urgent:
        return 'דחוף';
      case RequestUrgency.critical:
        return 'קריטי';
    }
  }

  String get firestoreValue {
    switch (this) {
      case RequestUrgency.normal:
        return 'normal';
      case RequestUrgency.urgent:
        return 'urgent';
      case RequestUrgency.critical:
        return 'critical';
    }
  }

  static RequestUrgency fromFirestore(String? value) {
    switch (value) {
      case 'urgent':
        return RequestUrgency.urgent;
      case 'critical':
        return RequestUrgency.critical;
      default:
        return RequestUrgency.normal;
    }
  }
}
