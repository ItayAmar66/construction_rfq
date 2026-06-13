import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../config/app_mode.dart';
import '../models/enterprise/enterprise_role.dart';
import '../models/enterprise/membership.dart';
import '../models/enterprise/organization.dart';
import '../models/enterprise/organization_type.dart';
import '../services/mock_store.dart';
import '../utils/constants.dart';

/// Organization/membership reads.
/// Demo mode: in-memory MockStore.
/// Production: Firestore organizations/{orgId}/memberships/{uid}.
class OrganizationRepository {
  OrganizationRepository({FirebaseFirestore? firestore})
      : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _orgs =>
      _db.collection(AppConstants.organizationsCollection);

  // ── User-scoped reads ──────────────────────────────────────────────────

  Stream<List<Membership>> watchMembershipsForUser(String uid) {
    if (uid.isEmpty) return Stream.value(const []);
    if (AppMode.isDemoMode) {
      return MockStore.instance.watchMembershipsForUser(uid);
    }
    return _db
        .collectionGroup(AppConstants.membershipsSubcollection)
        .where('uid', isEqualTo: uid)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => Membership.fromMap(d.id, d.data()))
              .toList(),
        )
        .handleError((e) {
      if (kDebugMode) debugPrint('[OrgRepo] watchMembershipsForUser: $e');
      return <Membership>[];
    });
  }

  // ── Org-scoped reads ───────────────────────────────────────────────────

  Stream<List<Membership>> watchMembershipsForOrg(String orgId) {
    if (orgId.isEmpty) return Stream.value(const []);
    if (AppMode.isDemoMode) {
      return MockStore.instance.watchMembershipsForOrg(orgId);
    }
    return _orgs
        .doc(orgId)
        .collection(AppConstants.membershipsSubcollection)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => Membership.fromMap(d.id, d.data()))
              .toList(),
        )
        .handleError((e) {
      if (kDebugMode) debugPrint('[OrgRepo] watchMembershipsForOrg: $e');
      return <Membership>[];
    });
  }

  Future<Organization?> getOrganization(String orgId) async {
    if (orgId.isEmpty || AppMode.isDemoMode) return null;
    try {
      final doc = await _orgs.doc(orgId).get();
      if (!doc.exists || doc.data() == null) return null;
      return Organization.fromMap(doc.id, doc.data()!);
    } catch (e) {
      if (kDebugMode) debugPrint('[OrgRepo] getOrganization: $e');
      return null;
    }
  }

  // ── Role updates ───────────────────────────────────────────────────────

  Future<Membership> updateMemberRole({
    required String orgId,
    required String memberUid,
    required EnterpriseRole newRole,
    required String actorUid,
    OrganizationType orgType = OrganizationType.contractor,
  }) async {
    // Client-side guardrails run in all modes.
    _validateRoleUpdate(
      orgType: orgType,
      newRole: newRole,
      actorUid: actorUid,
      memberUid: memberUid,
    );
    if (AppMode.isDemoMode) {
      return MockStore.instance.updateMemberRole(
        orgId: orgId,
        memberUid: memberUid,
        newRole: newRole,
        actorUid: actorUid,
      );
    }
    final memberRef = _orgs
        .doc(orgId)
        .collection(AppConstants.membershipsSubcollection)
        .doc(memberUid);
    await memberRef.update({
      'roles': [newRole.value],
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedByUid': actorUid,
    });
    final snap = await memberRef.get();
    return Membership.fromMap(snap.id, snap.data()!);
  }

  // ── Client-side guardrails ─────────────────────────────────────────────

  static void _validateRoleUpdate({
    required OrganizationType orgType,
    required EnterpriseRole newRole,
    required String actorUid,
    required String memberUid,
  }) {
    if (newRole == EnterpriseRole.platformAdmin) {
      throw Exception(
          'לא ניתן להקצות תפקיד מנהל מערכת דרך ניהול חברה');
    }
    if (actorUid == memberUid &&
        newRole == _ownerRoleFor(orgType)) {
      throw Exception('לא ניתן לשדרג את עצמך לתפקיד המנהל');
    }
    final allowedRoles = orgType == OrganizationType.supplier
        ? EnterpriseRole.values.where((r) => r.isSupplierRole).toList()
        : EnterpriseRole.values.where((r) => r.isContractorRole).toList();
    if (!allowedRoles.contains(newRole)) {
      throw Exception('תפקיד לא תואם לסוג הארגון');
    }
  }

  static EnterpriseRole _ownerRoleFor(OrganizationType type) =>
      type == OrganizationType.supplier
          ? EnterpriseRole.supplierOwner
          : EnterpriseRole.contractorCompanyOwner;
}
