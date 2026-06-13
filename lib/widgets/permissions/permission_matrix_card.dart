import 'package:flutter/material.dart';

import '../../models/enterprise/hierarchy_node.dart';
import '../../utils/app_theme.dart';
import 'permission_capability_chips.dart';

/// Compact role permission summary card for matrix display.
class PermissionMatrixCard extends StatelessWidget {
  const PermissionMatrixCard({
    super.key,
    required this.summary,
  });

  final RoleCapabilitySummary summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              summary.title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.navy,
                  ),
            ),
            const SizedBox(height: 8),
            PermissionCapabilityChips(capabilities: summary.capabilities),
          ],
        ),
      ),
    );
  }
}

/// Row of permission matrix cards.
class PermissionMatrixSection extends StatelessWidget {
  const PermissionMatrixSection({
    super.key,
    required this.title,
    required this.summaries,
  });

  final String title;
  final List<RoleCapabilitySummary> summaries;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        for (final s in summaries) ...[
          PermissionMatrixCard(summary: s),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
