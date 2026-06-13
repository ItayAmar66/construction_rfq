import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_mode.dart';
import '../models/enterprise/enterprise_role.dart';
import '../models/enterprise/membership.dart';
import '../models/enterprise/permission.dart';
import '../models/enterprise/project_assignment.dart';
import '../providers/enterprise_providers.dart';
import '../providers/providers.dart';
import '../services/mock_store.dart';
import '../utils/constants.dart';
import '../utils/project_assignment_roles.dart';

class ProjectAssignmentRepository {
  ProjectAssignmentRepository({FirebaseFirestore? firestore})
      : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _assignments(String projectId) =>
      _db
          .collection(AppConstants.projectsCollection)
          .doc(projectId)
          .collection('assignments');

  Stream<List<ProjectAssignment>> watchForProject(String projectId) {
    if (projectId.isEmpty) return Stream.value(const []);
    if (AppMode.isDemoMode) {
      return MockStore.instance.watchProjectAssignments(projectId);
    }
    return _assignments(projectId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ProjectAssignment.fromMap(d.data()))
            .toList())
        .handleError((e) {
      if (kDebugMode) debugPrint('[ProjectAssignmentRepo] $e');
      return <ProjectAssignment>[];
    });
  }

  Future<ProjectAssignment> assignUserToProject({
    required String projectId,
    required String orgId,
    required String uid,
    required EnterpriseRole role,
    required String actorUid,
    required bool canManage,
    String? displayName,
    String? email,
    List<Membership> orgMembers = const [],
  }) async {
    _validateAssign(
      projectId: projectId,
      uid: uid,
      role: role,
      actorUid: actorUid,
      canManage: canManage,
      orgMembers: orgMembers,
    );
    final now = DateTime.now();
    final assignment = ProjectAssignment(
      projectId: projectId,
      orgId: orgId,
      uid: uid,
      role: role,
      displayName: displayName,
      email: email,
      assignedByUid: actorUid,
      createdAt: now,
      updatedAt: now,
    );
    if (AppMode.isDemoMode) {
      return MockStore.instance.assignUserToProject(assignment);
    }
    await _assignments(projectId).doc(uid).set({
      ...assignment.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return assignment;
  }

  Future<ProjectAssignment> updateProjectAssignmentRole({
    required String projectId,
    required String uid,
    required EnterpriseRole role,
    required String actorUid,
    required bool canManage,
  }) async {
    if (!canManage) throw Exception('אין הרשאה לשנות שיוך פרויקט');
    if (actorUid == uid && role == EnterpriseRole.projectManager) {
      throw Exception('לא ניתן לשדרג את עצמך למנהל פרויקט');
    }
    if (!ProjectAssignmentRoles.isAssignable(role)) {
      throw Exception('תפקיד לא תקין לפרויקט');
    }
    if (AppMode.isDemoMode) {
      return MockStore.instance.updateProjectAssignmentRole(
        projectId: projectId,
        uid: uid,
        role: role,
      );
    }
    await _assignments(projectId).doc(uid).update({
      'role': role.value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final snap = await _assignments(projectId).doc(uid).get();
    return ProjectAssignment.fromMap(snap.data()!);
  }

  Future<void> removeProjectAssignment({
    required String projectId,
    required String uid,
    required bool canManage,
  }) async {
    if (!canManage) throw Exception('אין הרשאה להסיר שיוך פרויקט');
    if (AppMode.isDemoMode) {
      MockStore.instance.removeProjectAssignment(projectId: projectId, uid: uid);
      return;
    }
    await _assignments(projectId).doc(uid).delete();
  }

  static void _validateAssign({
    required String projectId,
    required String uid,
    required EnterpriseRole role,
    required String actorUid,
    required bool canManage,
    required List<Membership> orgMembers,
  }) {
    if (projectId.isEmpty || uid.isEmpty) {
      throw Exception('נתוני שיוך חסרים');
    }
    if (!canManage) throw Exception('אין הרשאה לשייך משתמש לפרויקט');
    if (actorUid == uid && role == EnterpriseRole.projectManager) {
      throw Exception('לא ניתן לשדרג את עצמך למנהל פרויקט');
    }
    if (!ProjectAssignmentRoles.isAssignable(role)) {
      throw Exception('תפקיד לא תקין לפרויקט');
    }
    if (orgMembers.isNotEmpty &&
        !orgMembers.any((m) => m.uid == uid && m.status == 'active')) {
      throw Exception('המשתמש אינו חבר פעיל בחברה');
    }
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

final canManageProjectTeamProvider = Provider.family<bool, String>(
  (ref, projectId) {
    final perms = ref.watch(effectivePermissionsProvider);
    if (perms.contains(Permission.manageProjects) ||
        perms.contains(Permission.manageUsers)) {
      return true;
    }
    final uid = ref.watch(authSessionProvider).valueOrNull?.uid;
    if (uid == null) return false;
    final assignments =
        ref.watch(projectAssignmentsProvider(projectId)).valueOrNull ?? const [];
    return assignments.any(
      (a) => a.uid == uid && a.role == EnterpriseRole.projectManager,
    );
  },
);

final projectTeamCountProvider = Provider.family<int, String>((ref, projectId) {
  final assignments =
      ref.watch(projectAssignmentsProvider(projectId)).valueOrNull ?? const [];
  return assignments.length;
});

// Re-export label helper for backward compatibility.
String assignmentRoleLabel(EnterpriseRole role) =>
    ProjectAssignmentRoles.label(role);
