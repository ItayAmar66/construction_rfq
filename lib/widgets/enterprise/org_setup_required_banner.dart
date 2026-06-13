import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';

/// Shown when team/invite features need a real organization document.
class OrgSetupRequiredBanner extends StatelessWidget {
  const OrgSetupRequiredBanner({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceTint,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.business_outlined, color: AppTheme.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message ??
                  'נדרש ארגון פעיל לניהול צוות והזמנות. '
                  'חשבונות מסחריים יקבלו ארגון אוטומטית; '
                  'אם הבעיה נמשכת פנו לתמיכה.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                    height: 1.35,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
