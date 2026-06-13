import '../models/enterprise/organization_invitation.dart';
import '../utils/invitation_link_builder.dart';

class InviteDeliveryResult {
  const InviteDeliveryResult({
    required this.status,
    required this.inviteLink,
    this.message,
  });

  final String status;
  final String inviteLink;
  final String? message;
}

/// Sends invitation emails via configured provider (Cloud Function in production).
abstract class EmailInviteService {
  bool get isProductionConfigured;

  Future<InviteDeliveryResult> sendInvitationEmail(
    OrganizationInvitation invitation, {
    String? companyLabel,
  });
}

/// Demo/local: exposes copy-link; no external email provider.
class DevInviteDeliveryService implements EmailInviteService {
  @override
  bool get isProductionConfigured => false;

  @override
  Future<InviteDeliveryResult> sendInvitationEmail(
    OrganizationInvitation invitation, {
    String? companyLabel,
  }) async {
    final link = InvitationLinkBuilder.inviteLink(invitation.id);
    return InviteDeliveryResult(
      status: InviteDeliveryStatus.copied,
      inviteLink: link,
      message:
          'כרגע ניתן להעתיק קישור הזמנה. שליחת מייל אוטומטית תחובר בהמשך.',
    );
  }
}

/// Production placeholder — requires Cloud Function + provider env vars.
class CloudFunctionInviteDeliveryService implements EmailInviteService {
  CloudFunctionInviteDeliveryService({this.callableConfigured = false});

  final bool callableConfigured;

  @override
  bool get isProductionConfigured => callableConfigured;

  @override
  Future<InviteDeliveryResult> sendInvitationEmail(
    OrganizationInvitation invitation, {
    String? companyLabel,
  }) async {
    if (!callableConfigured) {
      return DevInviteDeliveryService().sendInvitationEmail(
        invitation,
        companyLabel: companyLabel,
      );
    }
    throw UnimplementedError(
      'חבר Cloud Function sendInvitationEmail — ראו docs/INVITATION_EMAILS.md',
    );
  }
}
