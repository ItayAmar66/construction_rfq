import 'package:flutter/material.dart';

import '../utils/app_spacing.dart';
import '../utils/app_theme.dart';
import '../utils/hebrew_strings.dart';
import '../utils/rfq_draft_helpers.dart';

class RfqReviewSummaryCard extends StatelessWidget {
  const RfqReviewSummaryCard({
    super.key,
    required this.summary,
    this.hasMissingNotes = false,
  });

  final RfqDraftSummary summary;
  final bool hasMissingNotes;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppTheme.emerald.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            HebrewStrings.rfqReviewReady,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.emerald,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            HebrewStrings.rfqDraftSummary(
              summary.totalLines,
              summary.catalogLines,
              summary.manualLines,
            ),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'סה״כ כמות: ${summary.totalQuantity}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
          if (hasMissingNotes) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              HebrewStrings.rfqMissingNotesHint(summary.linesMissingNotes),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.amber,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            HebrewStrings.rfqReviewTargetingOpen,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}
