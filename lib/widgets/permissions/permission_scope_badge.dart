import 'package:flutter/material.dart';

import '../../models/enterprise/hierarchy_node.dart';
import '../../utils/app_theme.dart';

/// Scope badge for hierarchy nodes.
class PermissionScopeBadge extends StatelessWidget {
  const PermissionScopeBadge({super.key, required this.scope});

  final RoleScopeType scope;

  @override
  Widget build(BuildContext context) {
    final color = switch (scope) {
      RoleScopeType.platform => AppTheme.navy,
      RoleScopeType.company => AppTheme.teal,
      RoleScopeType.project => AppTheme.emerald,
      RoleScopeType.supplier => AppTheme.amber,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        scope.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
