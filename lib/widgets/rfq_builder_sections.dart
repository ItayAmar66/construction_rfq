import 'package:flutter/material.dart';

import '../utils/app_spacing.dart';
import '../utils/app_theme.dart';
import '../utils/hebrew_strings.dart';
import '../utils/rfq_draft_helpers.dart';

class RfqDraftSummaryBar extends StatelessWidget {
  const RfqDraftSummaryBar({super.key, required this.summary});

  final RfqDraftSummary summary;

  @override
  Widget build(BuildContext context) {
    if (!summary.hasLines) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppTheme.teal.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.teal.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            HebrewStrings.rfqDraftSummary(
              summary.totalLines,
              summary.catalogLines,
              summary.manualLines,
            ),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          if (summary.linesMissingNotes > 0) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              HebrewStrings.rfqMissingNotesHint(summary.linesMissingNotes),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class RfqBuilderStepHeader extends StatelessWidget {
  const RfqBuilderStepHeader({
    super.key,
    required this.currentStep,
  });

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    const steps = [
      HebrewStrings.rfqBuilderStepItems,
      HebrewStrings.rfqBuilderStepDetails,
      HebrewStrings.rfqBuilderStepSend,
    ];

    return Row(
      children: List.generate(steps.length, (index) {
        final step = index + 1;
        final active = step <= currentStep;
        return Expanded(
          child: Row(
            children: [
              if (index > 0)
                Expanded(
                  child: Container(
                    height: 2,
                    color: active
                        ? AppTheme.teal.withValues(alpha: 0.4)
                        : AppTheme.borderColor,
                  ),
                ),
              Column(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor:
                        active ? AppTheme.teal : AppTheme.surfaceTint,
                    child: Text(
                      '$step',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: active ? Colors.white : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    steps[index],
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: active
                              ? AppTheme.textPrimary
                              : AppTheme.textSecondary,
                          fontWeight:
                              step == currentStep ? FontWeight.w600 : null,
                        ),
                  ),
                ],
              ),
              if (index < steps.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    color: step < currentStep
                        ? AppTheme.teal.withValues(alpha: 0.4)
                        : AppTheme.borderColor,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}

class RfqDraftSectionHeader extends StatelessWidget {
  const RfqDraftSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs, top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: AppTheme.teal),
                const SizedBox(width: AppSpacing.xs),
              ],
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Padding(
              padding: EdgeInsetsDirectional.only(
                start: icon != null ? 26 : 0,
              ),
              child: Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
