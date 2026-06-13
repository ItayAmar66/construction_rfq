import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';

/// Read-only notice for permission editing not yet enabled.
class RoleReadOnlyNotice extends StatelessWidget {
  const RoleReadOnlyNotice({
    super.key,
    this.message =
        'עריכת הרשאות תופעל אחרי חיבור משתמשים והרשאות מלא',
    this.showDisabledButton = true,
  });

  final String message;
  final bool showDisabledButton;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.amber.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.amber.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                size: 18,
                color: AppTheme.amber.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontSize: 13, height: 1.35),
                ),
              ),
            ],
          ),
        ),
        if (showDisabledButton) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.lock_outline, size: 18),
            label: const Text('עריכת הרשאות בקרוב'),
          ),
        ],
      ],
    );
  }
}
