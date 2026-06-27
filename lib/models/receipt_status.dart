enum ReceiptStatus {
  pendingReceipt,
  receivedFull,
  receivedWithIssues,
}

extension ReceiptStatusExtension on ReceiptStatus {
  String get firestoreValue {
    switch (this) {
      case ReceiptStatus.pendingReceipt:
        return 'pending_receipt';
      case ReceiptStatus.receivedFull:
        return 'received_full';
      case ReceiptStatus.receivedWithIssues:
        return 'received_with_issues';
    }
  }

  String get label {
    switch (this) {
      case ReceiptStatus.pendingReceipt:
        return 'ממתין לאישור קבלה';
      case ReceiptStatus.receivedFull:
        return 'התקבל במלואו';
      case ReceiptStatus.receivedWithIssues:
        return 'התקבל עם חריגות';
    }
  }

  static ReceiptStatus? fromFirestore(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    switch (raw) {
      case 'pending_receipt':
        return ReceiptStatus.pendingReceipt;
      case 'received_full':
        return ReceiptStatus.receivedFull;
      case 'received_with_issues':
        return ReceiptStatus.receivedWithIssues;
      default:
        return null;
    }
  }

  bool get isFinal =>
      this == ReceiptStatus.receivedFull ||
      this == ReceiptStatus.receivedWithIssues;
}
