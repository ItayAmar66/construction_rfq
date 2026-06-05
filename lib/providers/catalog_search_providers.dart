import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_mode.dart';
import '../data/demo_catalog_search_data.dart';
import '../repositories/catalog_search/catalog_search_repository.dart';
import '../repositories/catalog_search/fallback_catalog_search_repository.dart';
import '../repositories/catalog_search/firestore_catalog_search_repository.dart';

/// Variant search for RFQ catalog selector (Firestore with demo fallback).
final catalogSearchRepositoryProvider =
    Provider<CatalogSearchRepository>((ref) {
  if (AppMode.isDemoMode) {
    return DemoCatalogSearchData.repository();
  }
  return FallbackCatalogSearchRepository(
    primary: FirestoreCatalogSearchRepository(),
    fallback: DemoCatalogSearchData.repository(),
  );
});
