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

  String get id => '${orgId}_$uid';

  bool hasRole(EnterpriseRole role) => roles.contains(role);

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
      };
}
