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

  /// Self-serve org bootstrap disabled — requires platform admin approval or invite.
  Future<Membership?> ensureOwnerOrganization({
    required AppUser user,
    List<Membership> existingMemberships = const [],
  }) async {
    if (existingMemberships.any((m) => m.status == 'active')) {
      return existingMemberships.firstWhere((m) => m.status == 'active');
    }
    return null;
  }
}
