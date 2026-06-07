import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/catalog_search/catalog_search_repository.dart';
import '../repositories/catalog_search/firestore_catalog_search_repository.dart';

/// Real imported Firestore catalog only (no demo/fallback slice in UI).
final catalogSearchRepositoryProvider =
    Provider<CatalogSearchRepository>((ref) {
  return FirestoreCatalogSearchRepository();
});
