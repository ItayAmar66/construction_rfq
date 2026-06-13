import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../config/app_mode.dart';
import '../models/account_status.dart';
import '../models/app_user.dart';
import '../models/enterprise/audit_event.dart';
import '../models/enterprise/enterprise_role.dart';
import '../models/enterprise/organization_type.dart';
import '../models/user_type.dart';
import '../repositories/audit_repository.dart';
import '../repositories/audit_repository.dart';
import '../services/organization_bootstrap_service.dart';
import '../utils/constants.dart';

/// Platform-admin actions to approve pending company/supplier managers.
class AdminApprovalService {
  AdminApprovalService({
    FirebaseFirestore? firestore,
    AuditRepository? auditRepository,
  })  : _firestore = firestore,
        _auditRepository = auditRepository ?? AuditRepository(firestore: firestore);

  final FirebaseFirestore? _firestore;
  final AuditRepository _auditRepository;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  Future<void> approveContractorManager({
    required AppUser user,
    required String actorUid,
    String? actorName,
    String? actorEmail,
  }) async {
    await _approveManager(
      user: user,
      actorUid: actorUid,
      actorName: actorName,
      actorEmail: actorEmail,
      orgType: OrganizationType.contractor,
      ownerRole: EnterpriseRole.contractorCompanyOwner,
      auditAction: AuditAction.adminApprovedContractorManager,
      summary: 'אושר כמנהל חברה קבלן',
    );
  }

  Future<void> approveSupplierManager({
    required AppUser user,
    required String actorUid,
    String? actorName,
    String? actorEmail,
  }) async {
    await _approveManager(
      user: user,
      actorUid: actorUid,
      actorName: actorName,
      actorEmail: actorEmail,
      orgType: OrganizationType.supplier,
      ownerRole: EnterpriseRole.supplierOwner,
      auditAction: AuditAction.adminApprovedSupplierManager,
      summary: 'אושר כמנהל ספק',
    );
  }

  Future<void> blockUser({
    required String uid,
    required String actorUid,
  }) async {
    if (AppMode.isDemoMode) return;
    await _db.collection(AppConstants.usersCollection).doc(uid).update({
      'accountStatus': AccountStatus.blocked.value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _approveManager({
    required AppUser user,
    required String actorUid,
    String? actorName,
    String? actorEmail,
    required OrganizationType orgType,
    required EnterpriseRole ownerRole,
    required String auditAction,
    required String summary,
  }) async {
    if (AppMode.isDemoMode) return;

    final orgId = user.id;
    final orgRef = _db.collection(AppConstants.organizationsCollection).doc(orgId);
    final memberRef = orgRef
        .collection(AppConstants.membershipsSubcollection)
        .doc(user.id);

    await _db.runTransaction((tx) async {
      final orgSnap = await tx.get(orgRef);
      if (!orgSnap.exists) {
        tx.set(orgRef, {
          'type': orgType.value,
          'name': user.fullName.trim().isEmpty ? user.email : user.fullName.trim(),
          'ownerUid': user.id,
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        tx.update(orgRef, {
          'status': 'active',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      tx.set(memberRef, {
        'uid': user.id,
        'orgId': orgId,
        'orgType': orgType.value,
        'roles': [ownerRole.value],
        'status': 'active',
        'createdBy': actorUid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      tx.update(_db.collection(AppConstants.usersCollection).doc(user.id), {
        'accountStatus': AccountStatus.active.value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    try {
      await AuditLogger.record(
        repository: _auditRepository,
        actorUid: actorUid,
        actorEmail: actorEmail,
        actorName: actorName,
        orgId: orgId,
        orgType: orgType,
        entityType: AuditEntityType.membership,
        entityId: user.id,
        action: auditAction,
        summaryHebrew: summary,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[AdminApproval] audit failed: $e');
    }
  }

  static bool isManagerCandidate(AppUser user) {
    return user.userType == UserType.commercialCustomer ||
        user.userType == UserType.commercialSupplier;
  }
}
