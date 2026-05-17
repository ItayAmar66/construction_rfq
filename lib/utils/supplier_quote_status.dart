/// Hebrew status values stored on [supplierQuotes] documents.
class SupplierQuoteStatus {
  static const sent = 'נשלח';
  static const approved = 'אושרה';
  static const rejected = 'נדחתה';
  static const shipped = 'נשלחה';
  static const notSelected = 'לא נבחרה';

  static const visibleToCustomer = {
    sent,
    approved,
    rejected,
    shipped,
  };

  static bool isVisibleToCustomer(String status) =>
      visibleToCustomer.contains(status);

  static bool countsTowardReceived(String status) =>
      isVisibleToCustomer(status);

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
      default:
        return status;
    }
  }
}
