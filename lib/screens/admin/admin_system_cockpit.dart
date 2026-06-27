import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../utils/app_theme.dart';

/// Actionable admin management cockpit replacing the static permissions tree.
class AdminSystemCockpit extends StatelessWidget {
  const AdminSystemCockpit({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: AppTheme.navy.withValues(alpha: 0.04),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.dashboard_customize_outlined, color: AppTheme.navy),
                const SizedBox(width: 8),
                Text(
                  'ניהול מערכת',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.navy,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: const Text(
                'מנהל מערכת ≠ מנהל חברה — '
                'מנהל מערכת הוא רמת פלטפורמה בלבד. '
                'מנהל חברה מנהל ארגון קבלן או ספק.',
                style: TextStyle(fontSize: 13, height: 1.35),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'עץ הרשאות מערכת',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'מנהל מערכת ≠ מנהל חברה',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            _CockpitSection(
              title: 'מנהל מערכת',
              description:
                  'בעלים/מנהל פלטפורמה — ניהול כל החברות, הספקים והנתונים.',
            ),
            _CockpitSection(
              title: 'חברות קבלן',
              description: 'ארגוני קבלן וצוותיהם.',
              actionLabel: 'ניהול חברות קבלן',
              onAction: () => context.push('/admin/contractors'),
            ),
            _CockpitSection(
              title: 'ספקים',
              description: 'ארגוני ספק וצוותי מכירות/תפעול.',
              actionLabel: 'ניהול ספקים',
              onAction: () => context.push('/admin/suppliers'),
            ),
            _CockpitSection(
              title: 'משתמשים',
              description: 'כל המשתמשים במערכת.',
              actionLabel: 'ניהול משתמשים',
              onAction: () => context.push('/admin/users'),
            ),
            _CockpitSection(
              title: 'פרויקטים',
              description: 'פרויקטים בכל החברות.',
              actionLabel: 'ניהול פרויקטים',
              onAction: () => context.push('/admin/projects'),
            ),
            _CockpitSection(
              title: 'בקשות / הצעות / הזמנות',
              description: 'מחזור RFQ מלא.',
              comingSoonLabel: 'ניהול בקשות והזמנות יתווסף בהמשך',
            ),
            _CockpitSection(
              title: 'הגדרות ואבטחה',
              description: 'כללי אבטחה והרשאות.',
              comingSoonLabel: 'הגדרות מערכת — בקרוב',
            ),
          ],
        ),
      ),
    );
  }
}

class _CockpitSection extends StatelessWidget {
  const _CockpitSection({
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
    this.comingSoonLabel,
  });

  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? comingSoonLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
              height: 1.3,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ),
          ] else if (comingSoonLabel != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton(
                onPressed: null,
                child: Text(comingSoonLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
