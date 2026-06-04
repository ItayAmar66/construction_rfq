import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'catalog_firestore_backend.dart';
import 'firestore_rest_value_encoder.dart';

/// Firestore writes via Emulator REST API (native Dart CLI, no Flutter).
class EmulatorRestFirestoreBackend implements CatalogFirestoreBackend {
  EmulatorRestFirestoreBackend({
    required this.projectId,
    String? emulatorHost,
    http.Client? client,
  })  : _host = emulatorHost ?? _hostFromEnv(),
        _client = client ?? http.Client();

  static const defaultProjectId = 'construction-rfq-itay-20-2eee0';

  final String projectId;
  final String _host;
  final http.Client _client;

  static String _hostFromEnv() {
    final raw = Platform.environment['FIRESTORE_EMULATOR_HOST'] ?? '127.0.0.1:8080';
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }
    return 'http://$raw';
  }

  String get _documentsRoot =>
      '$_host/v1/projects/$projectId/databases/(default)/documents';

  String _docPath(String collection, String docId) =>
      '$_documentsRoot/$collection/$docId';

  /// Root collection list: GET .../documents/{collectionId}?pageSize=N
  Uri _collectionListUri(
    String collection, {
    required int pageSize,
    String? pageToken,
  }) {
    return Uri.parse('$_documentsRoot/$collection').replace(
      queryParameters: {
        'pageSize': pageSize.toString(),
        if (pageToken != null && pageToken.isNotEmpty) 'pageToken': pageToken,
      },
    );
  }

  /// Missing / empty root collections return 404 on the emulator — treat as [].
  static bool _isMissingCollection(int statusCode) => statusCode == 404;

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
          'name': _docPath(collection, entry.key),
          'fields': FirestoreRestValueEncoder.encodeFields(entry.value),
        },
      };
    }).toList();

    final uri = Uri.parse('$_documentsRoot:batchWrite');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'writes': writes}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'batchWrite failed (${response.statusCode}): ${response.body}',
        uri: uri,
      );
    }
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
          'delete': _docPath(collection, doc.key),
        };
      }).toList();

      final uri = Uri.parse('$_documentsRoot:batchWrite');
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'writes': writes}),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'batchDelete failed (${response.statusCode}): ${response.body}',
          uri: uri,
        );
      }

      deleted += page.docs.length;
      onProgress?.call(collection, deleted);
      pageToken = page.nextPageToken;
    } while (pageToken != null && pageToken.isNotEmpty);

    return deleted;
  }

  @override
  Future<bool> deleteDocument(String collection, String docId) async {
    final uri = Uri.parse(_docPath(collection, docId));
    final response = await _client.delete(uri);
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
    final response = await _client.get(uri);
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
    final response = await _client.get(uri);
    if (_isMissingCollection(response.statusCode)) {
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

  void close() => _client.close();
}
