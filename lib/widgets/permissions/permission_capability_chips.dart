import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';

/// Compact capability chips for a role.
class PermissionCapabilityChips extends StatelessWidget {
  const PermissionCapabilityChips({
    super.key,
    required this.capabilities,
    this.maxVisible = 6,
  });

  final List<String> capabilities;
  final int maxVisible;

  @override
  Widget build(BuildContext context) {
    if (capabilities.isEmpty) return const SizedBox.shrink();

    final visible = capabilities.take(maxVisible).toList();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final cap in visible)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.surfaceTint,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Text(
              cap,
              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ),
      ],
    );
  }
}
