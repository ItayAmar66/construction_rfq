import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../config/app_mode.dart';
import '../models/enterprise/membership.dart';
import '../models/enterprise/organization.dart';
import '../utils/constants.dart';

/// Organization/membership reads — empty until Firestore migration.
class OrganizationRepository {
  OrganizationRepository({FirebaseFirestore? firestore}) : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  Stream<List<Membership>> watchMembershipsForUser(String uid) {
    if (uid.isEmpty || AppMode.isDemoMode) {
      return Stream.value(const []);
    }
    // V1: memberships collection not populated yet — legacy userType fallback.
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
}
