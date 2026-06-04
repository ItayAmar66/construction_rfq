import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/catalog/catalog_repository.dart';
import '../repositories/catalog/firestore_catalog_repository.dart';

/// V2 catalog repository (not wired to UI — legacy [productsProvider] unchanged).
final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return FirestoreCatalogRepository();
});
