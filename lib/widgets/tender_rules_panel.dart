import 'package:flutter/material.dart';

import '../utils/app_spacing.dart';
import '../utils/app_theme.dart';

/// Explains tender rules to customers and suppliers.
class TenderRulesPanel extends StatelessWidget {
  const TenderRulesPanel({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final rules = [
      'המכרז פתוח לכל הספקים הרשומים באזור',
      'ספקים יכולים להגיש הצעות נגד עד סיום הזמן',
      'זהות הספקים מוסתרת מהלקוח במהלך המכרז',
      'לאחר סגירה — השוואה מלאה והצעה מנצחת',
    ];

    return Container(
      padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
      decoration: AppTheme.cardDecoration(
        color: AppTheme.navy.withValues(alpha: 0.04),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: AppTheme.navy),
              const SizedBox(width: 8),
              Text(
                'כללי מכרז',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.navy,
                    ),
              ),
            ],
          ),
          SizedBox(height: compact ? AppSpacing.xs : AppSpacing.sm),
          ...rules.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: TextStyle(
                      color: AppTheme.teal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      r,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            height: 1.35,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
