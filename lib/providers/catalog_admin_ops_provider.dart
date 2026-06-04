import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/catalog/catalog_ops_snapshot.dart';
import '../services/catalog_admin_ops_service.dart';
import 'catalog_providers.dart';

final catalogAdminOpsServiceProvider = Provider<CatalogAdminOpsService>((ref) {
  return CatalogAdminOpsService(ref.watch(catalogRepositoryProvider));
});

final catalogOpsSnapshotProvider = FutureProvider<CatalogOpsSnapshot>((ref) {
  return ref.watch(catalogAdminOpsServiceProvider).loadSnapshot();
});
