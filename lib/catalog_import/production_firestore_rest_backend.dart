import 'package:googleapis_auth/auth_io.dart' as auth;

import 'firestore_rest_catalog_backend_base.dart';

/// Production Firestore REST via Application Default Credentials (Admin API).
///
/// Requires `GOOGLE_APPLICATION_CREDENTIALS` or `gcloud auth application-default login`.
/// Never uses emulator `Bearer owner` token.
class ProductionFirestoreRestBackend extends FirestoreRestCatalogBackendBase {
  ProductionFirestoreRestBackend._({
    required super.projectId,
    required super.client,
  });

  /// Opens a production backend using Application Default Credentials.
  static Future<ProductionFirestoreRestBackend> open({
    required String projectId,
  }) async {
    if (projectId.trim().isEmpty) {
      throw StateError('Production Firestore requires explicit projectId.');
    }
    final client = await auth.clientViaApplicationDefaultCredentials(
      scopes: const ['https://www.googleapis.com/auth/datastore'],
    );
    return ProductionFirestoreRestBackend._(
      projectId: projectId,
      client: client,
    );
  }

  /// Test-only constructor with injected HTTP client (no ADC).
  ProductionFirestoreRestBackend.forTesting({
    required super.projectId,
    required super.client,
  });

  @override
  String get documentsRoot =>
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents';

  @override
  Map<String, String> requestHeaders() => const {
        'Content-Type': 'application/json',
      };
}
