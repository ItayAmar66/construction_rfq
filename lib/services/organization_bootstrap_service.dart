import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../config/app_mode.dart';
import '../models/app_user.dart';
import '../models/enterprise/enterprise_role.dart';
import '../models/enterprise/membership.dart';
import '../models/enterprise/organization_type.dart';
import '../models/user_type.dart';
import '../utils/constants.dart';
import '../utils/org_id_helpers.dart';

/// Creates a real organization + owner membership for commercial account types.
class OrganizationBootstrapService {
  OrganizationBootstrapService({FirebaseFirestore? firestore})
      : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  /// Returns true when this user type should own a real org document.
  static bool shouldBootstrapOrg(UserType userType) {
    return userType == UserType.commercialCustomer ||
        userType == UserType.commercialSupplier;
  }

  static OrganizationType orgTypeFor(UserType userType) {
    return userType.isSupplier
        ? OrganizationType.supplier
        : OrganizationType.contractor;
  }

  static EnterpriseRole ownerRoleFor(UserType userType) {
    return userType.isSupplier
        ? EnterpriseRole.supplierOwner
        : EnterpriseRole.contractorCompanyOwner;
  }

  /// Ensures organizations/{uid} and owner membership exist (idempotent).
  Future<Membership?> ensureOwnerOrganization({
    required AppUser user,
    List<Membership> existingMemberships = const [],
  }) async {
    if (!shouldBootstrapOrg(user.userType)) return null;
    if (existingMemberships.any((m) => m.status == 'active')) {
      return existingMemberships.firstWhere((m) => m.status == 'active');
    }
    if (AppMode.isDemoMode) return null;

    final orgId = user.id;
    if (!OrgIdHelpers.isRealOrgId(orgId)) return null;

    final orgRef = _db.collection(AppConstants.organizationsCollection).doc(orgId);
    final memberRef = orgRef
        .collection(AppConstants.membershipsSubcollection)
        .doc(user.id);
    final orgType = orgTypeFor(user.userType);
    final ownerRole = ownerRoleFor(user.userType);

    try {
      final memberSnap = await memberRef.get();
      if (memberSnap.exists && memberSnap.data() != null) {
        return Membership.fromMap(memberSnap.id, memberSnap.data()!);
      }

      final orgSnap = await orgRef.get();
      if (!orgSnap.exists) {
        await orgRef.set({
          'type': orgType.value,
          'name': user.fullName.trim().isEmpty ? user.email : user.fullName.trim(),
          'ownerUid': user.id,
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await memberRef.set({
        'uid': user.id,
        'orgId': orgId,
        'orgType': orgType.value,
        'roles': [ownerRole.value],
        'status': 'active',
        'createdBy': user.id,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final saved = await memberRef.get();
      if (!saved.exists || saved.data() == null) return null;
      return Membership.fromMap(saved.id, saved.data()!);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[OrgBootstrap] ensureOwnerOrganization failed: $e');
      }
      return null;
    }
  }
}
