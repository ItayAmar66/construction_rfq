import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/product.dart';
import '../../providers/cart_provider.dart';
import '../../providers/providers.dart';
import '../../utils/hebrew_strings.dart';
import '../../widgets/app_back_leading.dart';

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
    final messenger = ScaffoldMessenger.of(context);
    ref.read(cartProvider.notifier).addProduct(_product!, quantity: _quantity);
    context.pop();
    messenger.showSnackBar(
      const SnackBar(
        content: Text(HebrewStrings.productAddedToCart),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        appBar: SecondaryAppBar(title: HebrewStrings.details),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final product = _product;
    if (product == null) {
      return const Scaffold(
        appBar: SecondaryAppBar(title: HebrewStrings.details),
        body: Center(child: Text('מוצר לא נמצא')),
      );
    }

    return Scaffold(
      appBar: SecondaryAppBar(title: product.name),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            _InfoRow(label: HebrewStrings.category, value: product.category),
            _InfoRow(label: 'סוג', value: product.variant),
            _InfoRow(label: HebrewStrings.unit, value: product.unitType),
            if (product.unitsPerPackage != null)
              _InfoRow(
                label: 'יחידות באריזה',
                value: '${product.unitsPerPackage}',
              ),
            if (product.litersPerBucket != null)
              _InfoRow(
                label: 'ליטר בדלי',
                value: '${product.litersPerBucket}',
              ),
            const SizedBox(height: 12),
            Text(
              HebrewStrings.description,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(product.description),
            const SizedBox(height: 24),
            Row(
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
                  style: const TextStyle(fontSize: 16),
                ),
                IconButton(
                  onPressed: () => setState(() => _quantity++),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _addToCart,
              child: const Text(HebrewStrings.addToCart),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
