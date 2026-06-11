import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../config/app_mode.dart';
import '../models/enterprise/enterprise_role.dart';
import '../models/enterprise/membership.dart';
import '../models/enterprise/organization.dart';
import '../services/mock_store.dart';
import '../utils/constants.dart';

/// Organization/membership reads — demo in-memory; Firestore when migrated.
class OrganizationRepository {
  OrganizationRepository({FirebaseFirestore? firestore}) : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  Stream<List<Membership>> watchMembershipsForUser(String uid) {
    if (uid.isEmpty) return Stream.value(const []);
    if (AppMode.isDemoMode) {
      return MockStore.instance.watchMembershipsForUser(uid);
    }
    return Stream.value(const []);
  }

  Future<Organization?> getOrganization(String orgId) async {
    if (orgId.isEmpty || AppMode.isDemoMode) return null;
    try {
      final doc =
          await _db.collection(AppConstants.organizationsCollection).doc(orgId).get();
      if (!doc.exists || doc.data() == null) return null;
      return Organization.fromMap(doc.id, doc.data()!);
    } catch (e) {
      if (kDebugMode) debugPrint('[OrganizationRepository] org load: $e');
      return null;
    }
  }

  Future<Membership> updateMemberRole({
    required String orgId,
    required String memberUid,
    required EnterpriseRole newRole,
    required String actorUid,
  }) async {
    if (AppMode.isDemoMode) {
      return MockStore.instance.updateMemberRole(
        orgId: orgId,
        memberUid: memberUid,
        newRole: newRole,
        actorUid: actorUid,
      );
    }
    throw Exception('שינוי תפקידים יהיה זמין לאחר מיגרציית ארגונים');
  }
}
