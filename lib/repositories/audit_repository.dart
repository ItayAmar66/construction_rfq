import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../config/app_mode.dart';
import '../models/enterprise/audit_event.dart';
import '../models/enterprise/organization_type.dart';
import '../services/mock_store.dart';
import '../utils/constants.dart';

class AuditRepository {
  AuditRepository({FirebaseFirestore? firestore}) : _firestore = firestore;

  final FirebaseFirestore? _firestore;
  static const _uuid = Uuid();

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _events =>
      _db.collection(AppConstants.auditEventsCollection);

  Future<AuditEvent> createEvent(AuditEvent event) async {
    if (AppMode.isDemoMode) {
      return MockStore.instance.createAuditEvent(event);
    }
    await _events.doc(event.id).set({
      ...event.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return event;
  }

  Stream<List<AuditEvent>> watchOrgEvents(String orgId, {int limit = 50}) {
    if (orgId.isEmpty) return Stream.value(const []);
    if (AppMode.isDemoMode) {
      return MockStore.instance.watchOrgAuditEvents(orgId, limit: limit);
    }
    return _events
        .where('orgId', isEqualTo: orgId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => AuditEvent.fromMap(d.id, d.data()))
            .toList())
        .handleError((e) {
      if (kDebugMode) debugPrint('[AuditRepo] org: $e');
      return <AuditEvent>[];
    });
  }

  Stream<List<AuditEvent>> watchProjectEvents(
    String projectId, {
    int limit = 30,
  }) {
    if (projectId.isEmpty) return Stream.value(const []);
    if (AppMode.isDemoMode) {
      return MockStore.instance.watchProjectAuditEvents(projectId, limit: limit);
    }
    return _events
        .where('projectId', isEqualTo: projectId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => AuditEvent.fromMap(d.id, d.data()))
            .toList())
        .handleError((e) {
      if (kDebugMode) debugPrint('[AuditRepo] project: $e');
      return <AuditEvent>[];
    });
  }

  Stream<List<AuditEvent>> watchAdminEvents({int limit = 50}) {
    if (AppMode.isDemoMode) {
      return MockStore.instance.watchAdminAuditEvents(limit: limit);
    }
    return _events
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => AuditEvent.fromMap(d.id, d.data()))
            .toList())
        .handleError((e) {
      if (kDebugMode) debugPrint('[AuditRepo] admin: $e');
      return <AuditEvent>[];
    });
  }
}

/// Fire-and-forget audit helper — never blocks main user actions.
abstract final class AuditLogger {
  static Future<void> record({
    required AuditRepository repository,
    required String actorUid,
    String? actorEmail,
    String? actorName,
    String? orgId,
    OrganizationType? orgType,
    String? projectId,
    required String entityType,
    required String entityId,
    required String action,
    required String summaryHebrew,
    Map<String, String> metadata = const {},
  }) async {
    try {
      final event = AuditEvent(
        id: const Uuid().v4(),
        actorUid: actorUid,
        actorEmail: actorEmail,
        actorName: actorName,
        orgId: orgId,
        orgType: orgType,
        projectId: projectId,
        entityType: entityType,
        entityId: entityId,
        action: action,
        summaryHebrew: summaryHebrew,
        metadata: metadata,
        createdAt: DateTime.now(),
      );
      await repository.createEvent(event);
    } catch (e) {
      if (kDebugMode) debugPrint('[AuditLogger] failed: $e');
    }
  }
}

final auditRepositoryProvider = Provider<AuditRepository>(
  (ref) => AuditRepository(),
);

final orgAuditEventsProvider =
    StreamProvider.family<List<AuditEvent>, String>((ref, orgId) {
  if (orgId.isEmpty) return Stream.value(const []);
  return ref.watch(auditRepositoryProvider).watchOrgEvents(orgId);
});

final projectAuditEventsProvider =
    StreamProvider.family<List<AuditEvent>, String>((ref, projectId) {
  if (projectId.isEmpty) return Stream.value(const []);
  return ref.watch(auditRepositoryProvider).watchProjectEvents(projectId);
});

final adminAuditEventsProvider = StreamProvider<List<AuditEvent>>((ref) {
  return ref.watch(auditRepositoryProvider).watchAdminEvents();
});
