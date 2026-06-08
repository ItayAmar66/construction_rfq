import 'package:flutter/material.dart';

import '../utils/app_spacing.dart';
import '../utils/app_theme.dart';
import '../utils/supplier_targeting_helpers.dart';

class RfqSupplierTargetPicker extends StatelessWidget {
  const RfqSupplierTargetPicker({
    super.key,
    required this.selectedNames,
    required this.onChanged,
  });

  final List<String> selectedNames;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'יעד ספקים',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'בחר ספקים ספציפיים לבקשה. ללא בחירה — הבקשה תוצג לכל הספקים הרלוונטיים.',
          style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final name in SupplierTargetingHelpers.qaSupplierPresets)
              FilterChip(
                label: Text(name),
                selected: selectedNames.any(
                  (selected) =>
                      selected.trim().toLowerCase() == name.trim().toLowerCase(),
                ),
                onSelected: (checked) {
                  final next = [...selectedNames];
                  if (checked) {
                    if (!next.any(
                      (selected) =>
                          selected.trim().toLowerCase() == name.trim().toLowerCase(),
                    )) {
                      next.add(name);
                    }
                  } else {
                    next.removeWhere(
                      (selected) =>
                          selected.trim().toLowerCase() == name.trim().toLowerCase(),
                    );
                  }
                  onChanged(next);
                },
              ),
          ],
        ),
        if (selectedNames.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppTheme.amber.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(color: AppTheme.amber.withValues(alpha: 0.25)),
            ),
            child: Text(
              'נבחרו: ${selectedNames.join(' · ')}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
