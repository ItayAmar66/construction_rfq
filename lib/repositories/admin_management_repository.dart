import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../config/app_mode.dart';
import '../models/enterprise/enterprise_role.dart';
import '../models/enterprise/membership.dart';
import '../models/enterprise/organization.dart';
import '../models/enterprise/organization_type.dart';
import '../models/enterprise/project.dart';
import '../models/supplier_directory_entry.dart';
import '../services/mock_store.dart';
import '../utils/constants.dart';

class AdminManagementRepository {
  AdminManagementRepository({FirebaseFirestore? firestore})
      : _firestore = firestore,
        _uuid = const Uuid();

  final FirebaseFirestore? _firestore;
  final Uuid _uuid;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  static final _demoOrgs = <String, Organization>{};
  static final _demoSupplierDirectory = <String, SupplierDirectoryEntry>{};

  Future<List<Organization>> fetchOrganizations() async {
    if (AppMode.isDemoMode) {
      return _demoOrgs.values.toList()
        ..sort((a, b) => a.name.compareTo(b.name));
    }
    final snap = await _db
        .collection(AppConstants.organizationsCollection)
        .orderBy('name')
        .get();
    return snap.docs
        .map((d) => Organization.fromMap(d.id, d.data()))
        .toList();
  }

  Future<Organization> createOrganization({
    required OrganizationType type,
    required String name,
    String? orgId,
    String ownerUid = '',
    String? phone,
    String? email,
    String? address,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw Exception('יש להזין שם חברה');

    final id = orgId?.trim().isNotEmpty == true
        ? orgId!.trim()
        : 'org-${type.value}-${_uuid.v4().substring(0, 8)}';
    final now = DateTime.now();

    final org = Organization(
      id: id,
      type: type,
      name: trimmed,
      ownerUid: ownerUid,
      status: 'active',
      createdAt: now,
      updatedAt: now,
      phone: phone?.trim(),
      email: email?.trim(),
      address: address?.trim(),
    );

    if (AppMode.isDemoMode) {
      _demoOrgs[id] = org;
      return org;
    }

    await _db.collection(AppConstants.organizationsCollection).doc(id).set({
      ...org.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return org;
  }

  Future<Organization> updateOrganizationOwner({
    required String orgId,
    required String ownerUid,
  }) async {
    if (AppMode.isDemoMode) {
      final existing = _demoOrgs[orgId];
      if (existing == null) throw Exception('הארגון לא נמצא');
      final updated = Organization(
        id: existing.id,
        type: existing.type,
        name: existing.name,
        ownerUid: ownerUid,
        status: existing.status,
        createdAt: existing.createdAt,
        updatedAt: DateTime.now(),
        phone: existing.phone,
        email: existing.email,
        address: existing.address,
      );
      _demoOrgs[orgId] = updated;
      return updated;
    }

    await _db.collection(AppConstants.organizationsCollection).doc(orgId).update({
      'ownerUid': ownerUid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final snap =
        await _db.collection(AppConstants.organizationsCollection).doc(orgId).get();
    return Organization.fromMap(snap.id, snap.data()!);
  }

  Future<Membership> upsertMembership({
    required String orgId,
    required OrganizationType orgType,
    required String uid,
    required EnterpriseRole role,
    required String actorUid,
    String? email,
    String? displayName,
    List<String> projectIds = const [],
    String status = 'active',
  }) async {
    final membership = Membership(
      uid: uid,
      orgId: orgId,
      orgType: orgType,
      roles: [role],
      status: status,
      projectIds: projectIds,
      createdBy: actorUid,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      email: email,
      displayName: displayName,
    );

    if (AppMode.isDemoMode) {
      MockStore.instance.upsertDemoMembership(membership);
      return membership;
    }

    await _db
        .collection(AppConstants.organizationsCollection)
        .doc(orgId)
        .collection(AppConstants.membershipsSubcollection)
        .doc(uid)
        .set({
      ...membership.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return membership;
  }

  Future<Membership> updateMembership({
    required String orgId,
    required String uid,
    EnterpriseRole? role,
    String? status,
    List<String>? projectIds,
    required String actorUid,
  }) async {
    if (AppMode.isDemoMode) {
      return MockStore.instance.updateDemoMembership(
        orgId: orgId,
        uid: uid,
        role: role,
        status: status,
        projectIds: projectIds,
      );
    }

    final ref = _db
        .collection(AppConstants.organizationsCollection)
        .doc(orgId)
        .collection(AppConstants.membershipsSubcollection)
        .doc(uid);
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedByUid': actorUid,
    };
    if (role != null) updates['roles'] = [role.value];
    if (status != null) updates['status'] = status;
    if (projectIds != null) updates['projectIds'] = projectIds;
    await ref.set(updates, SetOptions(merge: true));
    final snap = await ref.get();
    return Membership.fromMap(snap.id, snap.data()!);
  }

  Future<void> assignProjectMember({
    required String projectId,
    required String orgId,
    required String uid,
    required EnterpriseRole role,
    required String actorUid,
    String? displayName,
    String? email,
  }) async {
    if (AppMode.isDemoMode) {
      MockStore.instance.assignProjectMemberDemo(
        projectId: projectId,
        orgId: orgId,
        uid: uid,
        role: role,
        actorUid: actorUid,
        displayName: displayName,
        email: email,
      );
      return;
    }

    await _db
        .collection(AppConstants.projectsCollection)
        .doc(projectId)
        .collection('assignments')
        .doc(uid)
        .set({
      'projectId': projectId,
      'orgId': orgId,
      'uid': uid,
      'role': role.value,
      if (displayName != null) 'displayName': displayName,
      if (email != null) 'email': email,
      'assignedByUid': actorUid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<SupplierDirectoryEntry> upsertSupplierDirectory({
    required String uid,
    required String displayName,
    required String orgId,
    String city = '',
  }) async {
    final entry = SupplierDirectoryEntry(
      uid: uid,
      displayName: displayName,
      orgId: orgId,
      city: city,
      active: true,
    );

    if (AppMode.isDemoMode) {
      _demoSupplierDirectory[uid] = entry;
      return entry;
    }

    await _db
        .collection(AppConstants.supplierDirectoryCollection)
        .doc(uid)
        .set({
      'displayName': displayName,
      'orgId': orgId,
      'city': city,
      'active': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return entry;
  }

  Future<List<Membership>> fetchMembershipsForOrg(String orgId) async {
    if (AppMode.isDemoMode) {
      return MockStore.instance
          .watchMembershipsForOrganization(orgId)
          .first;
    }
    final snap = await _db
        .collection(AppConstants.organizationsCollection)
        .doc(orgId)
        .collection(AppConstants.membershipsSubcollection)
        .get();
    return snap.docs.map((d) => Membership.fromMap(d.id, d.data())).toList();
  }

  Future<Project> createProjectAsAdmin({
    required String ownerUid,
    required String name,
    required String orgId,
    String location = '',
    String cityOrArea = '',
    String? companyName,
    List<String> managerUids = const [],
    required String actorUid,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw Exception('יש להזין שם פרויקט');

    if (AppMode.isDemoMode) {
      return MockStore.instance.createProject(
        ownerUid: ownerUid,
        name: trimmed,
        location: location,
        cityOrArea: cityOrArea,
        companyName: companyName,
        orgId: orgId,
      );
    }

    final id = _uuid.v4();
    final data = <String, dynamic>{
      'ownerUid': ownerUid,
      'orgId': orgId,
      'name': trimmed,
      'location': location.trim(),
      'cityOrArea': cityOrArea.trim(),
      if (location.trim().isNotEmpty) 'siteName': location.trim(),
      if (cityOrArea.trim().isNotEmpty) 'city': cityOrArea.trim(),
      if (companyName != null && companyName.trim().isNotEmpty)
        'companyName': companyName.trim(),
      'status': 'active',
      'managerUids': managerUids,
      'createdBy': actorUid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await _db.collection(AppConstants.projectsCollection).doc(id).set(data);
    final snap =
        await _db.collection(AppConstants.projectsCollection).doc(id).get();
    return Project.fromMap(snap.id, snap.data()!);
  }

  String buildCreateUserCommand({
    required String email,
    required String password,
    required String fullName,
    required String orgId,
    required String role,
    required String userType,
    String? phone,
    String? city,
  }) {
    final parts = [
      'node tools/admin/admin_onboarding.js create-user',
      '--email "$email"',
      '--password "$password"',
      '--name "$fullName"',
      '--org "$orgId"',
      '--role "$role"',
      '--userType "$userType"',
      if (phone != null && phone.isNotEmpty) '--phone "$phone"',
      if (city != null && city.isNotEmpty) '--city "$city"',
    ];
    return parts.join(' ');
  }

  String get seedLaunchTestCommand =>
      'node tools/admin/admin_onboarding.js seed-launch-test';

  static void resetDemoStores() {
    _demoOrgs.clear();
    _demoSupplierDirectory.clear();
  }
}
