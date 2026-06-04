import '../utils/catalog_constants.dart';
import 'catalog_firestore_backend.dart';
import 'import_checkpoint.dart';
import 'import_config.dart';

/// Deletes catalog collections only (never legacy RFQ data).
class CatalogRollback {
  CatalogRollback({
    required this.config,
    required this.backend,
  });

  final CatalogImportConfig config;
  final CatalogFirestoreBackend backend;

  Future<CatalogRollbackResult> run() async {
    config.log('Rolling back catalog collections (emulator/staging only)...');

    final categories = await backend.deleteAllInCollection(
      CatalogConstants.categoriesCollection,
      onProgress: (c, n) => config.log('  deleted $c: $n'),
    );
    final products = await backend.deleteAllInCollection(
      CatalogConstants.productsCollection,
      onProgress: (c, n) => config.log('  deleted $c: $n'),
    );
    final variants = await backend.deleteAllInCollection(
      CatalogConstants.variantsCollection,
      onProgress: (c, n) => config.log('  deleted $c: $n'),
    );
    final meta = await backend.deleteDocument(
      CatalogConstants.metaCollection,
      CatalogConstants.metaCurrentDocId,
    );

    await ImportCheckpoint.clear(config.checkpointPath);

    config.log(
      'Rollback complete: $categories categories, $products products, '
      '$variants variants, meta=$meta',
    );

    return CatalogRollbackResult(
      categoriesDeleted: categories,
      productsDeleted: products,
      variantsDeleted: variants,
      metaDeleted: meta,
    );
  }
}

class CatalogRollbackResult {
  const CatalogRollbackResult({
    required this.categoriesDeleted,
    required this.productsDeleted,
    required this.variantsDeleted,
    required this.metaDeleted,
  });

  final int categoriesDeleted;
  final int productsDeleted;
  final int variantsDeleted;
  final bool metaDeleted;
}
