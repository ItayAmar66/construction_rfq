import 'package:flutter/material.dart';

import '../utils/app_spacing.dart';
import '../utils/app_theme.dart';
import '../utils/hebrew_strings.dart';
import '../utils/rfq_draft_helpers.dart';

class RfqDraftSubmitBar extends StatelessWidget {
  const RfqDraftSubmitBar({
    super.key,
    required this.summary,
    required this.supplierNames,
    required this.onSubmit,
    required this.submitting,
  });

  final RfqDraftSummary summary;
  final List<String> supplierNames;
  final VoidCallback onSubmit;
  final bool submitting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final supplierLabel = supplierNames.isEmpty
        ? 'פתוח לכל הספקים'
        : supplierNames.join(' · ');

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        border: const Border(top: BorderSide(color: AppTheme.borderColor)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.navy.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${summary.totalLines} פריטים · ${summary.totalQuantity} יח׳',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'יעד: $supplierLabel',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            onPressed: submitting ? null : onSubmit,
            icon: submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_outlined),
            label: Text(
              submitting ? 'שולח...' : HebrewStrings.submitRequest,
            ),
          ),
        ],
      ),
    );
  }
}
