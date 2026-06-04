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

    final categories = await _deleteCollectionLogged(
      CatalogConstants.categoriesCollection,
    );
    final products = await _deleteCollectionLogged(
      CatalogConstants.productsCollection,
    );
    final variants = await _deleteCollectionLogged(
      CatalogConstants.variantsCollection,
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

  Future<int> _deleteCollectionLogged(String collection) async {
    final deleted = await backend.deleteAllInCollection(
      collection,
      onProgress: (c, n) => config.log('  deleted $c: $n'),
    );
    if (deleted == 0) {
      config.log('  $collection: none to delete (empty or not yet imported)');
    }
    return deleted;
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
