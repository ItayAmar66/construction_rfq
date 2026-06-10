import '../../utils/firestore_parsing.dart';
import 'enterprise_role.dart';

class ProjectAssignment {
  const ProjectAssignment({
    required this.projectId,
    required this.orgId,
    required this.uid,
    required this.role,
    this.createdAt,
  });

  final String projectId;
  final String orgId;
  final String uid;
  final EnterpriseRole role;
  final DateTime? createdAt;

  String get id => '${projectId}_$uid';

  factory ProjectAssignment.fromMap(Map<String, dynamic> map) {
    return ProjectAssignment(
      projectId: FirestoreParsing.parseString(map['projectId']),
      orgId: FirestoreParsing.parseString(map['orgId']),
      uid: FirestoreParsing.parseString(map['uid']),
      role: EnterpriseRole.fromValue(map['role']?.toString()) ??
          EnterpriseRole.engineer,
      createdAt: FirestoreParsing.parseDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'projectId': projectId,
        'orgId': orgId,
        'uid': uid,
        'role': role.value,
        if (createdAt != null) 'createdAt': createdAt,
      };
}
