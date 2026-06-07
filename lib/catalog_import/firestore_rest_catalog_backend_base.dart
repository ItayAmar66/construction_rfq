import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'catalog_firestore_backend.dart';
import 'firestore_batch_retry.dart';
import 'firestore_batch_write_response.dart';
import 'firestore_rest_value_encoder.dart';

/// Shared Firestore REST implementation for emulator and production backends.
abstract class FirestoreRestCatalogBackendBase implements CatalogFirestoreBackend {
  FirestoreRestCatalogBackendBase({
    required this.projectId,
    required http.Client client,
    FirestoreRestTransportOptions? transport,
  })  : _client = client,
        _transport = transport ?? FirestoreRestTransportOptions.emulator();

  final String projectId;
  final http.Client _client;
  final FirestoreRestTransportOptions _transport;

  FirestoreBatchRetryPolicy get _retryPolicy => _transport.retryPolicy;

  String get documentsRoot;

  Map<String, String> requestHeaders();

  bool isMissingCollection(int statusCode) => statusCode == 404;

  Future<void> _delayAfterReadPage() async {
    if (_transport.readPageDelayMs <= 0) return;
    await Future<void>.delayed(
      Duration(milliseconds: _transport.readPageDelayMs),
    );
  }

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
    final response = await _retryPolicy.postWithRetry(
      client: _client,
      uri: uri,
      headers: requestHeaders(),
      body: jsonEncode({'writes': writes}),
      operation: 'batchWrite($collection, ${docs.length} docs)',
    );
    FirestoreBatchWriteResponse.ensureAllWritesSucceeded(
      responseBody: response.body,
      operation: 'batchWrite($collection, ${docs.length} docs)',
      uri: uri,
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
        pageSize: _transport.listPageSize,
        pageToken: pageToken,
      );
      if (page.docs.isEmpty) break;

      final writes = page.docs.map((doc) {
        return {
          'delete': _canonicalDocName(collection, doc.key),
        };
      }).toList();

      final uri = Uri.parse('$documentsRoot:batchWrite');
      final response = await _retryPolicy.postWithRetry(
        client: _client,
        uri: uri,
        headers: requestHeaders(),
        body: jsonEncode({'writes': writes}),
        operation: 'batchDelete($collection, ${page.docs.length} docs)',
      );
      FirestoreBatchWriteResponse.ensureAllWritesSucceeded(
        responseBody: response.body,
        operation: 'batchDelete($collection, ${page.docs.length} docs)',
        uri: uri,
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
        pageSize: _transport.countPageSize,
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
    final response = await _getWithOptionalNotFound(
      uri: uri,
      operation: 'get($collection/$docId)',
    );
    if (response == null) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final fields = body['fields'] as Map<String, dynamic>?;
    return FirestoreRestValueEncoder.decodeFields(fields);
  }

  /// GET with retry; returns null on 404 (missing document or empty collection).
  Future<http.Response?> _getWithOptionalNotFound({
    required Uri uri,
    required String operation,
    bool treat404AsEmpty = false,
  }) async {
    http.Response? lastResponse;

    for (var attempt = 1; attempt <= _retryPolicy.maxAttempts; attempt++) {
      try {
        final response = await _client.get(uri, headers: requestHeaders());
        if (response.statusCode == 404 && treat404AsEmpty) return null;
        if (response.statusCode == 404) return null;
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return response;
        }

        lastResponse = response;
        if (!_retryPolicy.isRetryableStatus(response.statusCode) ||
            attempt >= _retryPolicy.maxAttempts) {
          throw HttpException(
            '$operation failed (${response.statusCode}): ${response.body}',
            uri: uri,
          );
        }

        final wait = _retryPolicy.delayBeforeRetry(
          attempt: attempt,
          response: response,
        );
        _retryPolicy.log?.call(
          'RETRY $operation attempt $attempt/${_retryPolicy.maxAttempts} '
          '(HTTP ${response.statusCode}); '
          'wait ${(wait.inMilliseconds / 1000).toStringAsFixed(1)}s',
        );
        await _retryPolicy.sleep(wait);
      } catch (e) {
        if (e is HttpException) rethrow;
        if (attempt >= _retryPolicy.maxAttempts) {
          throw HttpException(
            '$operation failed after ${_retryPolicy.maxAttempts} attempts: $e',
            uri: uri,
          );
        }
        final wait = _retryPolicy.delayBeforeRetry(
          attempt: attempt,
          response: lastResponse,
        );
        await _retryPolicy.sleep(wait);
      }
    }
    return null;
  }

  @override
  Future<({List<MapEntry<String, Map<String, dynamic>>> docs, String? nextPageToken})>
      listCollectionPage(
    String collection, {
    int? pageSize,
    String? pageToken,
  }) async {
    if (pageToken != null && pageToken.isNotEmpty) {
      await _delayAfterReadPage();
    }
    final effectivePageSize = pageSize ?? _transport.listPageSize;
    final uri = _collectionListUri(
      collection,
      pageSize: effectivePageSize,
      pageToken: pageToken,
    );
    final response = await _getWithOptionalNotFound(
      uri: uri,
      operation: 'list($collection pageSize=$effectivePageSize)',
      treat404AsEmpty: true,
    );
    if (response == null) {
      return (docs: <MapEntry<String, Map<String, dynamic>>>[], nextPageToken: null);
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
    final response = await _retryPolicy.postWithRetry(
      client: _client,
      uri: uri,
      headers: requestHeaders(),
      body: jsonEncode(queryBody),
      operation: 'runQuery',
    );

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
