import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../config/app_mode.dart';
import '../models/enterprise/project.dart';
import '../models/enterprise/project_status.dart';
import '../utils/constants.dart';
import '../services/mock_store.dart';

class ProjectRepository {
  ProjectRepository({FirebaseFirestore? firestore}) : _firestore = firestore;

  final FirebaseFirestore? _firestore;
  final _uuid = const Uuid();

  static const deletionGracePeriod = Duration(hours: 24);

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  Stream<List<Project>> watchProjectsForOwner(String ownerUid) {
    if (ownerUid.isEmpty) return Stream.value(const []);
    if (AppMode.isDemoMode) {
      return MockStore.instance.watchProjectsForOwner(ownerUid);
    }

    return _db
        .collection(AppConstants.projectsCollection)
        .where('ownerUid', isEqualTo: ownerUid)
        .snapshots()
        .map((snapshot) => _sortProjects(snapshot.docs
            .map((doc) => Project.fromMap(doc.id, doc.data()))
            .where((p) => !p.isDeleted && p.showOnDashboard)
            .toList()))
        .handleError((Object e, StackTrace st) {
      if (kDebugMode) debugPrint('[ProjectRepository] watch error: $e');
      return const <Project>[];
    });
  }

  Stream<List<Project>> watchDeletionPendingForOwner(String ownerUid) {
    if (ownerUid.isEmpty) return Stream.value(const []);
    if (AppMode.isDemoMode) {
      return MockStore.instance.watchDeletionPendingForOwner(ownerUid);
    }

    return _db
        .collection(AppConstants.projectsCollection)
        .where('ownerUid', isEqualTo: ownerUid)
        .where('status', isEqualTo: ProjectStatus.deletionPending)
        .snapshots()
        .map((snapshot) => _sortProjects(snapshot.docs
            .map((doc) => Project.fromMap(doc.id, doc.data()))
            .where((p) => !p.isDeleted)
            .toList()))
        .handleError((Object e, StackTrace st) {
      if (kDebugMode) {
        debugPrint('[ProjectRepository] deletion watch error: $e');
      }
      return const <Project>[];
    });
  }

  Stream<Project?> watchProject(String projectId) {
    if (projectId.isEmpty) return Stream.value(null);
    if (AppMode.isDemoMode) {
      return MockStore.instance.watchProject(projectId);
    }

    return _db
        .collection(AppConstants.projectsCollection)
        .doc(projectId)
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      final project = Project.fromMap(doc.id, doc.data()!);
      return project.isDeleted ? null : project;
    }).handleError((Object e, StackTrace st) {
      if (kDebugMode) debugPrint('[ProjectRepository] project watch: $e');
      return null;
    });
  }

  Future<Project?> getProject(String projectId) async {
    if (projectId.isEmpty) return null;
    if (AppMode.isDemoMode) {
      return MockStore.instance.getProject(projectId);
    }

    try {
      final doc =
          await _db.collection(AppConstants.projectsCollection).doc(projectId).get();
      if (!doc.exists || doc.data() == null) return null;
      final project = Project.fromMap(doc.id, doc.data()!);
      return project.isDeleted ? null : project;
    } catch (e) {
      if (kDebugMode) debugPrint('[ProjectRepository] getProject: $e');
      return null;
    }
  }

  Future<List<Project>> listProjectsForOwner(String ownerUid) async {
    if (ownerUid.isEmpty) return const [];
    if (AppMode.isDemoMode) {
      return MockStore.instance.listProjectsForOwner(ownerUid);
    }

    try {
      final snapshot = await _db
          .collection(AppConstants.projectsCollection)
          .where('ownerUid', isEqualTo: ownerUid)
          .get();
      return _sortProjects(snapshot.docs
          .map((doc) => Project.fromMap(doc.id, doc.data()))
          .where((p) => !p.isDeleted && p.showOnDashboard)
          .toList());
    } catch (e) {
      if (kDebugMode) debugPrint('[ProjectRepository] list error: $e');
      return const [];
    }
  }

  Future<Project> createProject({
    required String ownerUid,
    required String name,
    String location = '',
    String cityOrArea = '',
    String? notes,
    String? companyName,
    String? orgId,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) throw Exception('יש להזין שם פרויקט');

    if (AppMode.isDemoMode) {
      return MockStore.instance.createProject(
        ownerUid: ownerUid,
        name: trimmedName,
        location: location.trim(),
        cityOrArea: cityOrArea.trim(),
        notes: notes?.trim(),
        companyName: companyName?.trim(),
        orgId: orgId,
      );
    }

    final id = _uuid.v4();
    final now = FieldValue.serverTimestamp();
    final data = <String, dynamic>{
      'ownerUid': ownerUid,
      'name': trimmedName,
      'location': location.trim(),
      'cityOrArea': cityOrArea.trim(),
      if (location.trim().isNotEmpty) 'siteName': location.trim(),
      if (cityOrArea.trim().isNotEmpty) 'city': cityOrArea.trim(),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      if (companyName != null && companyName.trim().isNotEmpty)
        'companyName': companyName.trim(),
      if (orgId != null && orgId.isNotEmpty) 'orgId': orgId,
      'status': ProjectStatus.active,
      'managerUids': <String>[],
      'createdBy': ownerUid,
      'createdAt': now,
      'updatedAt': now,
    };

    await _db.collection(AppConstants.projectsCollection).doc(id).set(data);
    final doc =
        await _db.collection(AppConstants.projectsCollection).doc(id).get();
    return Project.fromMap(doc.id, doc.data()!);
  }

  Future<Project> completeProject({
    required String projectId,
    required String ownerUid,
  }) async {
    if (AppMode.isDemoMode) {
      return MockStore.instance.completeProject(
        projectId: projectId,
        ownerUid: ownerUid,
      );
    }

    final ref = _db.collection(AppConstants.projectsCollection).doc(projectId);
    final snap = await ref.get();
    if (!snap.exists) throw Exception('הפרויקט לא נמצא');
    final project = Project.fromMap(snap.id, snap.data()!);
    if (project.ownerUid != ownerUid) throw Exception('אין הרשאה');
    if (project.isDeletionPending) {
      throw Exception('לא ניתן לסיים פרויקט בזמן מחיקה מתוזמנת');
    }

    await ref.update({
      'status': ProjectStatus.completed,
      'completedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final updated = await ref.get();
    return Project.fromMap(updated.id, updated.data()!);
  }

  Future<Project> requestProjectDeletion({
    required String projectId,
    required String ownerUid,
  }) async {
    if (AppMode.isDemoMode) {
      return MockStore.instance.requestProjectDeletion(
        projectId: projectId,
        ownerUid: ownerUid,
      );
    }

    final ref = _db.collection(AppConstants.projectsCollection).doc(projectId);
    final snap = await ref.get();
    if (!snap.exists) throw Exception('הפרויקט לא נמצא');
    final project = Project.fromMap(snap.id, snap.data()!);
    if (project.ownerUid != ownerUid) throw Exception('אין הרשאה');

    final scheduled = Timestamp.fromDate(
      DateTime.now().add(deletionGracePeriod),
    );

    await ref.update({
      'status': ProjectStatus.deletionPending,
      'statusBeforeDeletion': project.status,
      'deletionRequestedAt': FieldValue.serverTimestamp(),
      'deletionScheduledFor': scheduled,
      'deletionRequestedByUid': ownerUid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final updated = await ref.get();
    return Project.fromMap(updated.id, updated.data()!);
  }

  Future<Project> cancelProjectDeletion({
    required String projectId,
    required String ownerUid,
  }) async {
    if (AppMode.isDemoMode) {
      return MockStore.instance.cancelProjectDeletion(
        projectId: projectId,
        ownerUid: ownerUid,
      );
    }

    final ref = _db.collection(AppConstants.projectsCollection).doc(projectId);
    final snap = await ref.get();
    if (!snap.exists) throw Exception('הפרויקט לא נמצא');
    final project = Project.fromMap(snap.id, snap.data()!);
    if (project.ownerUid != ownerUid) throw Exception('אין הרשאה');
    if (!project.isDeletionPending) throw Exception('הפרויקט לא מתוזמן למחיקה');

    final restoredStatus = project.statusBeforeDeletion ?? ProjectStatus.active;
    await ref.update({
      'status': restoredStatus,
      'statusBeforeDeletion': FieldValue.delete(),
      'deletionRequestedAt': FieldValue.delete(),
      'deletionScheduledFor': FieldValue.delete(),
      'deletionRequestedByUid': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final updated = await ref.get();
    return Project.fromMap(updated.id, updated.data()!);
  }

  Future<void> archiveProject({
    required String projectId,
    required String ownerUid,
  }) async {
    await completeProject(projectId: projectId, ownerUid: ownerUid);
  }

  List<Project> _sortProjects(List<Project> projects) {
    projects.sort((a, b) => a.name.compareTo(b.name));
    return projects;
  }
}
