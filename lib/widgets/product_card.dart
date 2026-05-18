import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/product.dart';
import '../utils/app_spacing.dart';
import '../utils/app_theme.dart';
import 'app_list_card.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return AppListCard(
      onTap: () => context.push('/product/${product.id}'),
      title: product.name,
      subtitle: '${product.variant} · ${product.unitType}',
      meta: product.category,
      leading: _ProductImagePlaceholder(category: product.category),
    );
  }
}

class _ProductImagePlaceholder extends StatelessWidget {
  const _ProductImagePlaceholder({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppTheme.teal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.xs),
      ),
      child: Icon(
        Icons.inventory_2_outlined,
        color: AppTheme.teal,
        size: 24,
      ),
    );
  }
}
