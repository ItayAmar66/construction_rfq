import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';
import '../../utils/enterprise_hierarchy_presets.dart';
import 'permission_hierarchy_tree.dart';
import 'role_read_only_notice.dart';

/// Compact project team hierarchy section for project workspace.
class ProjectTeamHierarchySection extends StatelessWidget {
  const ProjectTeamHierarchySection({super.key});

  @override
  Widget build(BuildContext context) {
    final preset = EnterpriseHierarchyPresets.projectTeam;
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              preset.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'הרשאות החברה קובעות מה המשתמש יכול לעשות. '
              'שיוך לפרויקט קובע באיזה פרויקט הוא יכול לעבוד.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceTint,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: const Row(
                children: [
                  Icon(Icons.group_outlined, size: 20, color: AppTheme.textSecondary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'עדיין לא הוגדר צוות לפרויקט',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            PermissionHierarchyTree(
              root: preset.root,
              showHeader: false,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.person_add_outlined, size: 18),
                  label: const Text('שייך משתמש לפרויקט'),
                ),
                OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('ערוך הרשאות בפרויקט'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const RoleReadOnlyNotice(
              message: 'יופעל לאחר חיבור ניהול משתמשים מלא',
              showDisabledButton: false,
            ),
          ],
        ),
      ),
    );
  }
}
