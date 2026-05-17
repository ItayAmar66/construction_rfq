// =============================================================================
// DEV / MVP ONLY — Firestore bulk delete helper
// =============================================================================
// Do NOT import this from production app screens or call it on app startup.
// Use only via: lib/dev/reset_firestore_dev_main.dart (see tool/RESET_FIRESTORE_DEV.md)
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore collections managed by this app (top-level).
abstract final class FirestoreDevResetCollections {
  static const dataCollections = [
    'users',
    'products',
    'quoteRequests',
    'supplierQuotes',
    'quoteRequestItems',
    'supplierQuoteItems',
  ];

  /// Optional metadata (e.g. product seed flag). Not deleted unless requested.
  static const metaCollection = 'appMeta';
}

/// Deletes all documents in [collectionPath] in batches (Firestore limit: 500 ops/batch).
Future<int> deleteAllDocumentsInCollection(
  FirebaseFirestore firestore,
  String collectionPath, {
  void Function(String message)? onLog,
  int batchSize = 400,
}) async {
  var totalDeleted = 0;
  final collection = firestore.collection(collectionPath);

  while (true) {
    final snapshot = await collection.limit(batchSize).get();
    if (snapshot.docs.isEmpty) break;

    final batch = firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    totalDeleted += snapshot.docs.length;
    onLog?.call('  $collectionPath: deleted ${snapshot.docs.length} (total: $totalDeleted)');
  }

  return totalDeleted;
}

/// DEV ONLY: Wipes app Firestore data collections. Does not touch Firebase Auth users.
Future<FirestoreDevResetResult> resetFirestoreDevData(
  FirebaseFirestore firestore, {
  bool includeAppMeta = false,
  void Function(String message)? onLog,
}) async {
  final perCollection = <String, int>{};
  var grandTotal = 0;

  for (final name in FirestoreDevResetCollections.dataCollections) {
    onLog?.call('Deleting collection: $name');
    final count = await deleteAllDocumentsInCollection(
      firestore,
      name,
      onLog: onLog,
    );
    perCollection[name] = count;
    grandTotal += count;
  }

  if (includeAppMeta) {
    onLog?.call('Deleting collection: ${FirestoreDevResetCollections.metaCollection}');
    final count = await deleteAllDocumentsInCollection(
      firestore,
      FirestoreDevResetCollections.metaCollection,
      onLog: onLog,
    );
    perCollection[FirestoreDevResetCollections.metaCollection] = count;
    grandTotal += count;
  }

  return FirestoreDevResetResult(
    deletedByCollection: perCollection,
    totalDocumentsDeleted: grandTotal,
  );
}

class FirestoreDevResetResult {
  const FirestoreDevResetResult({
    required this.deletedByCollection,
    required this.totalDocumentsDeleted,
  });

  final Map<String, int> deletedByCollection;
  final int totalDocumentsDeleted;
}
