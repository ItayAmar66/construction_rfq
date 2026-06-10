import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

class PlatformAdminRoleBadge extends StatelessWidget {
  const PlatformAdminRoleBadge({super.key, this.compact = false});

  static const label = 'מנהל מערכת';

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: AppTheme.navy.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.navy.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.admin_panel_settings_outlined,
            size: compact ? 14 : 16,
            color: AppTheme.navy,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: AppTheme.navy,
              fontWeight: FontWeight.w600,
              fontSize: compact ? 11 : 12,
            ),
          ),
        ],
      ),
    );
  }
}
