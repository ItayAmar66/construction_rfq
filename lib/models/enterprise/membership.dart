import '../../utils/firestore_parsing.dart';
import 'enterprise_role.dart';
import 'organization_type.dart';
import 'permission.dart';

class Membership {
  const Membership({
    required this.uid,
    required this.orgId,
    required this.orgType,
    this.roles = const [],
    this.status = 'active',
    this.projectIds = const [],
    this.orgWideProjectAccess,
    this.managerUid,
    this.team,
    this.grants = const [],
    this.revokes = const [],
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.email,
    this.displayName,
  });

  final String uid;
  final String orgId;
  final OrganizationType orgType;

  /// Stored as a single-element list (enforced by rules); use [role].
  final List<EnterpriseRole> roles;
  final String status;

  /// Derived compatibility cache only — `projects/{id}/assignments/{uid}` is
  /// the authoritative source for explicit project access.
  final List<String> projectIds;

  /// Explicit project-access mode. When null, falls back to the role default
  /// ([roleDefaultsToOrgWideAccess]). Suppliers are always org-wide.
  final bool? orgWideProjectAccess;

  /// Informational only — never grants access.
  final String? managerUid;

  /// Informational team label — never grants access.
  final String? team;

  /// Narrow permission exceptions added on top of the role.
  final List<Permission> grants;

  /// Permission exceptions removed from the role; revokes win over grants.
  final List<Permission> revokes;

  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? email;
  final String? displayName;

  String get id => '${orgId}_$uid';

  /// The single canonical organization role for this membership.
  EnterpriseRole? get role => roles.firstOrNull;

  bool hasRole(EnterpriseRole role) => roles.contains(role);

  bool get isActive => status == 'active';

  /// Roles whose members see every organization project by default.
  static bool roleDefaultsToOrgWideAccess(EnterpriseRole? role) {
    if (role == null) return false;
    return role.isOrgAdminRole ||
        role == EnterpriseRole.procurementManager ||
        role.isSupplierRole;
  }

  /// Effective project-access mode: explicit field wins, otherwise role
  /// default. Suppliers do not use contractor-style project assignment.
  bool get hasOrgWideProjectAccess {
    if (orgType == OrganizationType.supplier) return true;
    return orgWideProjectAccess ?? roleDefaultsToOrgWideAccess(role);
  }

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
          .toSet()
          .toList(),
      status:
          FirestoreParsing.parseString(map['status'], defaultValue: 'active'),
      projectIds: FirestoreParsing.parseStringList(map['projectIds']),
      orgWideProjectAccess: map['orgWideProjectAccess'] is bool
          ? map['orgWideProjectAccess'] as bool
          : null,
      managerUid: FirestoreParsing.parseNullableString(map['managerUid']),
      team: FirestoreParsing.parseNullableString(map['team']),
      grants: FirestoreParsing.parseStringList(map['grants'])
          .map(Permission.fromValue)
          .whereType<Permission>()
          .toList(),
      revokes: FirestoreParsing.parseStringList(map['revokes'])
          .map(Permission.fromValue)
          .whereType<Permission>()
          .toList(),
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
        if (orgWideProjectAccess != null)
          'orgWideProjectAccess': orgWideProjectAccess,
        if (managerUid != null) 'managerUid': managerUid,
        if (team != null) 'team': team,
        if (grants.isNotEmpty) 'grants': grants.map((p) => p.value).toList(),
        if (revokes.isNotEmpty) 'revokes': revokes.map((p) => p.value).toList(),
        if (createdBy != null) 'createdBy': createdBy,
        if (createdAt != null) 'createdAt': createdAt,
        if (updatedAt != null) 'updatedAt': updatedAt,
        if (email != null) 'email': email,
        if (displayName != null) 'displayName': displayName,
      };

  Membership copyWith({
    List<EnterpriseRole>? roles,
    String? status,
    List<String>? projectIds,
    bool? orgWideProjectAccess,
    String? managerUid,
    String? team,
    List<Permission>? grants,
    List<Permission>? revokes,
    String? email,
    String? displayName,
  }) {
    return Membership(
      uid: uid,
      orgId: orgId,
      orgType: orgType,
      roles: roles ?? this.roles,
      status: status ?? this.status,
      projectIds: projectIds ?? this.projectIds,
      orgWideProjectAccess: orgWideProjectAccess ?? this.orgWideProjectAccess,
      managerUid: managerUid ?? this.managerUid,
      team: team ?? this.team,
      grants: grants ?? this.grants,
      revokes: revokes ?? this.revokes,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
    );
  }
}
