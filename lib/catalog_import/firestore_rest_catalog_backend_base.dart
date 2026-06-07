import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'catalog_firestore_backend.dart';
import 'firestore_batch_retry.dart';
import 'firestore_rest_value_encoder.dart';

/// Shared Firestore REST implementation for emulator and production backends.
abstract class FirestoreRestCatalogBackendBase implements CatalogFirestoreBackend {
  FirestoreRestCatalogBackendBase({
    required this.projectId,
    required http.Client client,
    FirestoreBatchRetryPolicy? retryPolicy,
  })  : _client = client,
        _retryPolicy = retryPolicy ?? FirestoreBatchRetryPolicy.none();

  final String projectId;
  final http.Client _client;
  final FirestoreBatchRetryPolicy _retryPolicy;

  String get documentsRoot;

  Map<String, String> requestHeaders();

  bool isMissingCollection(int statusCode) => statusCode == 404;

  String _docPath(String collection, String docId) =>
      '$documentsRoot/$collection/$docId';

  String _canonicalDocName(String collection, String docId) =>
      'projects/$projectId/databases/(default)/documents/$collection/$docId';

  Uri _collectionListUri(
    String collection, {
    required int pageSize,
    String? pageToken,
  }) {
    return Uri.parse('$documentsRoot/$collection').replace(
      queryParameters: {
        'pageSize': pageSize.toString(),
        if (pageToken != null && pageToken.isNotEmpty) 'pageToken': pageToken,
      },
    );
  }

  @override
  Future<void> setDocument(
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) async {
    await batchSet(collection, [MapEntry(docId, data)]);
  }

  @override
  Future<void> batchSet(
    String collection,
    List<MapEntry<String, Map<String, dynamic>>> docs,
  ) async {
    if (docs.isEmpty) return;

    final writes = docs.map((entry) {
      return {
        'update': {
          'name': _canonicalDocName(collection, entry.key),
          'fields': FirestoreRestValueEncoder.encodeFields(entry.value),
        },
      };
    }).toList();

    final uri = Uri.parse('$documentsRoot:batchWrite');
    await _retryPolicy.postWithRetry(
      client: _client,
      uri: uri,
      headers: requestHeaders(),
      body: jsonEncode({'writes': writes}),
      operation: 'batchWrite($collection, ${docs.length} docs)',
    );
  }

  @override
  Future<int> deleteAllInCollection(
    String collection, {
    void Function(String collection, int deleted)? onProgress,
  }) async {
    var deleted = 0;
    String? pageToken;
    do {
      final page = await listCollectionPage(
        collection,
        pageSize: 400,
        pageToken: pageToken,
      );
      if (page.docs.isEmpty) break;

      final writes = page.docs.map((doc) {
        return {
          'delete': _canonicalDocName(collection, doc.key),
        };
      }).toList();

      final uri = Uri.parse('$documentsRoot:batchWrite');
      await _retryPolicy.postWithRetry(
        client: _client,
        uri: uri,
        headers: requestHeaders(),
        body: jsonEncode({'writes': writes}),
        operation: 'batchDelete($collection, ${page.docs.length} docs)',
      );

      deleted += page.docs.length;
      onProgress?.call(collection, deleted);
      pageToken = page.nextPageToken;
    } while (pageToken != null && pageToken.isNotEmpty);

    return deleted;
  }

  @override
  Future<bool> deleteDocument(String collection, String docId) async {
    final uri = Uri.parse(_docPath(collection, docId));
    final response = await _client.delete(uri, headers: requestHeaders());
    if (response.statusCode == 404) return false;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'delete failed (${response.statusCode}): ${response.body}',
        uri: uri,
      );
    }
    return true;
  }

  @override
  Future<int> countCollection(String collection) async {
    var count = 0;
    String? pageToken;
    do {
      final page = await listCollectionPage(
        collection,
        pageSize: 1000,
        pageToken: pageToken,
      );
      count += page.docs.length;
      pageToken = page.nextPageToken;
    } while (pageToken != null && pageToken.isNotEmpty);
    return count;
  }

  @override
  Future<Map<String, dynamic>?> getDocument(
    String collection,
    String docId,
  ) async {
    final uri = Uri.parse(_docPath(collection, docId));
    final response = await _client.get(uri, headers: requestHeaders());
    if (response.statusCode == 404) return null;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'get failed (${response.statusCode}): ${response.body}',
        uri: uri,
      );
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final fields = body['fields'] as Map<String, dynamic>?;
    return FirestoreRestValueEncoder.decodeFields(fields);
  }

  @override
  Future<({List<MapEntry<String, Map<String, dynamic>>> docs, String? nextPageToken})>
      listCollectionPage(
    String collection, {
    int pageSize = 500,
    String? pageToken,
  }) async {
    final uri = _collectionListUri(
      collection,
      pageSize: pageSize,
      pageToken: pageToken,
    );
    final response = await _client.get(uri, headers: requestHeaders());
    if (isMissingCollection(response.statusCode)) {
      return (docs: <MapEntry<String, Map<String, dynamic>>>[], nextPageToken: null);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'list failed (${response.statusCode}): ${response.body}',
        uri: uri,
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final rawDocs = body['documents'] as List? ?? [];
    final docs = <MapEntry<String, Map<String, dynamic>>>[];

    for (final raw in rawDocs) {
      final doc = Map<String, dynamic>.from(raw as Map);
      final name = doc['name'] as String? ?? '';
      final id = name.split('/').last;
      final fields = doc['fields'] as Map<String, dynamic>?;
      docs.add(
        MapEntry(id, FirestoreRestValueEncoder.decodeFields(fields)),
      );
    }

    return (
      docs: docs,
      nextPageToken: body['nextPageToken'] as String?,
    );
  }

  @override
  Future<List<MapEntry<String, Map<String, dynamic>>>> runStructuredQuery(
    Map<String, dynamic> queryBody,
  ) async {
    final uri = Uri.parse('$documentsRoot:runQuery');
    final response = await _client.post(
      uri,
      headers: requestHeaders(),
      body: jsonEncode(queryBody),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'runQuery failed (${response.statusCode}): ${response.body}',
        uri: uri,
      );
    }

    final rows = jsonDecode(response.body) as List;
    final docs = <MapEntry<String, Map<String, dynamic>>>[];
    for (final raw in rows) {
      if (raw is! Map) continue;
      final doc = raw['document'];
      if (doc is! Map) continue;
      final name = doc['name'] as String? ?? '';
      final id = name.split('/').last;
      if (id.isEmpty) continue;
      final fields = doc['fields'] as Map<String, dynamic>?;
      docs.add(
        MapEntry(id, FirestoreRestValueEncoder.decodeFields(fields)),
      );
    }
    return docs;
  }

  void close() => _client.close();
}
