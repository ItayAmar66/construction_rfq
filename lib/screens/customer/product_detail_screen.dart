import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/product.dart';
import '../../providers/cart_provider.dart';
import '../../providers/providers.dart';
import '../../utils/app_feedback.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_typography.dart';
import '../../utils/hebrew_strings.dart';
import '../../widgets/app_back_leading.dart';
import '../../widgets/app_fade_in.dart';
import '../../widgets/app_list_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  int _quantity = 1;
  Product? _product;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final product =
        await ref.read(productServiceProvider).getProduct(widget.productId);
    if (mounted) {
      setState(() {
        _product = product;
        _loading = false;
      });
    }
  }

  void _addToCart() {
    if (_product == null) return;
    ref.read(cartProvider.notifier).addProduct(_product!, quantity: _quantity);
    AppFeedback.showSuccess(context, HebrewStrings.productAddedToCart);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        appBar: SecondaryAppBar(title: HebrewStrings.details),
        body: LoadingView(),
      );
    }

    final product = _product;
    if (product == null) {
      return const Scaffold(
        appBar: SecondaryAppBar(title: HebrewStrings.details),
        body: EmptyState(
          message: 'מוצר לא נמצא',
          icon: Icons.inventory_2_outlined,
        ),
      );
    }

    return Scaffold(
      appBar: SecondaryAppBar(title: product.name),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: AppFadeIn(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 140,
                decoration: AppTheme.cardDecoration().copyWith(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.teal.withValues(alpha: 0.08),
                      AppTheme.navy.withValues(alpha: 0.04),
                    ],
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.inventory_2_outlined,
                    size: 56,
                    color: AppTheme.teal.withValues(alpha: 0.85),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (product.brand.isNotEmpty || product.sku.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (product.brand.isNotEmpty)
                      _MetaChip(label: product.brand, icon: Icons.sell_outlined),
                    if (product.sku.isNotEmpty)
                      _MetaChip(label: product.sku, icon: Icons.qr_code_2_outlined),
                    _MetaChip(label: product.category, icon: Icons.category_outlined),
                  ],
                ),
              const SizedBox(height: AppSpacing.sm),
              Text(product.name, style: AppTypography.h1(context)),
              const SizedBox(height: AppSpacing.xs),
              Text(
                product.packagingSummary,
                style: AppTypography.bodySecondary(context),
              ),
              const SizedBox(height: AppSpacing.md),
              _SpecGrid(product: product),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: AppTheme.cardDecoration(elevation: 1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      HebrewStrings.description,
                      style: AppTypography.h2(context),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      product.description,
                      style: AppTypography.body(context).copyWith(height: 1.45),
                    ),
                  ],
                ),
              ),
              if (product.relatedProductIds.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text('מוצרים קשורים', style: AppTypography.h2(context)),
                const SizedBox(height: AppSpacing.sm),
                _RelatedProductsSection(ids: product.relatedProductIds),
              ],
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: AppTheme.cardDecoration(elevation: 1),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: _quantity > 1
                          ? () => setState(() => _quantity--)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text(
                      '${HebrewStrings.quantity}: $_quantity',
                      style: AppTypography.body(context),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _quantity++),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton.icon(
                onPressed: _addToCart,
                icon: const Icon(Icons.add_shopping_cart_outlined, size: 20),
                label: const Text(HebrewStrings.addToCart),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.surfaceTint,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.teal),
          const SizedBox(width: 4),
          Text(label, style: AppTypography.micro(context)),
        ],
      ),
    );
  }
}

class _SpecGrid extends StatelessWidget {
  const _SpecGrid({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final entries = <MapEntry<String, String>>[
      MapEntry('סוג', product.variant),
      MapEntry(HebrewStrings.unit, product.unitType),
      ...product.specs.entries,
    ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: AppTheme.cardDecoration(elevation: 1),
      child: Column(
        children: entries.map((e) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(e.key, style: AppTypography.caption(context)),
                ),
                Text(
                  e.value,
                  style: AppTypography.body(context).copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _RelatedProductsSection extends ConsumerWidget {
  const _RelatedProductsSection({required this.ids});

  final List<String> ids;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: Future.wait(
        ids.take(4).map(
          (id) => ref.read(productServiceProvider).getProduct(id),
        ),
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final products = snapshot.data!.whereType<Product>().toList();
        if (products.isEmpty) return const SizedBox.shrink();
        return Column(
          children: products.map((p) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppListCard(
                onTap: () => context.push('/product/${p.id}'),
                title: p.name,
                subtitle: p.brand.isNotEmpty ? p.brand : p.variant,
                meta: p.packagingSummary,
                leading: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.teal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    color: AppTheme.teal,
                    size: 20,
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
