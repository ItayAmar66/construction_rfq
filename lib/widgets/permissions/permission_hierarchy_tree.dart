import 'package:flutter/material.dart';

import '../../models/enterprise/hierarchy_node.dart';
import '../../utils/app_theme.dart';
import 'permission_capability_chips.dart';
import 'permission_scope_badge.dart';

/// Single node tile in the hierarchy tree.
class PermissionHierarchyNodeTile extends StatelessWidget {
  const PermissionHierarchyNodeTile({
    super.key,
    required this.node,
    required this.depth,
    this.isLast = false,
  });

  final HierarchyNode node;
  final int depth;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRoot = depth == 0;
    final indent = depth * 16.0;

    return Padding(
      padding: EdgeInsetsDirectional.only(start: indent, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (depth > 0)
            SizedBox(
              width: 20,
              child: Column(
                children: [
                  Container(
                    width: 2,
                    height: 8,
                    color: AppTheme.borderColor,
                  ),
                  Container(
                    width: 10,
                    height: 2,
                    color: AppTheme.borderColor,
                  ),
                ],
              ),
            ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isRoot
                    ? AppTheme.navy.withValues(alpha: 0.04)
                    : Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                  color: isRoot
                      ? AppTheme.navy.withValues(alpha: 0.15)
                      : AppTheme.borderColor,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          node.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight:
                                isRoot ? FontWeight.w700 : FontWeight.w600,
                            fontSize: isRoot ? 15 : 13,
                          ),
                        ),
                      ),
                      PermissionScopeBadge(scope: node.scope),
                    ],
                  ),
                  if (node.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      node.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                  if (node.capabilities.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'יכולות התפקיד',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    PermissionCapabilityChips(capabilities: node.capabilities),
                  ],
                  if (node.canManageChildren && node.childTitles.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'מנהל את: ${node.childTitles.join(' · ')}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppTheme.teal,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Nested permission hierarchy tree.
class PermissionHierarchyTree extends StatelessWidget {
  const PermissionHierarchyTree({
    super.key,
    required this.root,
    this.showHeader = true,
    this.headerTitle = 'עץ הרשאות',
    this.headerSubtitle,
  });

  final HierarchyNode root;
  final bool showHeader;
  final String headerTitle;
  final String? headerSubtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tiles = _flatten(root);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader) ...[
          Text(
            headerTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (headerSubtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              headerSubtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 12),
        ],
        for (var i = 0; i < tiles.length; i++)
          PermissionHierarchyNodeTile(
            node: tiles[i].node,
            depth: tiles[i].depth,
            isLast: i == tiles.length - 1,
          ),
      ],
    );
  }

  static List<_FlatNode> _flatten(HierarchyNode node, [int depth = 0]) {
    final result = <_FlatNode>[_FlatNode(node, depth)];
    for (final child in node.children) {
      result.addAll(_flatten(child, depth + 1));
    }
    return result;
  }
}

class _FlatNode {
  const _FlatNode(this.node, this.depth);
  final HierarchyNode node;
  final int depth;
}
