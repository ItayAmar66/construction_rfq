import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../config/app_mode.dart';
import '../models/app_user.dart';
import '../models/enterprise/organization.dart';
import '../models/user_type.dart';
import '../repositories/organization_repository.dart';
import '../utils/constants.dart';
import 'mock_store.dart';

/// Lists supplier organizations for RFQ targeting (company name search).
class SupplierDirectoryService {
  SupplierDirectoryService({
    FirebaseFirestore? firestore,
    OrganizationRepository? organizationRepository,
  })  : _firestore = firestore,
        _organizationRepository =
            organizationRepository ?? OrganizationRepository(firestore: firestore);

  final FirebaseFirestore? _firestore;
  final OrganizationRepository _organizationRepository;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  Future<List<AppUser>> listSuppliers() async {
    if (AppMode.isDemoMode) {
      return MockStore.listTargetableSuppliers();
    }

    try {
      final orgs = await _organizationRepository.listActiveSupplierOrganizations();
      if (orgs.isNotEmpty) {
        return orgs.map(organizationToAppUser).toList();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SupplierDirectory] organizations query error: $e');
      }
    }

    return const [];
  }

  static AppUser organizationToAppUser(Organization org) {
    final ownerUid = org.ownerUid.trim();
    return AppUser(
      id: ownerUid.isNotEmpty ? ownerUid : org.id,
      fullName: org.name,
      email: '',
      phone: '',
      userType: UserType.commercialSupplier,
      city: '',
      notes: org.id,
      createdAt: org.createdAt ?? DateTime.now(),
      supplierOrgId: org.id,
    );
  }

  static List<AppUser> filterByQuery(List<AppUser> suppliers, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return suppliers;
    return suppliers
        .where(
          (s) =>
              s.fullName.toLowerCase().contains(q) ||
              s.city.toLowerCase().contains(q) ||
              (s.notes ?? '').toLowerCase().contains(q) ||
              (s.supplierOrgId ?? '').toLowerCase().contains(q),
        )
        .toList();
  }
}
