import 'dart:io';

import 'package:http/http.dart' as http;

import 'firestore_batch_retry.dart';
import 'firestore_rest_catalog_backend_base.dart';

/// Firestore writes via Emulator REST API (native Dart CLI, no Flutter).
class EmulatorRestFirestoreBackend extends FirestoreRestCatalogBackendBase {
  EmulatorRestFirestoreBackend({
    required super.projectId,
    String? emulatorHost,
    http.Client? client,
    bool emulatorMode = true,
    FirestoreBatchRetryPolicy? retryPolicy,
  })  : _host = _resolveHost(emulatorHost, emulatorMode),
        super(
          client: client ?? http.Client(),
          retryPolicy: retryPolicy,
        ) {
    if (!emulatorMode) {
      throw StateError(
        'EmulatorRestFirestoreBackend requires emulator mode (--emulator).',
      );
    }
    _assertLocalEmulatorHost(_host);
  }

  static const defaultProjectId = 'construction-rfq-itay-20-2eee0';

  /// Firestore emulator admin token for batchWrite and other privileged REST ops.
  static const emulatorAdminAuthorization = 'Bearer owner';

  late final String _host;

  static String _resolveHost(String? emulatorHost, bool emulatorMode) {
    if (!emulatorMode) {
      throw StateError('EmulatorRestFirestoreBackend requires emulator mode.');
    }
    final envHost = Platform.environment['FIRESTORE_EMULATOR_HOST'];
    if ((envHost == null || envHost.trim().isEmpty) && emulatorHost == null) {
      throw StateError(
        'FIRESTORE_EMULATOR_HOST is required (e.g. 127.0.0.1:8080).',
      );
    }
    return emulatorHost ?? _hostFromEnv(envHost!);
  }

  static String _hostFromEnv(String raw) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    return 'http://$trimmed';
  }

  static void _assertLocalEmulatorHost(String hostUrl) {
    final lower = hostUrl.toLowerCase();
    if (lower.contains('googleapis.com') || lower.contains('firebaseio.com')) {
      throw StateError('Refusing non-emulator Firestore host: $hostUrl');
    }

    final uri = Uri.parse(
      hostUrl.startsWith('http://') || hostUrl.startsWith('https://')
          ? hostUrl
          : 'http://$hostUrl',
    );
    final hostname = uri.host.toLowerCase();
    const allowed = {'127.0.0.1', 'localhost', '::1'};
    if (!allowed.contains(hostname)) {
      throw StateError(
        'Refusing non-local Firestore emulator host: ${uri.host}',
      );
    }
  }

  @override
  String get documentsRoot =>
      '$_host/v1/projects/$projectId/databases/(default)/documents';

  @override
  Map<String, String> requestHeaders() => {
        'Content-Type': 'application/json',
        'Authorization': emulatorAdminAuthorization,
      };

  @override
  bool isMissingCollection(int statusCode) => statusCode == 404;
}
