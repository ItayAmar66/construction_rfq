import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../config/app_mode.dart';
import '../models/enterprise/organization_invitation.dart';
import '../models/app_user.dart';
import '../models/enterprise/project.dart';
import '../models/quote_request.dart';
import '../models/supplier_directory_entry.dart';
import '../models/supplier_quote.dart';
import '../services/mock_store.dart';
import '../utils/constants.dart';
import '../services/quote_persistence_support.dart';

class AdminOverviewCounts {
  const AdminOverviewCounts({
    required this.users,
    required this.projects,
    required this.requests,
    required this.suppliers,
    required this.quotes,
  });

  final int users;
  final int projects;
  final int requests;
  final int suppliers;
  final int quotes;
}

class AdminRepository {
  AdminRepository({FirebaseFirestore? firestore}) : _firestore = firestore;

  final FirebaseFirestore? _firestore;
  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  Future<AdminOverviewCounts> fetchCounts() async {
    if (AppMode.isDemoMode) {
      final users = _demoUsers().length;
      return AdminOverviewCounts(
        users: users,
        projects: MockStore.instance.projects.length,
        requests: MockStore.instance.quoteRequests.length,
        suppliers: MockStore.listTargetableSuppliers().length,
        quotes: MockStore.instance.supplierQuotes.length,
      );
    }

    try {
      final users = await _db.collection(AppConstants.usersCollection).count().get();
      final projects =
          await _db.collection(AppConstants.projectsCollection).count().get();
      final requests =
          await _db.collection(AppConstants.quoteRequestsCollection).count().get();
      final suppliers =
          await _db.collection(AppConstants.supplierDirectoryCollection).count().get();
      final quotes =
          await _db.collection(AppConstants.supplierQuotesCollection).count().get();
      return AdminOverviewCounts(
        users: users.count ?? 0,
        projects: projects.count ?? 0,
        requests: requests.count ?? 0,
        suppliers: suppliers.count ?? 0,
        quotes: quotes.count ?? 0,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[AdminRepository] counts error: $e');
      rethrow;
    }
  }

  Future<List<AppUser>> fetchRecentUsers({int limit = 12}) async {
    if (AppMode.isDemoMode) {
      return _demoUsers().take(limit).toList();
    }
    try {
      final snap = await _db
          .collection(AppConstants.usersCollection)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return snap.docs
          .map((doc) => AppUser.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('[AdminRepository] users error: $e');
      rethrow;
    }
  }

  Future<List<Project>> fetchRecentProjects({int limit = 12}) async {
    if (AppMode.isDemoMode) {
      final list = [...MockStore.instance.projects]
        ..sort((a, b) => (b.updatedAt ?? b.createdAt ?? DateTime(2000))
            .compareTo(a.updatedAt ?? a.createdAt ?? DateTime(2000)));
      return list.take(limit).toList();
    }
    try {
      final snap = await _db
          .collection(AppConstants.projectsCollection)
          .orderBy('updatedAt', descending: true)
          .limit(limit)
          .get();
      return snap.docs.map((doc) => Project.fromMap(doc.id, doc.data())).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('[AdminRepository] projects error: $e');
      rethrow;
    }
  }

  Future<List<QuoteRequest>> fetchRecentRequests({int limit = 12}) async {
    if (AppMode.isDemoMode) {
      final list = [...MockStore.instance.quoteRequests]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list.take(limit).toList();
    }
    try {
      final snap = await _db
          .collection(AppConstants.quoteRequestsCollection)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return mapQuoteRequests(snap);
    } catch (e) {
      if (kDebugMode) debugPrint('[AdminRepository] requests error: $e');
      rethrow;
    }
  }

  Future<List<SupplierDirectoryEntry>> fetchSuppliers({int limit = 12}) async {
    if (AppMode.isDemoMode) {
      return MockStore.listTargetableSuppliers()
          .take(limit)
          .map(
            (u) => SupplierDirectoryEntry(
              uid: u.id,
              displayName: u.fullName,
              city: u.city,
              categoryIds: u.supplierCategoryIds,
              serviceAreas: u.serviceAreas,
            ),
          )
          .toList();
    }
    try {
      final snap = await _db
          .collection(AppConstants.supplierDirectoryCollection)
          .limit(limit)
          .get();
      return snap.docs
          .map((doc) => SupplierDirectoryEntry.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('[AdminRepository] suppliers error: $e');
      rethrow;
    }
  }

  Future<List<SupplierQuote>> fetchRecentQuotes({int limit = 12}) async {
    if (AppMode.isDemoMode) {
      final list = [...MockStore.instance.supplierQuotes]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list.take(limit).toList();
    }
    try {
      final snap = await _db
          .collection(AppConstants.supplierQuotesCollection)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return snap.docs
          .map((doc) => SupplierQuote.fromMap(doc.id, doc.data()))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      if (kDebugMode) debugPrint('[AdminRepository] quotes error: $e');
      rethrow;
    }
  }

  List<AppUser> _demoUsers() {
    final users = <AppUser>[
      MockStore.demoCustomer,
      ...MockStore.listTargetableSuppliers(),
    ];
    final current = MockStore.instance.currentUser;
    if (current != null && !users.any((u) => u.id == current.id)) {
      users.insert(0, current);
    }
    return users;
  }

  Future<List<OrganizationInvitation>> fetchRecentInvitations({
    int limit = 8,
  }) async {
    if (AppMode.isDemoMode) {
      return MockStore.instance.demoInvitations.values.take(limit).toList();
    }
    try {
      final snap = await _db
          .collection(AppConstants.invitationsCollection)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return snap.docs
          .map((d) => OrganizationInvitation.fromMap(d.id, d.data()))
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('[AdminRepository] invitations error: $e');
      rethrow;
    }
  }
}
