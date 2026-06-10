import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../config/app_mode.dart';
import '../models/enterprise/project.dart';
import '../utils/constants.dart';
import '../services/mock_store.dart';

class ProjectRepository {
  ProjectRepository({FirebaseFirestore? firestore}) : _firestore = firestore;

  final FirebaseFirestore? _firestore;
  final _uuid = const Uuid();

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  Stream<List<Project>> watchProjectsForOwner(String ownerUid) {
    if (ownerUid.isEmpty) return Stream.value(const []);
    if (AppMode.isDemoMode) {
      return MockStore.instance.watchProjectsForOwner(ownerUid);
    }

    return _db
        .collection(AppConstants.projectsCollection)
        .where('ownerUid', isEqualTo: ownerUid)
        .snapshots()
        .map((snapshot) {
      final projects = snapshot.docs
          .map((doc) => Project.fromMap(doc.id, doc.data()))
          .where((p) => p.isActive)
          .toList();
      projects.sort((a, b) => a.name.compareTo(b.name));
      return projects;
    }).handleError((Object e, StackTrace st) {
      if (kDebugMode) debugPrint('[ProjectRepository] watch error: $e');
      return const <Project>[];
    });
  }

  Future<List<Project>> listProjectsForOwner(String ownerUid) async {
    if (ownerUid.isEmpty) return const [];
    if (AppMode.isDemoMode) {
      return MockStore.instance.listProjectsForOwner(ownerUid);
    }

    try {
      final snapshot = await _db
          .collection(AppConstants.projectsCollection)
          .where('ownerUid', isEqualTo: ownerUid)
          .get();
      final projects = snapshot.docs
          .map((doc) => Project.fromMap(doc.id, doc.data()))
          .where((p) => p.isActive)
          .toList();
      projects.sort((a, b) => a.name.compareTo(b.name));
      return projects;
    } catch (e) {
      if (kDebugMode) debugPrint('[ProjectRepository] list error: $e');
      return const [];
    }
  }

  Future<Project> createProject({
    required String ownerUid,
    required String name,
    String location = '',
    String cityOrArea = '',
    String? notes,
    String? companyName,
    String? orgId,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) throw Exception('יש להזין שם פרויקט');

    if (AppMode.isDemoMode) {
      return MockStore.instance.createProject(
        ownerUid: ownerUid,
        name: trimmedName,
        location: location.trim(),
        cityOrArea: cityOrArea.trim(),
        notes: notes?.trim(),
        companyName: companyName?.trim(),
        orgId: orgId,
      );
    }

    final id = _uuid.v4();
    final now = FieldValue.serverTimestamp();
    final data = <String, dynamic>{
      'ownerUid': ownerUid,
      'name': trimmedName,
      'location': location.trim(),
      'cityOrArea': cityOrArea.trim(),
      if (location.trim().isNotEmpty) 'siteName': location.trim(),
      if (cityOrArea.trim().isNotEmpty) 'city': cityOrArea.trim(),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      if (companyName != null && companyName.trim().isNotEmpty)
        'companyName': companyName.trim(),
      if (orgId != null && orgId.isNotEmpty) 'orgId': orgId,
      'status': 'active',
      'managerUids': <String>[],
      'createdBy': ownerUid,
      'createdAt': now,
      'updatedAt': now,
    };

    await _db.collection(AppConstants.projectsCollection).doc(id).set(data);
    final doc =
        await _db.collection(AppConstants.projectsCollection).doc(id).get();
    return Project.fromMap(doc.id, doc.data()!);
  }

  Future<void> archiveProject({
    required String projectId,
    required String ownerUid,
  }) async {
    if (AppMode.isDemoMode) {
      return MockStore.instance.archiveProject(
        projectId: projectId,
        ownerUid: ownerUid,
      );
    }

    final ref = _db.collection(AppConstants.projectsCollection).doc(projectId);
    final snap = await ref.get();
    if (!snap.exists) throw Exception('הפרויקט לא נמצא');
    final project = Project.fromMap(snap.id, snap.data()!);
    if (project.ownerUid != ownerUid) throw Exception('אין הרשאה');

    await ref.update({
      'status': 'archived',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
