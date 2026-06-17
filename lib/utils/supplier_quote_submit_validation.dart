import 'user_facing_error.dart';

abstract final class SupplierQuoteSubmitValidation {
  static const priceRequired = 'יש להזין מחיר לפחות לפריט אחד';
  static const deliveryRequired = 'יש להזין זמן אספקה';
  static const supplierOrgRequired = 'לא נמצאה הרשאת ספק פעילה לחשבון זה';
  static const duplicateQuote = 'כבר נשלחה הצעה מטעם הספק הזה לבקשה זו';
  static const permissionDenied = 'אין הרשאה לשלוח הצעה לבקשה זו';

  static String? validate({
    required String deliveryTime,
    required double lineSubtotal,
    required String? supplierOrgId,
  }) {
    if (lineSubtotal <= 0) return priceRequired;
    if (deliveryTime.trim().isEmpty) return deliveryRequired;
    if (supplierOrgId == null || supplierOrgId.trim().isEmpty) {
      return supplierOrgRequired;
    }
    return null;
  }

  static String errorMessage(Object error) {
    final message = userFacingError(error);
    if (message.contains('כבר נשלחה הצעה')) return duplicateQuote;
    final raw = error.toString();
    if (raw.contains('permission-denied') ||
        message.contains('אין הרשאה לפעולה')) {
      return permissionDenied;
    }
    return message;
  }
}
