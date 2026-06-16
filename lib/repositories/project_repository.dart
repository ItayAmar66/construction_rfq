import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../config/app_mode.dart';
import '../models/enterprise/audit_event.dart';
import '../models/enterprise/enterprise_role.dart';
import '../models/enterprise/membership.dart';
import '../models/enterprise/project.dart';
import '../models/enterprise/project_status.dart';
import '../repositories/audit_repository.dart';
import '../utils/constants.dart';
import '../services/mock_store.dart';

class ProjectRepository {
  ProjectRepository({
    FirebaseFirestore? firestore,
    AuditRepository? auditRepository,
  })  : _firestore = firestore,
        _auditRepository = auditRepository ?? AuditRepository(firestore: firestore);

  final FirebaseFirestore? _firestore;
  final AuditRepository _auditRepository;
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

  Stream<List<Project>> watchAccessibleProjects({
    required String uid,
    required List<Membership> memberships,
  }) {
    if (uid.isEmpty) return Stream.value(const []);
    final active =
        memberships.where((m) => m.status == 'active').toList(growable: false);
    if (AppMode.isDemoMode) {
      return MockStore.instance.watchAccessibleProjects(
        uid: uid,
        memberships: active,
      );
    }

    final orgIds = active.map((m) => m.orgId).where((id) => id.isNotEmpty).toSet();
    final canSeeOrgProjects = active.any(
      (m) =>
          m.hasRole(EnterpriseRole.contractorCompanyOwner) ||
          m.hasRole(EnterpriseRole.procurementManager),
    );

    QuerySnapshot<Map<String, dynamic>>? ownerSnap;
    final orgSnaps = <String, QuerySnapshot<Map<String, dynamic>>>{};
    final assignedProjects = <String, Project>{};

    late StreamController<List<Project>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? ownerSub;
    final orgSubs = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? assignmentSub;

    void publish() {
      if (controller.isClosed) return;
      final byId = <String, Project>{};
      if (ownerSnap != null) {
        for (final doc in ownerSnap!.docs) {
          final project = Project.fromMap(doc.id, doc.data());
          if (!project.isDeleted && project.showOnDashboard) {
            byId[project.id] = project;
          }
        }
      }
      for (final snap in orgSnaps.values) {
        for (final doc in snap.docs) {
          final project = Project.fromMap(doc.id, doc.data());
          if (!project.isDeleted && project.showOnDashboard) {
            byId[project.id] = project;
          }
        }
      }
      byId.addAll(assignedProjects);
      controller.add(_sortProjects(byId.values.toList()));
    }

    Future<void> refreshAssignedProjects(
      QuerySnapshot<Map<String, dynamic>> snap,
    ) async {
      assignedProjects.clear();
      final projectIds = snap.docs
          .map((d) => d.reference.parent.parent?.id)
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet();
      if (projectIds.isEmpty) {
        publish();
        return;
      }
      for (final chunk in _chunk(projectIds.toList(), 10)) {
        final docs = await _db
            .collection(AppConstants.projectsCollection)
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final doc in docs.docs) {
          final project = Project.fromMap(doc.id, doc.data());
          if (!project.isDeleted && project.showOnDashboard) {
            assignedProjects[project.id] = project;
          }
        }
      }
      publish();
    }

    controller = StreamController<List<Project>>(
      onListen: () {
        ownerSub = _db
            .collection(AppConstants.projectsCollection)
            .where('ownerUid', isEqualTo: uid)
            .snapshots()
            .listen((snap) {
          ownerSnap = snap;
          publish();
        });

        if (canSeeOrgProjects) {
          for (final orgId in orgIds) {
            final sub = _db
                .collection(AppConstants.projectsCollection)
                .where('orgId', isEqualTo: orgId)
                .snapshots()
                .listen((snap) {
              orgSnaps[orgId] = snap;
              publish();
            });
            orgSubs.add(sub);
          }
        }

        assignmentSub = _db
            .collectionGroup('assignments')
            .where('uid', isEqualTo: uid)
            .snapshots()
            .listen((snap) {
          unawaited(refreshAssignedProjects(snap));
        });
      },
      onCancel: () async {
        await ownerSub?.cancel();
        for (final sub in orgSubs) {
          await sub.cancel();
        }
        await assignmentSub?.cancel();
      },
    );

    return controller.stream;
  }

  static Iterable<List<T>> _chunk<T>(List<T> items, int size) sync* {
    for (var i = 0; i < items.length; i += size) {
      final end = (i + size) > items.length ? items.length : i + size;
      yield items.sublist(i, end);
    }
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
      final project = MockStore.instance.createProject(
        ownerUid: ownerUid,
        name: trimmedName,
        location: location.trim(),
        cityOrArea: cityOrArea.trim(),
        notes: notes?.trim(),
        companyName: companyName?.trim(),
        orgId: orgId,
      );
      await _auditProject(
        project: project,
        actorUid: ownerUid,
        action: AuditAction.projectCreated,
        summary: 'נוצר פרויקט: ${project.name}',
      );
      return project;
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
    final created = Project.fromMap(doc.id, doc.data()!);
    await _auditProject(
      project: created,
      actorUid: ownerUid,
      action: AuditAction.projectCreated,
      summary: 'נוצר פרויקט: ${created.name}',
    );
    return created;
  }

  Future<Project> completeProject({
    required String projectId,
    required String ownerUid,
  }) async {
    if (AppMode.isDemoMode) {
      final project = MockStore.instance.completeProject(
        projectId: projectId,
        ownerUid: ownerUid,
      );
      await _auditProject(
        project: project,
        actorUid: ownerUid,
        action: AuditAction.projectCompleted,
        summary: 'פרויקט הושלם: ${project.name}',
      );
      return project;
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
    final completed = Project.fromMap(updated.id, updated.data()!);
    await _auditProject(
      project: completed,
      actorUid: ownerUid,
      action: AuditAction.projectCompleted,
      summary: 'פרויקט הושלם: ${completed.name}',
    );
    return completed;
  }

  Future<Project> requestProjectDeletion({
    required String projectId,
    required String ownerUid,
  }) async {
    if (AppMode.isDemoMode) {
      final project = MockStore.instance.requestProjectDeletion(
        projectId: projectId,
        ownerUid: ownerUid,
      );
      await _auditProject(
        project: project,
        actorUid: ownerUid,
        action: AuditAction.projectDeletionRequested,
        summary: 'נדרשה מחיקת פרויקט: ${project.name}',
      );
      return project;
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
    final pending = Project.fromMap(updated.id, updated.data()!);
    await _auditProject(
      project: pending,
      actorUid: ownerUid,
      action: AuditAction.projectDeletionRequested,
      summary: 'נדרשה מחיקת פרויקט: ${pending.name}',
    );
    return pending;
  }

  Future<Project> cancelProjectDeletion({
    required String projectId,
    required String ownerUid,
  }) async {
    if (AppMode.isDemoMode) {
      final project = MockStore.instance.cancelProjectDeletion(
        projectId: projectId,
        ownerUid: ownerUid,
      );
      await _auditProject(
        project: project,
        actorUid: ownerUid,
        action: AuditAction.projectDeletionCancelled,
        summary: 'בוטלה מחיקת פרויקט: ${project.name}',
      );
      return project;
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
    final restored = Project.fromMap(updated.id, updated.data()!);
    await _auditProject(
      project: restored,
      actorUid: ownerUid,
      action: AuditAction.projectDeletionCancelled,
      summary: 'בוטלה מחיקת פרויקט: ${restored.name}',
    );
    return restored;
  }

  Future<void> _auditProject({
    required Project project,
    required String actorUid,
    required String action,
    required String summary,
  }) async {
    await AuditLogger.record(
      repository: _auditRepository,
      actorUid: actorUid,
      orgId: project.orgId,
      projectId: project.id,
      entityType: AuditEntityType.project,
      entityId: project.id,
      action: action,
      summaryHebrew: summary,
    );
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
