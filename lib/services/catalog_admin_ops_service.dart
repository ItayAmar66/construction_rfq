import '../models/catalog/catalog_meta.dart';
import '../models/catalog/catalog_ops_snapshot.dart';
import '../repositories/catalog/catalog_repository.dart';

/// Read-only catalog metadata for admin/debug ops screens.
class CatalogAdminOpsService {
  CatalogAdminOpsService(this._repository);

  final CatalogRepository _repository;

  Future<CatalogOpsSnapshot> loadSnapshot() async {
    final meta = await _repository.getMeta();
    return CatalogOpsSnapshot.fromMeta(meta);
  }

  Stream<CatalogOpsSnapshot> watchSnapshot() {
    return _repository.watchMeta().map(CatalogOpsSnapshot.fromMeta);
  }
}

/// Demo fallback when Firestore meta is unavailable (e.g. widget tests).
CatalogOpsSnapshot demoCatalogOpsSnapshot() {
  return CatalogOpsSnapshot.fromMeta(
    const CatalogMeta(
      version: 'demo',
      productCount: 11149,
      variantCount: 31551,
      categoryCount: 418,
      searchMode: 'firestore',
      isDemoSlice: false,
    ),
  );
}
