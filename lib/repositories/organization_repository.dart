import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../config/app_mode.dart';
import '../models/enterprise/audit_event.dart';
import '../models/enterprise/enterprise_role.dart';
import '../models/enterprise/membership.dart';
import '../models/enterprise/organization.dart';
import '../models/enterprise/organization_type.dart';
import '../repositories/audit_repository.dart';
import '../services/mock_store.dart';
import '../utils/constants.dart';
import '../utils/enterprise_role_labels.dart';
import '../utils/firestore_parsing.dart';
import '../utils/membership_role_update_errors.dart';
import '../utils/user_org_id_resolver.dart';

/// Organization/membership reads.
/// Demo mode: in-memory MockStore.
/// Production: direct organizations/{orgId}/memberships/{uid} reads (primary).
class OrganizationRepository {
  OrganizationRepository({
    FirebaseFirestore? firestore,
    AuditRepository? auditRepository,
  })  : _firestore = firestore,
        _auditRepository = auditRepository ?? AuditRepository(firestore: firestore);

  final FirebaseFirestore? _firestore;
  final AuditRepository _auditRepository;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _orgs =>
      _db.collection(AppConstants.organizationsCollection);

  DocumentReference<Map<String, dynamic>> _membershipRef(
    String orgId,
    String uid,
  ) =>
      _orgs
          .doc(orgId)
          .collection(AppConstants.membershipsSubcollection)
          .doc(uid);

  // ── User-scoped reads ──────────────────────────────────────────────────

  Stream<List<Membership>> watchMembershipsForUser(String uid) {
    if (uid.isEmpty) return Stream.value(const []);
    if (AppMode.isDemoMode) {
      return MockStore.instance.watchMembershipsForUser(uid);
    }

    final membershipsById = <String, Membership>{};
    final directSubs = <String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>{};
    var collectionGroupLogged = false;

    late StreamController<List<Membership>> controller;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? userSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? groupSub;
    Timer? groupFallbackTimer;
    Timer? bootstrapTimer;
    var collectionGroupStarted = false;

    void publish() {
      if (controller.isClosed) return;
      if (membershipsById.isNotEmpty) {
        groupFallbackTimer?.cancel();
        bootstrapTimer?.cancel();
      }
      controller.add(membershipsById.values.toList(growable: false));
    }

    void upsert(Membership membership) {
      membershipsById[membership.id] = membership;
      publish();
    }

    void startCollectionGroupFallback() {
      if (collectionGroupStarted || controller.isClosed) return;
      collectionGroupStarted = true;
      groupSub = _db
          .collectionGroup(AppConstants.membershipsSubcollection)
          .where('uid', isEqualTo: uid)
          .snapshots()
          .listen(
        (snap) {
          if (snap.docs.isEmpty) {
            publish();
            return;
          }
          for (final doc in snap.docs) {
            final data = doc.data();
            upsert(
              Membership.fromMap(
                FirestoreParsing.parseString(
                  data['uid'],
                  defaultValue: doc.id,
                ),
                data,
              ),
            );
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (kDebugMode && !collectionGroupLogged) {
            collectionGroupLogged = true;
            debugPrint(
              '[OrgRepo] collectionGroup unavailable; using direct membership reads',
            );
          }
        },
      );
    }

    void scheduleCollectionGroupFallback() {
      groupFallbackTimer?.cancel();
      groupFallbackTimer = Timer(const Duration(milliseconds: 700), () {
        if (!controller.isClosed && membershipsById.isEmpty) {
          startCollectionGroupFallback();
        }
      });
    }

    void removeMembership(String orgId, String memberUid) {
      final id = '${orgId}_$memberUid';
      membershipsById.remove(id);
      publish();
    }

    void bindDirectOrg(String orgId) {
      if (orgId.isEmpty || directSubs.containsKey(orgId)) return;
      directSubs[orgId] = _membershipRef(orgId, uid).snapshots().listen(
        (snap) {
          if (!snap.exists || snap.data() == null) {
            removeMembership(orgId, uid);
            return;
          }
          upsert(Membership.fromMap(snap.id, snap.data()!));
        },
        onError: (Object error, StackTrace stackTrace) {
          if (kDebugMode && !collectionGroupLogged) {
            debugPrint('[OrgRepo] direct membership read failed for $orgId: $error');
          }
        },
      );
    }

    void syncOrgCandidates(Set<String> candidates) {
      for (final orgId in candidates) {
        bindDirectOrg(orgId);
      }
    }

    controller = StreamController<List<Membership>>(
      onListen: () {
        publish();

        bindDirectOrg(uid);

        userSub = _db
            .collection(AppConstants.usersCollection)
            .doc(uid)
            .snapshots()
            .listen(
          (snap) {
            syncOrgCandidates(
              UserOrgIdResolver.candidateOrgIds(
                uid: uid,
                profile: snap.data(),
              ),
            );
            scheduleCollectionGroupFallback();
          },
          onError: (Object error, StackTrace stackTrace) {
            if (kDebugMode && !collectionGroupLogged) {
              collectionGroupLogged = true;
              debugPrint(
                '[OrgRepo] user profile watch unavailable; using direct membership reads',
              );
            }
            syncOrgCandidates({uid});
            scheduleCollectionGroupFallback();
          },
        );

        bootstrapTimer = Timer(const Duration(seconds: 10), () {
          if (!controller.isClosed) publish();
        });
      },
      onCancel: () async {
        groupFallbackTimer?.cancel();
        bootstrapTimer?.cancel();
        await userSub?.cancel();
        await groupSub?.cancel();
        for (final sub in directSubs.values) {
          await sub.cancel();
        }
        directSubs.clear();
      },
    );

    return controller.stream;
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
    String? actorEmail,
    String? actorName,
  }) async {
    final members = await _loadOrgMembers(orgId);
    final existing = members.where((m) => m.uid == memberUid).firstOrNull;
    final previousRole = existing?.roles.firstOrNull;
    _validateRoleUpdate(
      orgType: orgType,
      newRole: newRole,
      actorUid: actorUid,
      memberUid: memberUid,
      members: members,
    );
    Membership updated;
    if (AppMode.isDemoMode) {
      updated = MockStore.instance.updateMemberRole(
        orgId: orgId,
        memberUid: memberUid,
        newRole: newRole,
        actorUid: actorUid,
      );
    } else {
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
      updated = Membership.fromMap(snap.id, snap.data()!);
    }
    await AuditLogger.record(
      repository: _auditRepository,
      actorUid: actorUid,
      actorEmail: actorEmail,
      actorName: actorName,
      orgId: orgId,
      orgType: orgType,
      entityType: AuditEntityType.membership,
      entityId: memberUid,
      action: AuditAction.roleChanged,
      summaryHebrew: previousRole != null
          ? 'שינוי תפקיד מ-${EnterpriseRoleLabels.hebrew(previousRole)} ל-${EnterpriseRoleLabels.hebrew(newRole)}'
          : 'שינוי תפקיד ל-${EnterpriseRoleLabels.hebrew(newRole)}',
      metadata: {
        'previousRole': previousRole?.value ?? '',
        'newRole': newRole.value,
      },
    );
    return updated;
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
