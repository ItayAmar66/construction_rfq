import '../../utils/firestore_parsing.dart';
import 'enterprise_role.dart';

class ProjectAssignment {
  const ProjectAssignment({
    required this.projectId,
    required this.orgId,
    required this.uid,
    required this.role,
    this.displayName,
    this.email,
    this.assignedByUid,
    this.createdAt,
    this.updatedAt,
  });

  final String projectId;
  final String orgId;
  final String uid;
  final EnterpriseRole role;
  final String? displayName;
  final String? email;
  final String? assignedByUid;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get id => '${projectId}_$uid';

  factory ProjectAssignment.fromMap(Map<String, dynamic> map) {
    return ProjectAssignment(
      projectId: FirestoreParsing.parseString(map['projectId']),
      orgId: FirestoreParsing.parseString(map['orgId']),
      uid: FirestoreParsing.parseString(map['uid']),
      role: EnterpriseRole.fromValue(map['role']?.toString()) ??
          EnterpriseRole.engineer,
      displayName: FirestoreParsing.parseNullableString(map['displayName']),
      email: FirestoreParsing.parseNullableString(map['email']),
      assignedByUid: FirestoreParsing.parseNullableString(map['assignedByUid']),
      createdAt: FirestoreParsing.parseDate(map['createdAt']),
      updatedAt: FirestoreParsing.parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'projectId': projectId,
        'orgId': orgId,
        'uid': uid,
        'role': role.value,
        if (displayName != null) 'displayName': displayName,
        if (email != null) 'email': email,
        if (assignedByUid != null) 'assignedByUid': assignedByUid,
        if (createdAt != null) 'createdAt': createdAt,
        if (updatedAt != null) 'updatedAt': updatedAt,
      };
}
