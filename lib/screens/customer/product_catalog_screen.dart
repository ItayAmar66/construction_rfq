import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/product.dart';
import '../../providers/providers.dart';
import '../../utils/hebrew_strings.dart';
import '../../widgets/app_back_leading.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_message.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/product_card.dart';

class ProductCatalogScreen extends ConsumerStatefulWidget {
  const ProductCatalogScreen({super.key});

  @override
  ConsumerState<ProductCatalogScreen> createState() =>
      _ProductCatalogScreenState();
}

class _ProductCatalogScreenState extends ConsumerState<ProductCatalogScreen> {
  String _search = '';
  String? _category;
  String? _brand;

  @override
  Widget build(BuildContext context) {
    final scrollController = ref.watch(catalogScrollControllerProvider);
    final productsAsync = ref.watch(productsProvider);
    final categoriesAsync = ref.watch(productCategoriesProvider);

    return Scaffold(
      appBar: SecondaryAppBar(
        title: HebrewStrings.catalog,
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined),
            onPressed: () => context.push('/cart'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                hintText: HebrewStrings.searchHint,
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          categoriesAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (categories) {
              return productsAsync.maybeWhen(
                data: (products) {
                  final brands = products
                      .map((p) => p.brand)
                      .where((b) => b.isNotEmpty)
                      .toSet()
                      .toList()
                    ..sort();
                  return Column(
                    children: [
                      SizedBox(
                        height: 44,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: FilterChip(
                                label: const Text('הכל'),
                                selected: _category == null,
                                onSelected: (_) =>
                                    setState(() => _category = null),
                              ),
                            ),
                            ...categories.map(
                              (c) => Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: FilterChip(
                                  label: Text(c),
                                  selected: _category == c,
                                  onSelected: (_) =>
                                      setState(() => _category = c),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (brands.isNotEmpty)
                        SizedBox(
                          height: 40,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: FilterChip(
                                  label: const Text('כל המותגים'),
                                  selected: _brand == null,
                                  onSelected: (_) =>
                                      setState(() => _brand = null),
                                ),
                              ),
                              ...brands.map(
                                (b) => Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: FilterChip(
                                    label: Text(b),
                                    selected: _brand == b,
                                    onSelected: (_) =>
                                        setState(() => _brand = b),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
                orElse: () => const SizedBox.shrink(),
              );
            },
          ),
          Expanded(
            child: productsAsync.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorMessage.fromError(
                    e,
                    onRetry: () => ref.invalidate(productsProvider),
                  ),
              data: (products) {
                final filtered = _filterProducts(products);
                if (filtered.isEmpty) {
                  return const EmptyState(message: 'לא נמצאו מוצרים');
                }
                return ListView.separated(
                  controller: scrollController,
                  key: const PageStorageKey<String>('product_catalog_list'),
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => ProductCard(product: filtered[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Product> _filterProducts(List<Product> products) {
    return products.where((p) {
      final matchesCategory = _category == null || p.category == _category;
      final matchesBrand = _brand == null || p.brand == _brand;
      final q = _search.trim();
      final matchesSearch = q.isEmpty ||
          p.name.contains(q) ||
          p.category.contains(q) ||
          p.brand.contains(q) ||
          p.sku.contains(q) ||
          p.description.contains(q) ||
          p.variant.contains(q);
      return matchesCategory && matchesBrand && matchesSearch;
    }).toList();
  }
}
