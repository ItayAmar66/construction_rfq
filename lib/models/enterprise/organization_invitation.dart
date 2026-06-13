import '../../utils/firestore_parsing.dart';
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
    required this.invitedByUid,
    this.invitedByName,
    this.createdAt,
    this.updatedAt,
    this.expiresAt,
  });

  final String id;
  final String orgId;
  final OrganizationType orgType;
  final String email;
  final String? displayName;
  final EnterpriseRole role;
  final String status;
  final String invitedByUid;
  final String? invitedByName;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? expiresAt;

  bool get isPending => status == 'pending';

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
      invitedByUid: FirestoreParsing.parseString(map['invitedByUid']),
      invitedByName: FirestoreParsing.parseNullableString(map['invitedByName']),
      createdAt: FirestoreParsing.parseDate(map['createdAt']),
      updatedAt: FirestoreParsing.parseDate(map['updatedAt']),
      expiresAt: FirestoreParsing.parseDate(map['expiresAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'orgId': orgId,
        'orgType': orgType.value,
        'email': email,
        'role': role.value,
        if (displayName != null) 'displayName': displayName,
        'status': status,
        'invitedByUid': invitedByUid,
        if (invitedByName != null) 'invitedByName': invitedByName,
        if (createdAt != null) 'createdAt': createdAt,
        if (updatedAt != null) 'updatedAt': updatedAt,
        if (expiresAt != null) 'expiresAt': expiresAt,
      };
}
