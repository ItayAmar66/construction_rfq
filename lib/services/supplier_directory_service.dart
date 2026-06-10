import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../config/app_mode.dart';
import '../models/app_user.dart';
import '../models/supplier_directory_entry.dart';
import '../models/user_type.dart';
import '../utils/constants.dart';
import 'mock_store.dart';

/// Lists supplier accounts for RFQ targeting (company/name search).
class SupplierDirectoryService {
  SupplierDirectoryService({FirebaseFirestore? firestore})
      : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  Future<List<AppUser>> listSuppliers() async {
    if (AppMode.isDemoMode) {
      return MockStore.listTargetableSuppliers();
    }

    try {
      final snapshot = await _db
          .collection(AppConstants.supplierDirectoryCollection)
          .where('active', isEqualTo: true)
          .get();
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs
            .map((doc) => _entryToAppUser(doc.id, doc.data()))
            .toList()
          ..sort((a, b) => a.fullName.compareTo(b.fullName));
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SupplierDirectory] directory query error: $e');
      }
    }

    return MockStore.listTargetableSuppliers();
  }

  static AppUser _entryToAppUser(String uid, Map<String, dynamic> map) {
    final entry = SupplierDirectoryEntry.fromMap(uid, map);
    return AppUser(
      id: entry.uid,
      fullName: entry.displayName,
      email: '',
      phone: '',
      userType: UserType.commercialSupplier,
      city: entry.city,
      createdAt: DateTime.now(),
      supplierCategoryIds: entry.categoryIds,
      serviceAreas: entry.serviceAreas,
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
              (s.notes ?? '').toLowerCase().contains(q),
        )
        .toList();
  }
}
