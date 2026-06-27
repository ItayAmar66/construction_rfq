import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../config/app_mode.dart';
import '../models/access_request.dart';
import '../models/enterprise/organization_type.dart';
import '../utils/constants.dart';

class AccessRequestRepository {
  AccessRequestRepository({FirebaseFirestore? firestore}) : _firestore = firestore;

  final FirebaseFirestore? _firestore;
  static final _demoRequests = <String, AccessRequest>{};

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection(AppConstants.accessRequestsCollection);

  Future<void> createPendingRequest(AccessRequest request) async {
    if (AppMode.isDemoMode) {
      _demoRequests[request.uid] = request;
      return;
    }
    await _collection.doc(request.uid).set({
      ...request.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<AccessRequest>> fetchPendingForOrg(String orgId) async {
    if (orgId.isEmpty) return const [];
    if (AppMode.isDemoMode) {
      return _demoRequests.values
          .where((r) => r.isPending && r.requestedOrgId == orgId)
          .toList()
        ..sort((a, b) => (b.createdAt ?? DateTime(2000))
            .compareTo(a.createdAt ?? DateTime(2000)));
    }
    try {
      final snap = await _collection
          .where('status', isEqualTo: 'pending')
          .where('requestedOrgId', isEqualTo: orgId)
          .orderBy('createdAt', descending: true)
          .get();
      return snap.docs
          .map((d) => AccessRequest.fromMap(d.id, d.data()))
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('[AccessRequestRepo] org pending $e');
      rethrow;
    }
  }

  Future<List<AccessRequest>> fetchAllPending() async {
    if (AppMode.isDemoMode) {
      return _demoRequests.values.where((r) => r.isPending).toList()
        ..sort((a, b) => (b.createdAt ?? DateTime(2000))
            .compareTo(a.createdAt ?? DateTime(2000)));
    }
    final snap = await _collection
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();
    return snap.docs.map((d) => AccessRequest.fromMap(d.id, d.data())).toList();
  }

  Future<void> resolveRequest({
    required String uid,
    required String status,
    required String actorUid,
  }) async {
    if (AppMode.isDemoMode) {
      final existing = _demoRequests[uid];
      if (existing == null) return;
      _demoRequests[uid] = AccessRequest(
        uid: existing.uid,
        email: existing.email,
        fullName: existing.fullName,
        userType: existing.userType,
        requestedOrgType: existing.requestedOrgType,
        requestedOrgId: existing.requestedOrgId,
        requestedOrgName: existing.requestedOrgName,
        requestedRole: existing.requestedRole,
        requestedProjectName: existing.requestedProjectName,
        status: status,
        createdAt: existing.createdAt,
        updatedAt: DateTime.now(),
        resolvedByUid: actorUid,
      );
      return;
    }
    await _collection.doc(uid).update({
      'status': status,
      'resolvedByUid': actorUid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String?> resolveOrgIdByName({
    required String companyName,
    required OrganizationType type,
  }) async {
    final trimmed = companyName.trim();
    if (trimmed.isEmpty) return null;
    if (AppMode.isDemoMode) return null;

    final snap = await _db
        .collection(AppConstants.organizationsCollection)
        .where('type', isEqualTo: type.value)
        .where('status', isEqualTo: 'active')
        .get();
    for (final doc in snap.docs) {
      final name = doc.data()['name']?.toString().trim() ?? '';
      if (name == trimmed) return doc.id;
    }
    return null;
  }

  static void resetDemo() => _demoRequests.clear();
}
