/// Abstraction for catalog import Firestore I/O (emulator REST or cloud_firestore).
abstract class CatalogFirestoreBackend {
  Future<void> batchSet(
    String collection,
    List<MapEntry<String, Map<String, dynamic>>> docs,
  );

  Future<void> setDocument(
    String collection,
    String docId,
    Map<String, dynamic> data,
  );

  Future<int> deleteAllInCollection(
    String collection, {
    void Function(String collection, int deleted)? onProgress,
  });

  Future<bool> deleteDocument(String collection, String docId);

  Future<int> countCollection(String collection);

  Future<Map<String, dynamic>?> getDocument(String collection, String docId);

  /// Lists documents with decoded field maps. [pageToken] for pagination.
  Future<({List<MapEntry<String, Map<String, dynamic>>> docs, String? nextPageToken})>
      listCollectionPage(
    String collection, {
    int pageSize = 500,
    String? pageToken,
  });

  /// Firestore REST `:runQuery` (structured queries).
  Future<List<MapEntry<String, Map<String, dynamic>>>> runStructuredQuery(
    Map<String, dynamic> queryBody,
  );
}
