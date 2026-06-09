import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../config/app_mode.dart';
import '../models/app_user.dart';
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
      final snapshot = await _db.collection(AppConstants.usersCollection).get();
      final suppliers = snapshot.docs
          .map((doc) => AppUser.fromMap(doc.id, doc.data()))
          .where((user) => user.userType.isSupplier)
          .toList();
      suppliers.sort((a, b) => a.fullName.compareTo(b.fullName));
      return suppliers;
    } catch (e) {
      if (kDebugMode) debugPrint('[SupplierDirectory] list error: $e');
      return MockStore.listTargetableSuppliers();
    }
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
