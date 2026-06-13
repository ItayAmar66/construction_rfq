import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../config/app_mode.dart';
import '../models/enterprise/enterprise_role.dart';
import '../models/enterprise/membership.dart';
import '../models/enterprise/organization.dart';
import '../models/enterprise/organization_type.dart';
import '../services/mock_store.dart';
import '../utils/constants.dart';
import '../utils/membership_role_update_errors.dart';

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
          (snap) =>
              snap.docs.map((d) => Membership.fromMap(d.id, d.data())).toList(),
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
          (snap) =>
              snap.docs.map((d) => Membership.fromMap(d.id, d.data())).toList(),
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
    final members = await _loadOrgMembers(orgId);
    _validateRoleUpdate(
      orgType: orgType,
      newRole: newRole,
      actorUid: actorUid,
      memberUid: memberUid,
      members: members,
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
    try {
      await memberRef.update({
        'roles': [newRole.value],
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedByUid': actorUid,
      });
    } on FirebaseException catch (e) {
      throw Exception(MembershipRoleUpdateErrors.userMessage(e));
    }
    final snap = await memberRef.get();
    return Membership.fromMap(snap.id, snap.data()!);
  }

  Future<List<Membership>> _loadOrgMembers(String orgId) async {
    if (AppMode.isDemoMode) {
      return MockStore.instance.membershipsForOrg(orgId);
    }
    final snap = await _orgs
        .doc(orgId)
        .collection(AppConstants.membershipsSubcollection)
        .get();
    return snap.docs.map((d) => Membership.fromMap(d.id, d.data())).toList();
  }

  // ── Client-side guardrails ─────────────────────────────────────────────

  static void _validateRoleUpdate({
    required OrganizationType orgType,
    required EnterpriseRole newRole,
    required String actorUid,
    required String memberUid,
    required List<Membership> members,
  }) {
    if (actorUid == memberUid) {
      throw Exception(MembershipRoleUpdateErrors.selfChangeBlocked);
    }
    if (newRole == EnterpriseRole.platformAdmin) {
      throw Exception(MembershipRoleUpdateErrors.platformAdminBlocked);
    }
    final allowedRoles = orgType == OrganizationType.supplier
        ? EnterpriseRole.values.where((r) => r.isSupplierRole).toList()
        : EnterpriseRole.values.where((r) => r.isContractorRole).toList();
    if (!allowedRoles.contains(newRole)) {
      throw Exception(MembershipRoleUpdateErrors.wrongOrgRole);
    }
    _validateLastOwner(
      members: members,
      memberUid: memberUid,
      newRole: newRole,
      orgType: orgType,
    );
  }

  static void _validateLastOwner({
    required List<Membership> members,
    required String memberUid,
    required EnterpriseRole newRole,
    required OrganizationType orgType,
  }) {
    final ownerRole = _ownerRoleFor(orgType);
    if (newRole == ownerRole) return;
    Membership? target;
    for (final m in members) {
      if (m.uid == memberUid) {
        target = m;
        break;
      }
    }
    if (target == null || !target.hasRole(ownerRole)) return;
    final ownerCount =
        members.where((m) => m.hasRole(ownerRole)).length;
    if (ownerCount <= 1) {
      throw Exception(MembershipRoleUpdateErrors.lastOwnerBlocked);
    }
  }

  static EnterpriseRole _ownerRoleFor(OrganizationType type) =>
      type == OrganizationType.supplier
          ? EnterpriseRole.supplierOwner
          : EnterpriseRole.contractorCompanyOwner;
}
