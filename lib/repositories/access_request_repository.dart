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
      return _sortNewestFirst(
        _demoRequests.values
            .where((r) => r.isPending && r.requestedOrgId == orgId)
            .toList(),
      );
    }
    try {
      final snap = await _collection
          .where('status', isEqualTo: 'pending')
          .where('requestedOrgId', isEqualTo: orgId)
          .get();
      return _sortNewestFirst(
        snap.docs.map((d) => AccessRequest.fromMap(d.id, d.data())).toList(),
      );
    } on FirebaseException catch (e) {
      if (kDebugMode) {
        debugPrint('[AccessRequestRepo] org pending ${e.code}: ${e.message}');
      }
      if (_isBenignEmptyQueryError(e)) return const [];
      rethrow;
    } catch (e) {
      if (kDebugMode) debugPrint('[AccessRequestRepo] org pending $e');
      rethrow;
    }
  }

  Future<List<AccessRequest>> fetchAllPending() async {
    if (AppMode.isDemoMode) {
      return _sortNewestFirst(
        _demoRequests.values.where((r) => r.isPending).toList(),
      );
    }
    try {
      final snap = await _collection
          .where('status', isEqualTo: 'pending')
          .limit(50)
          .get();
      return _sortNewestFirst(
        snap.docs.map((d) => AccessRequest.fromMap(d.id, d.data())).toList(),
      );
    } on FirebaseException catch (e) {
      if (kDebugMode) {
        debugPrint('[AccessRequestRepo] all pending ${e.code}: ${e.message}');
      }
      if (_isBenignEmptyQueryError(e)) return const [];
      rethrow;
    } catch (e) {
      if (kDebugMode) debugPrint('[AccessRequestRepo] all pending $e');
      rethrow;
    }
  }

  static List<AccessRequest> _sortNewestFirst(List<AccessRequest> requests) {
    return requests
      ..sort((a, b) => (b.createdAt ?? DateTime(2000))
          .compareTo(a.createdAt ?? DateTime(2000)));
  }

  static bool _isBenignEmptyQueryError(FirebaseException e) {
    return e.code == 'permission-denied' && e.message?.contains('false') == true;
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
