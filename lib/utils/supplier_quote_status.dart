/// Hebrew status values stored on [supplierQuotes] documents.
class SupplierQuoteStatus {
  static const sent = 'נשלח';
  static const approved = 'אושרה';
  static const rejected = 'נדחתה';
  static const shipped = 'נשלחה';
  static const notSelected = 'לא נבחרה';
  static const outdated = 'לא מעודכנת';
  static const pendingCustomer = 'ממתין להחלטת לקוח';
  static const won = 'זכית';
  static const lost = 'לא נבחר';
  static const delivered = 'נשלח/סופק';

  static const visibleToCustomer = {
    sent,
    approved,
    rejected,
    shipped,
    outdated,
  };

  static bool isVisibleToCustomer(String status) =>
      visibleToCustomer.contains(status);

  static bool countsTowardReceived(String status) =>
      status == sent ||
      status == approved ||
      status == rejected ||
      status == shipped;

  static String label(String status) {
    switch (status) {
      case sent:
        return 'נשלח';
      case approved:
        return 'אושרה';
      case rejected:
        return 'נדחתה';
      case shipped:
        return 'נשלחה';
      case notSelected:
        return 'לא נבחרה';
      case outdated:
        return 'לא מעודכנת';
      case pendingCustomer:
        return 'ממתין להחלטת לקוח';
      case won:
        return 'זכית';
      case lost:
        return 'לא נבחר';
      case delivered:
        return 'נשלח/סופק';
      default:
        return status;
    }
  }

  /// Supplier-facing display label for quote history cards.
  static String displayLabel(String status) {
    switch (status) {
      case sent:
        return pendingCustomer;
      case approved:
        return won;
      case rejected:
      case notSelected:
        return lost;
      case shipped:
        return delivered;
      default:
        return label(status);
    }
  }
}
