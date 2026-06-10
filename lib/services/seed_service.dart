import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_mode.dart';
import '../data/seed_products.dart';
import '../utils/constants.dart';

class SeedService {
  SeedService({FirebaseFirestore? firestore}) : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  Future<void> seedProductsIfNeeded() async {
    if (!AppMode.isDemoMode || !AppMode.useFirebase) return;

    try {
      final metaRef = _db.doc(AppConstants.seedFlagDoc);
      final meta = await metaRef.get();
      if (meta.exists && meta.data()?['productsSeeded'] == true) {
        return;
      }

      final products = getSeedProductsData();
      final batch = _db.batch();
      for (final product in products) {
        final id = product['id'] as String;
        final ref =
            _db.collection(AppConstants.productsCollection).doc(id);
        batch.set(ref, product..remove('id'));
      }
      batch.set(metaRef, {
        'productsSeeded': true,
        'seededAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
    } catch (e) {
      // Non-fatal: catalog may already be seeded.
      rethrow;
    }
  }
}
