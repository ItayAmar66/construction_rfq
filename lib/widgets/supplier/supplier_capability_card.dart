import 'package:flutter/material.dart';

import '../../utils/app_spacing.dart';
import '../../utils/app_theme.dart';
import '../../utils/supplier_capability_helpers.dart';

/// Read-only supplier capabilities on profile (foundation).
class SupplierCapabilityCard extends StatelessWidget {
  const SupplierCapabilityCard({
    super.key,
    required this.profile,
  });

  final SupplierCapabilityProfile profile;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'יכולות ספק',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _Row(label: 'קטגוריות', value: profile.categoriesLabel),
            const SizedBox(height: AppSpacing.xs),
            _Row(label: 'אזורי שירות', value: profile.areasLabel),
            const SizedBox(height: AppSpacing.xs),
            _Row(label: 'עיר', value: profile.city),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
