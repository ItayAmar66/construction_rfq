import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/catalog_search/catalog_search_repository.dart';
import '../repositories/catalog_search/firestore_catalog_search_repository.dart';

/// Variant search layer (not wired to UI — legacy catalog screens unchanged).
final catalogSearchRepositoryProvider =
    Provider<CatalogSearchRepository>((ref) {
  return FirestoreCatalogSearchRepository();
});
