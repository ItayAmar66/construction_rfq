import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_mode.dart';
import '../models/enterprise/enterprise_role.dart';
import '../models/enterprise/project_assignment.dart';
import '../utils/constants.dart';

/// Read-only repository for project-level team assignments.
/// Write path deferred — UI shows disabled actions.
class ProjectAssignmentRepository {
  ProjectAssignmentRepository({FirebaseFirestore? firestore})
      : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  Stream<List<ProjectAssignment>> watchForProject(String projectId) {
    if (projectId.isEmpty) return Stream.value(const []);
    if (AppMode.isDemoMode) return Stream.value(const []);
    return _db
        .collection(AppConstants.projectsCollection)
        .doc(projectId)
        .collection('assignments')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ProjectAssignment.fromMap(d.data())).toList())
        .handleError((e) {
      if (kDebugMode) debugPrint('[ProjectAssignmentRepo] $e');
      return <ProjectAssignment>[];
    });
  }
}

final projectAssignmentRepositoryProvider =
    Provider<ProjectAssignmentRepository>(
  (ref) => ProjectAssignmentRepository(),
);

final projectAssignmentsProvider =
    StreamProvider.family<List<ProjectAssignment>, String>(
  (ref, projectId) =>
      ref.watch(projectAssignmentRepositoryProvider).watchForProject(projectId),
);

/// Helper to get label for assignment roles.
String assignmentRoleLabel(EnterpriseRole role) {
  switch (role) {
    case EnterpriseRole.projectManager:
      return 'מנהל פרויקט';
    case EnterpriseRole.engineer:
      return 'מהנדס';
    case EnterpriseRole.procurementManager:
      return 'רכש משויך';
    case EnterpriseRole.contractorViewer:
    case EnterpriseRole.supplierViewer:
      return 'צופה';
    default:
      return role.value;
  }
}
