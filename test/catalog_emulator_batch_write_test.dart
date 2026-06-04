import 'dart:convert';

import 'package:construction_rfq/catalog_import/emulator_rest_firestore_backend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const projectId = 'construction-rfq-itay-20-2eee0';
  const host = 'http://127.0.0.1:8080';
  final documentsUrl =
      '$host/v1/projects/$projectId/databases/(default)/documents';
  final canonicalPrefix =
      'projects/$projectId/databases/(default)/documents';

  test('batchSet posts to emulator URL with canonical document names', () async {
    Uri? batchUri;
    Map<String, dynamic>? body;

    final client = MockClient((request) async {
      if (request.method == 'POST' &&
          request.url.path.endsWith(':batchWrite')) {
        batchUri = request.url;
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('{}', 200);
      }
      fail('unexpected ${request.method} ${request.url}');
    });

    final backend = EmulatorRestFirestoreBackend(
      projectId: projectId,
      emulatorHost: host,
      client: client,
    );

    await backend.batchSet(
      'catalogCategories',
      [
        MapEntry('100', {'name': 'Test category'}),
      ],
    );
    backend.close();

    expect(batchUri, isNotNull);
    expect(batchUri!.toString(), '$documentsUrl:batchWrite');
    expect(batchUri!.host, '127.0.0.1');
    expect(batchUri!.scheme, 'http');

    final writes = body!['writes'] as List;
    expect(writes, hasLength(1));
    final update = writes.first as Map<String, dynamic>;
    final name = (update['update'] as Map)['name'] as String;
    expect(
      name,
      '$canonicalPrefix/catalogCategories/100',
    );
    expect(name.startsWith('http://'), isFalse);
    expect(name.startsWith('projects/'), isTrue);
  });

  test('batch delete uses canonical names in batchWrite body', () async {
    Map<String, dynamic>? body;

    final client = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path.endsWith('/catalogProducts')) {
        return http.Response(
          jsonEncode({
            'documents': [
              {
                'name': '$documentsUrl/catalogProducts/p1',
                'fields': {},
              },
            ],
          }),
          200,
        );
      }
      if (request.method == 'POST' &&
          request.url.path.endsWith(':batchWrite')) {
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('{}', 200);
      }
      fail('unexpected ${request.method} ${request.url}');
    });

    final backend = EmulatorRestFirestoreBackend(
      projectId: projectId,
      emulatorHost: host,
      client: client,
    );

    final deleted = await backend.deleteAllInCollection('catalogProducts');
    backend.close();

    expect(deleted, 1);
    final writes = body!['writes'] as List;
    expect(writes.first['delete'], '$canonicalPrefix/catalogProducts/p1');
    expect((writes.first['delete'] as String).startsWith('http://'), isFalse);
  });

  test('single-document HTTP paths still use emulator host URL', () async {
    Uri? getUri;

    final client = MockClient((request) async {
      if (request.method == 'GET') {
        getUri = request.url;
        return http.Response('Not Found', 404);
      }
      fail('unexpected ${request.method} ${request.url}');
    });

    final backend = EmulatorRestFirestoreBackend(
      projectId: projectId,
      emulatorHost: host,
      client: client,
    );

    await backend.getDocument('catalogMeta', 'current');
    backend.close();

    expect(
      getUri.toString(),
      '$documentsUrl/catalogMeta/current',
    );
    expect(getUri!.host, '127.0.0.1');
    expect(getUri!.host.contains('googleapis.com'), isFalse);
  });

  test('default project id matches emulator gate configuration', () {
    expect(
      EmulatorRestFirestoreBackend.defaultProjectId,
      projectId,
    );
  });
}
