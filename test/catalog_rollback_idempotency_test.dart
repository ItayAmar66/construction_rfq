import 'dart:convert';
import 'dart:io';

import 'package:construction_rfq/catalog_import/catalog_rollback.dart';
import 'package:construction_rfq/catalog_import/emulator_rest_firestore_backend.dart';
import 'package:construction_rfq/catalog_import/import_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const projectId = 'test-project';
  const host = 'http://127.0.0.1:8080';
  final root = '$host/v1/projects/$projectId/databases/(default)/documents';

  CatalogImportConfig testConfig({void Function(String)? log}) {
    return CatalogImportConfig(
      dataRoot: '/tmp',
      outputDir: 'tools/catalog_import/out/test_rollback',
      log: log ?? (_) {},
    );
  }

  test('listCollectionPage uses collection path and returns empty on 404', () async {
    final client = MockClient((request) async {
      expect(
        request.url.toString(),
        '$root/catalogCategories?pageSize=10',
      );
      return http.Response('Not Found', 404);
    });

    final backend = EmulatorRestFirestoreBackend(
      projectId: projectId,
      emulatorHost: host,
      client: client,
    );

    final page = await backend.listCollectionPage(
      'catalogCategories',
      pageSize: 10,
    );
    expect(page.docs, isEmpty);
    expect(page.nextPageToken, isNull);
    backend.close();
  });

  test('deleteAllInCollection on missing collection returns 0', () async {
    final client = MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response('Not Found', 404);
      }
      fail('unexpected ${request.method} ${request.url}');
    });

    final backend = EmulatorRestFirestoreBackend(
      projectId: projectId,
      emulatorHost: host,
      client: client,
    );

    final deleted = await backend.deleteAllInCollection('catalogProducts');
    expect(deleted, 0);
    backend.close();
  });

  test('CatalogRollback on clean emulator does not fail', () async {
    final client = MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response('Not Found', 404);
      }
      if (request.method == 'DELETE' &&
          request.url.path.endsWith('/catalogMeta/current')) {
        return http.Response('', 404);
      }
      fail('unexpected ${request.method} ${request.url}');
    });

    final backend = EmulatorRestFirestoreBackend(
      projectId: projectId,
      emulatorHost: host,
      client: client,
    );

    final result = await CatalogRollback(
      config: testConfig(),
      backend: backend,
    ).run();

    expect(result.categoriesDeleted, 0);
    expect(result.productsDeleted, 0);
    expect(result.variantsDeleted, 0);
    expect(result.metaDeleted, isFalse);
    backend.close();
  });

  test('rollback deletes documents then second rollback is idempotent', () async {
    var listCalls = 0;

    final client = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path.endsWith('/catalogCategories')) {
        listCalls++;
        if (listCalls == 1) {
          return http.Response(
            jsonEncode({
              'documents': [
                {
                  'name': '$root/catalogCategories/1',
                  'fields': {
                    'name': {'stringValue': 'Cat'},
                  },
                },
              ],
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      }
      if (request.method == 'GET') {
        return http.Response('Not Found', 404);
      }
      if (request.method == 'POST' && request.url.path.endsWith(':batchWrite')) {
        return http.Response('{}', 200);
      }
      if (request.method == 'DELETE') {
        return http.Response('', 404);
      }
      fail('unexpected ${request.method} ${request.url}');
    });

    final backend = EmulatorRestFirestoreBackend(
      projectId: projectId,
      emulatorHost: host,
      client: client,
    );

    final first = await CatalogRollback(
      config: testConfig(),
      backend: backend,
    ).run();
    expect(first.categoriesDeleted, 1);

    final second = await CatalogRollback(
      config: testConfig(),
      backend: backend,
    ).run();
    expect(second.categoriesDeleted, 0);
    backend.close();
  });

  test(
    'double rollback on live emulator',
    () async {
      if (!CatalogImportSafety.isEmulatorHostConfigured) return;

      final backend = EmulatorRestFirestoreBackend(
        projectId: EmulatorRestFirestoreBackend.defaultProjectId,
      );
      final config = testConfig();

      try {
        final first = await CatalogRollback(config: config, backend: backend).run();
        expect(first, isNotNull);

        final second = await CatalogRollback(config: config, backend: backend).run();
        expect(second.categoriesDeleted, 0);
        expect(second.productsDeleted, 0);
        expect(second.variantsDeleted, 0);
      } finally {
        backend.close();
      }
    },
    skip: !Platform.environment.containsKey('FIRESTORE_EMULATOR_HOST'),
  );
}
