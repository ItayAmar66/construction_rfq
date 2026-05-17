import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_mode.dart';
import '../models/product.dart';
import 'mock_store.dart';
import '../utils/constants.dart';

class ProductService {
  ProductService({FirebaseFirestore? firestore}) : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  Stream<List<Product>> watchProducts({String? categoryQuery}) {
    if (AppMode.isDemoMode) {
      return _filterByCategory(MockStore.instance.watchProducts(), categoryQuery);
    }

    return _filterByCategory(
      _db.collection(AppConstants.productsCollection).snapshots().map(
        (snapshot) {
          final products = snapshot.docs
              .map((d) => Product.fromMap(d.id, d.data()))
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));
          return products;
        },
      ),
      categoryQuery,
    );
  }

  Stream<List<Product>> _filterByCategory(
    Stream<List<Product>> source,
    String? categoryQuery,
  ) {
    return source.map((products) {
      if (categoryQuery == null || categoryQuery.isEmpty) return products;
      return products.where((p) => p.category == categoryQuery).toList();
    });
  }

  Future<Product?> getProduct(String id) async {
    if (AppMode.isDemoMode) return MockStore.instance.getProduct(id);

    try {
      final doc = await _db
          .collection(AppConstants.productsCollection)
          .doc(id)
          .get();
      if (!doc.exists) return null;
      return Product.fromMap(doc.id, doc.data()!);
    } catch (e) {
      if (AppMode.isDemoMode) return MockStore.instance.getProduct(id);
      throw Exception(FirebaseErrorHelper.toHebrewMessage(e));
    }
  }

  Future<List<String>> getCategories() async {
    if (AppMode.isDemoMode) return MockStore.instance.getCategories();

    try {
      final snapshot =
          await _db.collection(AppConstants.productsCollection).get();
      final categories = snapshot.docs
          .map((d) => d.data()['category'] as String? ?? '')
          .where((c) => c.isNotEmpty)
          .toSet()
          .toList();
      categories.sort();
      return categories;
    } catch (e) {
      if (AppMode.isDemoMode) return MockStore.instance.getCategories();
      throw Exception(FirebaseErrorHelper.toHebrewMessage(e));
    }
  }
}
