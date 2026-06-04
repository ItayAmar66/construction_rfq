import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/catalog_constants.dart';
import 'import_checkpoint.dart';
import 'import_config.dart';

/// Deletes catalog collections only (never legacy RFQ data).
class CatalogRollback {
  CatalogRollback({
    required this.config,
    required this.db,
  });

  final CatalogImportConfig config;
  final FirebaseFirestore db;

  static const int deleteBatchSize = 400;

  Future<CatalogRollbackResult> run() async {
    config.log('Rolling back catalog collections (emulator/staging only)...');

    final categories = await _deleteCollection(
      CatalogConstants.categoriesCollection,
    );
    final products = await _deleteCollection(
      CatalogConstants.productsCollection,
    );
    final variants = await _deleteCollection(
      CatalogConstants.variantsCollection,
    );
    final meta = await _deleteMeta();

    final checkpointPath = config.checkpointPath;
    await ImportCheckpoint.clear(checkpointPath);

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

  Future<int> _deleteCollection(String collection) async {
    var deleted = 0;
    while (true) {
      final snap = await db.collection(collection).limit(deleteBatchSize).get();
      if (snap.docs.isEmpty) break;
      final batch = db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      deleted += snap.docs.length;
      if (deleted % 2000 == 0 || snap.docs.length < deleteBatchSize) {
        config.log('  deleted $collection: $deleted');
      }
    }
    return deleted;
  }

  Future<bool> _deleteMeta() async {
    final ref = db
        .collection(CatalogConstants.metaCollection)
        .doc(CatalogConstants.metaCurrentDocId);
    final snap = await ref.get();
    if (!snap.exists) return false;
    await ref.delete();
    return true;
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
