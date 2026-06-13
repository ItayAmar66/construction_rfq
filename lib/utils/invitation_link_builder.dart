/// Delivery status for organization invitations.
abstract final class InviteDeliveryStatus {
  static const pending = 'pending';
  static const sent = 'sent';
  static const failed = 'failed';
  static const copied = 'copied';
  static const accepted = 'accepted';
}

/// Builds invite join URLs (path-only; host from runtime Uri.base).
abstract final class InvitationLinkBuilder {
  static String invitePath(String inviteId) => '/invite/$inviteId';

  static String inviteLink(String inviteId) {
    final base = Uri.base;
    if (base.host.isEmpty || base.scheme == 'file') {
      return invitePath(inviteId);
    }
    return base.replace(path: invitePath(inviteId), query: '', fragment: '').toString();
  }
}

/// Hebrew labels for invitation lifecycle status.
String invitationStatusLabel(String status) {
  switch (status) {
    case 'pending':
      return 'ממתין';
    case 'accepted':
      return 'התקבל';
    case 'cancelled':
      return 'בוטל';
    case 'expired':
      return 'פג תוקף';
    default:
      return status;
  }
}

String invitationDeliveryStatusLabel(String deliveryStatus) {
  switch (deliveryStatus) {
    case InviteDeliveryStatus.pending:
      return 'ממתין';
    case InviteDeliveryStatus.sent:
      return 'נשלח';
    case InviteDeliveryStatus.failed:
      return 'נכשל';
    case InviteDeliveryStatus.copied:
      return 'הועתק';
    case InviteDeliveryStatus.accepted:
      return 'התקבל';
    default:
      return deliveryStatus;
  }
}

/// Hebrew email copy for invitation delivery (Cloud Function / provider use).
abstract final class InvitationEmailCopy {
  static const subject = 'הוזמנת להצטרף למערכת הרכש';

  static String body({
    required String companyLabel,
    required String inviteLink,
  }) =>
      'שלום,\n'
      'הוזמנת להצטרף ל־$companyLabel.\n'
      'כדי להתחבר, לחץ על הקישור:\n'
      '$inviteLink';
}
