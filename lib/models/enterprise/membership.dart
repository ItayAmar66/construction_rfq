import '../../utils/firestore_parsing.dart';
import 'enterprise_role.dart';
import 'organization_type.dart';

class Membership {
  const Membership({
    required this.uid,
    required this.orgId,
    required this.orgType,
    this.roles = const [],
    this.status = 'active',
    this.projectIds = const [],
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.email,
    this.displayName,
  });

  final String uid;
  final String orgId;
  final OrganizationType orgType;
  final List<EnterpriseRole> roles;
  final String status;
  final List<String> projectIds;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? email;
  final String? displayName;

  String get id => '${orgId}_$uid';

  bool hasRole(EnterpriseRole role) => roles.contains(role);

  String get displayLabel {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final mail = email?.trim();
    if (mail != null && mail.isNotEmpty) return mail;
    if (uid.length > 8) return '${uid.substring(0, 8)}…';
    return uid;
  }

  factory Membership.fromMap(String uid, Map<String, dynamic> map) {
    final roleValues = FirestoreParsing.parseStringList(map['roles']);
    return Membership(
      uid: uid,
      orgId: FirestoreParsing.parseString(map['orgId']),
      orgType: OrganizationType.fromValue(map['orgType']?.toString()) ??
          OrganizationType.contractor,
      roles: roleValues
          .map(EnterpriseRole.fromValue)
          .whereType<EnterpriseRole>()
          .toList(),
      status: FirestoreParsing.parseString(map['status'], defaultValue: 'active'),
      projectIds: FirestoreParsing.parseStringList(map['projectIds']),
      createdBy: FirestoreParsing.parseNullableString(map['createdBy']),
      createdAt: FirestoreParsing.parseDate(map['createdAt']),
      updatedAt: FirestoreParsing.parseDate(map['updatedAt']),
      email: FirestoreParsing.parseNullableString(map['email']),
      displayName: FirestoreParsing.parseNullableString(map['displayName']),
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'orgId': orgId,
        'orgType': orgType.value,
        'roles': roles.map((r) => r.value).toList(),
        'status': status,
        'projectIds': projectIds,
        if (createdBy != null) 'createdBy': createdBy,
        if (createdAt != null) 'createdAt': createdAt,
        if (updatedAt != null) 'updatedAt': updatedAt,
        if (email != null) 'email': email,
        if (displayName != null) 'displayName': displayName,
      };
}
