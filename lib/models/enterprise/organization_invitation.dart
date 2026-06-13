import '../../utils/firestore_parsing.dart';
import '../../utils/invitation_link_builder.dart';
import 'enterprise_role.dart';
import 'organization_type.dart';

class OrganizationInvitation {
  const OrganizationInvitation({
    required this.id,
    required this.orgId,
    required this.orgType,
    required this.email,
    required this.role,
    this.displayName,
    this.status = 'pending',
    this.deliveryStatus = InviteDeliveryStatus.pending,
    required this.invitedByUid,
    this.invitedByName,
    this.acceptedByUid,
    this.createdAt,
    this.updatedAt,
    this.expiresAt,
    this.acceptedAt,
    this.cancelledAt,
  });

  final String id;
  final String orgId;
  final OrganizationType orgType;
  final String email;
  final String? displayName;
  final EnterpriseRole role;
  final String status;
  final String deliveryStatus;
  final String invitedByUid;
  final String? invitedByName;
  final String? acceptedByUid;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? expiresAt;
  final DateTime? acceptedAt;
  final DateTime? cancelledAt;

  bool get isPending => status == 'pending';

  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

  String get inviteLink => InvitationLinkBuilder.inviteLink(id);

  factory OrganizationInvitation.fromMap(String id, Map<String, dynamic> map) {
    return OrganizationInvitation(
      id: id,
      orgId: FirestoreParsing.parseString(map['orgId']),
      orgType: OrganizationType.fromValue(map['orgType']?.toString()) ??
          OrganizationType.contractor,
      email: FirestoreParsing.parseString(map['email']),
      displayName: FirestoreParsing.parseNullableString(map['displayName']),
      role: EnterpriseRole.fromValue(map['role']?.toString()) ??
          EnterpriseRole.engineer,
      status: FirestoreParsing.parseString(map['status'], defaultValue: 'pending'),
      deliveryStatus: FirestoreParsing.parseString(
        map['deliveryStatus'],
        defaultValue: InviteDeliveryStatus.pending,
      ),
      invitedByUid: FirestoreParsing.parseString(map['invitedByUid']),
      invitedByName: FirestoreParsing.parseNullableString(map['invitedByName']),
      acceptedByUid: FirestoreParsing.parseNullableString(map['acceptedByUid']),
      createdAt: FirestoreParsing.parseDate(map['createdAt']),
      updatedAt: FirestoreParsing.parseDate(map['updatedAt']),
      expiresAt: FirestoreParsing.parseDate(map['expiresAt']),
      acceptedAt: FirestoreParsing.parseDate(map['acceptedAt']),
      cancelledAt: FirestoreParsing.parseDate(map['cancelledAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'orgId': orgId,
        'orgType': orgType.value,
        'email': email,
        'role': role.value,
        if (displayName != null) 'displayName': displayName,
        'status': status,
        'deliveryStatus': deliveryStatus,
        'invitedByUid': invitedByUid,
        if (invitedByName != null) 'invitedByName': invitedByName,
        if (acceptedByUid != null) 'acceptedByUid': acceptedByUid,
        if (createdAt != null) 'createdAt': createdAt,
        if (updatedAt != null) 'updatedAt': updatedAt,
        if (expiresAt != null) 'expiresAt': expiresAt,
        if (acceptedAt != null) 'acceptedAt': acceptedAt,
        if (cancelledAt != null) 'cancelledAt': cancelledAt,
      };
}
