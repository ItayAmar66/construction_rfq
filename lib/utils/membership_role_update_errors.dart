import 'package:cloud_firestore/cloud_firestore.dart';

/// Maps membership role update failures to user-facing Hebrew messages.
abstract final class MembershipRoleUpdateErrors {
  static const selfChangeBlocked =
      'לא ניתן לשדרג או לשנות את התפקיד של עצמך';
  static const permissionDenied = 'אין הרשאה לשנות תפקיד זה';
  static const lastOwnerBlocked = 'לא ניתן לשנות את המנהל האחרון';
  static const platformAdminBlocked =
      'לא ניתן להקצות תפקיד מנהל מערכת דרך ניהול חברה';
  static const wrongOrgRole = 'תפקיד לא תואם לסוג הארגון';
  static const genericFailure =
      'לא ניתן לעדכן את התפקיד. נסו שוב או פנו למנהל.';

  static String userMessage(Object error) {
    if (error is FirebaseException && error.code == 'permission-denied') {
      return permissionDenied;
    }
    final text = error.toString().replaceFirst('Exception: ', '');
    if (text.contains('permission-denied') ||
        text.contains('PERMISSION_DENIED')) {
      return permissionDenied;
    }
    if (_knownMessages.contains(text)) return text;
    return genericFailure;
  }

  static const _knownMessages = {
    selfChangeBlocked,
    permissionDenied,
    lastOwnerBlocked,
    platformAdminBlocked,
    wrongOrgRole,
    'אין הרשאה לשנות תפקיד',
    'רק מנהל יכול לקדם למנהל',
  };
}
