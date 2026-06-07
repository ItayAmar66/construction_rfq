import 'package:cloud_firestore/cloud_firestore.dart';

import 'catalog_firestore_backend.dart';

/// Adapter for Flutter integration tests using cloud_firestore + emulator.
class CloudFirestoreCatalogBackend implements CatalogFirestoreBackend {
  CloudFirestoreCatalogBackend(this._db);

  final FirebaseFirestore _db;

  @override
  Future<void> batchSet(
    String collection,
    List<MapEntry<String, Map<String, dynamic>>> docs,
  ) async {
    if (docs.isEmpty) return;
    final batch = _db.batch();
    for (final entry in docs) {
      batch.set(_db.collection(collection).doc(entry.key), entry.value);
    }
    await batch.commit();
  }

  @override
  Future<void> setDocument(
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) async {
    await _db.collection(collection).doc(docId).set(data);
  }

  @override
  Future<int> deleteAllInCollection(
    String collection, {
    void Function(String collection, int deleted)? onProgress,
  }) async {
    const pageSize = 400;
    var deleted = 0;
    while (true) {
      final snap = await _db.collection(collection).limit(pageSize).get();
      if (snap.docs.isEmpty) break;
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      deleted += snap.docs.length;
      onProgress?.call(collection, deleted);
      if (snap.docs.length < pageSize) break;
    }
    return deleted;
  }

  @override
  Future<bool> deleteDocument(String collection, String docId) async {
    final ref = _db.collection(collection).doc(docId);
    final snap = await ref.get();
    if (!snap.exists) return false;
    await ref.delete();
    return true;
  }

  @override
  Future<int> countCollection(String collection) async {
    final agg = await _db.collection(collection).count().get();
    return agg.count ?? 0;
  }

  @override
  Future<Map<String, dynamic>?> getDocument(
    String collection,
    String docId,
  ) async {
    final snap = await _db.collection(collection).doc(docId).get();
    if (!snap.exists) return null;
    return snap.data();
  }

  @override
  Future<({List<MapEntry<String, Map<String, dynamic>>> docs, String? nextPageToken})>
      listCollectionPage(
    String collection, {
    int pageSize = 500,
    String? pageToken,
  }) async {
    Query<Map<String, dynamic>> q =
        _db.collection(collection).limit(pageSize);
    if (pageToken != null && pageToken.isNotEmpty) {
      final parts = pageToken.split('|');
      if (parts.length == 2) {
        final lastDoc = await _db.collection(collection).doc(parts[1]).get();
        if (lastDoc.exists) {
          q = q.startAfterDocument(lastDoc);
        }
      }
    }
    final snap = await q.get();
    final docs = snap.docs
        .map((d) => MapEntry(d.id, d.data()))
        .toList();
    final next = snap.docs.isEmpty
        ? null
        : '${snap.docs.last.id}|${snap.docs.last.id}';
    return (docs: docs, nextPageToken: next);
  }

  @override
  Future<List<MapEntry<String, Map<String, dynamic>>>> runStructuredQuery(
    Map<String, dynamic> queryBody,
  ) async {
    throw UnimplementedError(
      'Structured query not supported on cloud_firestore adapter',
    );
  }
}
