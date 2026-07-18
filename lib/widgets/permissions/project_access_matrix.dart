import 'package:flutter/material.dart';

import '../../models/enterprise/membership.dart';
import '../../models/enterprise/project.dart';
import '../../utils/app_theme.dart';
import 'access_badges.dart';

/// Members × projects access matrix for a contractor organization.
///
/// Read-only overview: a cell is checked when the member is assigned to the
/// project or holds org-wide project access (marked with a globe on the row).
class ProjectAccessMatrix extends StatelessWidget {
  const ProjectAccessMatrix({
    super.key,
    required this.members,
    required this.projects,
    this.onTapMember,
  });

  final List<Membership> members;
  final List<Project> projects;
  final ValueChanged<Membership>? onTapMember;

  static Future<void> show({
    required BuildContext context,
    required List<Membership> members,
    required List<Project> projects,
    ValueChanged<Membership>? onTapMember,
  }) {
    final matrix = ProjectAccessMatrix(
      members: members,
      projects: projects,
      onTapMember: onTapMember,
    );
    final isWide = MediaQuery.sizeOf(context).width >= 700;
    if (isWide) {
      return showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860, maxHeight: 720),
            child: matrix,
          ),
        ),
      );
    }
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        builder: (_, __) => matrix,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeMembers =
        members.where((m) => m.status != 'disabled').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
          child: Row(
            children: [
              const Icon(Icons.grid_on_outlined, size: 20, color: AppTheme.navy),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'מטריצת גישה לפרויקטים',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                tooltip: 'סגור',
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'מי רואה איזה פרויקט. סמל הגלובוס מציין גישה לכל פרויקטי החברה.',
            style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: projects.isEmpty
              ? const Center(
                  child: Text(
                    'אין פרויקטים בחברה',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: _buildMatrix(activeMembers),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildMatrix(List<Membership> activeMembers) {
    const nameWidth = 170.0;
    const projectWidth = 110.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const SizedBox(width: nameWidth),
            for (final project in projects)
              SizedBox(
                width: projectWidth,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    project.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (final member in activeMembers)
          InkWell(
            onTap: onTapMember != null ? () => onTapMember!(member) : null,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: AppTheme.borderColor.withValues(alpha: 0.6),
                  ),
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: nameWidth,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 7),
                      child: Row(
                        children: [
                          if (member.hasOrgWideProjectAccess) ...[
                            const Icon(Icons.public_outlined,
                                size: 14, color: AppTheme.teal),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  member.displayLabel,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                RoleBadge(role: member.role, compact: true),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  for (final project in projects)
                    SizedBox(
                      width: projectWidth,
                      child: Center(
                        child: member.hasOrgWideProjectAccess
                            ? const Icon(Icons.check_circle_outline,
                                size: 16, color: AppTheme.teal)
                            : member.projectIds.contains(project.id)
                                ? const Icon(Icons.check_circle,
                                    size: 16, color: AppTheme.emerald)
                                : Icon(Icons.remove,
                                    size: 14,
                                    color: AppTheme.textSecondary
                                        .withValues(alpha: 0.4)),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
