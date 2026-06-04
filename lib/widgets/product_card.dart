import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/product.dart';
import '../utils/app_spacing.dart';
import '../utils/app_theme.dart';
import '../utils/app_typography.dart';
import 'app_list_card.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return AppListCard(
      onTap: () => context.push('/product/${product.id}'),
      title: product.name,
      subtitle:
          '${product.brand.isNotEmpty ? '${product.brand} · ' : ''}${product.packagingSummary}',
      meta: product.sku.isNotEmpty ? product.sku : product.category,
      leading: _ProductThumb(category: product.category),
    );
  }
}

class _ProductThumb extends StatelessWidget {
  const _ProductThumb({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.teal.withValues(alpha: 0.14),
            AppTheme.navy.withValues(alpha: 0.06),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.xs),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, color: AppTheme.teal, size: 22),
          if (category.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                category.length > 6 ? category.substring(0, 6) : category,
                style: AppTypography.micro(context).copyWith(fontSize: 8),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}
