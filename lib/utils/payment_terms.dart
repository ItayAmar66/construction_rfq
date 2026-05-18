/// Standard payment terms for supplier quotes.
abstract final class PaymentTerms {
  static const String cash = 'cash';
  static const String net30 = 'net30';
  static const String net60 = 'net60';
  static const String other = 'other';

  static const String defaultValue = net30;

  static const List<String> values = [cash, net30, net60, other];

  static String label(String value) {
    switch (value) {
      case cash:
        return 'מזומן';
      case net30:
        return 'שוטף + 30';
      case net60:
        return 'שוטף + 60';
      case other:
        return 'אחר';
      default:
        return 'שוטף + 30';
    }
  }
}
