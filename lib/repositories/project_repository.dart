import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../config/app_mode.dart';
import '../models/enterprise/audit_event.dart';
import '../models/enterprise/membership.dart';
import '../models/enterprise/project.dart';
import '../models/enterprise/project_status.dart';
import '../repositories/audit_repository.dart';
import '../utils/constants.dart';
import '../utils/project_access_policy.dart';
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

  Stream<List<Project>> watchAccessibleProjectsForUser(
    String uid,
    Stream<List<Membership>> membershipsStream,
  ) {
    if (uid.isEmpty) return Stream.value(const []);

    late StreamController<List<Project>> controller;
    StreamSubscription<List<Project>>? projectsSub;
    StreamSubscription<List<Membership>>? membershipsSub;

    controller = StreamController<List<Project>>(
      onListen: () {
        membershipsSub = membershipsStream.listen(
          (memberships) {
            projectsSub?.cancel();
            projectsSub = watchAccessibleProjects(
              uid: uid,
              memberships: memberships,
            ).listen(
              controller.add,
              onError: controller.addError,
            );
          },
          onError: controller.addError,
        );
      },
      onCancel: () async {
        await membershipsSub?.cancel();
        membershipsSub = null;
        await projectsSub?.cancel();
        projectsSub = null;
      },
    );

    return controller.stream;
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

    final orgIds = ProjectAccessPolicy.activeOrgIds(active);
    final membershipProjectIds = ProjectAccessPolicy.assignedProjectIds(active);

    QuerySnapshot<Map<String, dynamic>>? ownerSnap;
    final orgIdSnaps = <String, QuerySnapshot<Map<String, dynamic>>>{};
    final ownerOrgSnaps = <String, QuerySnapshot<Map<String, dynamic>>>{};
    final directProjects = <String, Project>{};
    final assignmentProjects = <String, Project>{};

    late StreamController<List<Project>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? ownerSub;
    final orgIdSubs = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
    final ownerOrgSubs = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
    final directProjectSubs =
        <String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>{};
    final assignmentSubs =
        <String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>{};
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? assignmentGroupSub;
    var assignmentGroupLogged = false;
    var publishScheduled = false;
    var disposed = false;

    void publish() {
      if (controller.isClosed) return;
      if (publishScheduled) return;
      publishScheduled = true;
      scheduleMicrotask(() {
        publishScheduled = false;
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
        for (final snap in orgIdSnaps.values.toList(growable: false)) {
          for (final doc in snap.docs) {
            final project = Project.fromMap(doc.id, doc.data());
            if (!project.isDeleted && project.showOnDashboard) {
              byId[project.id] = project;
            }
          }
        }
        for (final snap in ownerOrgSnaps.values.toList(growable: false)) {
          for (final doc in snap.docs) {
            final project = Project.fromMap(doc.id, doc.data());
            if (!project.isDeleted && project.showOnDashboard) {
              byId[project.id] = project;
            }
          }
        }
        byId.addAll(directProjects);
        byId.addAll(assignmentProjects);
        controller.add(_sortProjects(byId.values.toList(growable: false)));
      });
    }

    void bindDirectProject(String projectId) {
      if (disposed || projectId.isEmpty || directProjectSubs.containsKey(projectId)) {
        return;
      }
      directProjectSubs[projectId] = _db
          .collection(AppConstants.projectsCollection)
          .doc(projectId)
          .snapshots()
          .listen(
        (snap) {
          if (snap.exists && snap.data() != null) {
            final project = Project.fromMap(snap.id, snap.data()!);
            if (!project.isDeleted && project.showOnDashboard) {
              directProjects[project.id] = project;
            } else {
              directProjects.remove(project.id);
            }
          } else {
            directProjects.remove(projectId);
          }
          publish();
        },
        onError: (Object error, StackTrace stackTrace) {
          if (kDebugMode) {
            debugPrint('[ProjectRepository] direct project $projectId: $error');
          }
        },
      );
    }

    void bindAssignmentDoc(String projectId) {
      if (disposed || projectId.isEmpty || assignmentSubs.containsKey(projectId)) {
        return;
      }
      assignmentSubs[projectId] = _assignments(projectId, uid).snapshots().listen(
        (snap) async {
          if (snap.exists && snap.data() != null) {
            try {
              final projectDoc = await _db
                  .collection(AppConstants.projectsCollection)
                  .doc(projectId)
                  .get();
              if (projectDoc.exists && projectDoc.data() != null) {
                final project = Project.fromMap(projectDoc.id, projectDoc.data()!);
                if (!project.isDeleted && project.showOnDashboard) {
                  assignmentProjects[project.id] = project;
                } else {
                  assignmentProjects.remove(projectId);
                }
              }
            } catch (e) {
              if (kDebugMode) {
                debugPrint('[ProjectRepository] assignment project $projectId: $e');
              }
            }
          } else {
            assignmentProjects.remove(projectId);
          }
          publish();
        },
        onError: (Object error, StackTrace stackTrace) {
          if (kDebugMode) {
            debugPrint('[ProjectRepository] assignment doc $projectId: $error');
          }
        },
      );
    }

    Future<void> mergeAssignmentGroup(
      QuerySnapshot<Map<String, dynamic>> snap,
    ) async {
      assignmentProjects.clear();
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
            assignmentProjects[project.id] = project;
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

        for (final orgId in orgIds) {
          orgIdSubs.add(
            _db
                .collection(AppConstants.projectsCollection)
                .where('orgId', isEqualTo: orgId)
                .snapshots()
                .listen(
              (snap) {
                orgIdSnaps[orgId] = snap;
                publish();
              },
              onError: (Object error, StackTrace stackTrace) {
                if (kDebugMode) {
                  debugPrint(
                    '[ProjectRepository] orgId project query unavailable for $orgId ($error)',
                  );
                }
              },
            ),
          );
          ownerOrgSubs.add(
            _db
                .collection(AppConstants.projectsCollection)
                .where('ownerUid', isEqualTo: orgId)
                .snapshots()
                .listen(
              (snap) {
                ownerOrgSnaps[orgId] = snap;
                publish();
              },
              onError: (Object error, StackTrace stackTrace) {
                if (kDebugMode) {
                  debugPrint(
                    '[ProjectRepository] ownerUid org query unavailable for $orgId ($error)',
                  );
                }
              },
            ),
          );
        }

        for (final projectId in membershipProjectIds) {
          bindDirectProject(projectId);
          bindAssignmentDoc(projectId);
        }

        assignmentGroupSub = _db
            .collectionGroup('assignments')
            .where('uid', isEqualTo: uid)
            .snapshots()
            .listen(
          (snap) => unawaited(mergeAssignmentGroup(snap)),
          onError: (Object error, StackTrace stackTrace) {
            if (kDebugMode && !assignmentGroupLogged) {
              assignmentGroupLogged = true;
              debugPrint(
                '[ProjectRepository] assignment collectionGroup unavailable; using org/direct reads ($error)',
              );
            }
          },
        );
      },
      onCancel: () async {
        disposed = true;
        final directSubs = directProjectSubs.values.toList(growable: false);
        directProjectSubs.clear();
        final assignSubs = assignmentSubs.values.toList(growable: false);
        assignmentSubs.clear();
        await ownerSub?.cancel();
        ownerSub = null;
        for (final sub in orgIdSubs.toList(growable: false)) {
          await sub.cancel();
        }
        orgIdSubs.clear();
        for (final sub in ownerOrgSubs.toList(growable: false)) {
          await sub.cancel();
        }
        ownerOrgSubs.clear();
        for (final sub in directSubs) {
          await sub.cancel();
        }
        for (final sub in assignSubs) {
          await sub.cancel();
        }
        await assignmentGroupSub?.cancel();
        assignmentGroupSub = null;
      },
    );

    return controller.stream;
  }

  DocumentReference<Map<String, dynamic>> _assignments(
    String projectId,
    String assignUid,
  ) =>
      _db
          .collection(AppConstants.projectsCollection)
          .doc(projectId)
          .collection('assignments')
          .doc(assignUid);

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
