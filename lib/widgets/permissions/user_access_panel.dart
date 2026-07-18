import 'package:flutter/material.dart';

import '../../models/enterprise/membership.dart';
import '../../models/enterprise/organization_type.dart';
import '../../models/enterprise/permission.dart';
import '../../models/enterprise/project.dart';
import '../../services/effective_permissions.dart';
import '../../utils/app_theme.dart';
import '../../utils/enterprise_role_labels.dart';
import 'access_badges.dart';

/// Read-only effective-access breakdown for a single member: identity, role,
/// project-access mode, and every permission with its source — in plain
/// Hebrew, no enum names.
class UserAccessPanel extends StatelessWidget {
  const UserAccessPanel({
    super.key,
    required this.membership,
    this.orgName,
    this.projects = const [],
    this.memberNamesByUid = const {},
  });

  final Membership membership;
  final String? orgName;
  final List<Project> projects;

  /// For resolving the manager uid to a display name.
  final Map<String, String> memberNamesByUid;

  static Future<void> show({
    required BuildContext context,
    required Membership membership,
    String? orgName,
    List<Project> projects = const [],
    Map<String, String> memberNamesByUid = const {},
  }) {
    final panel = UserAccessPanel(
      membership: membership,
      orgName: orgName,
      projects: projects,
      memberNamesByUid: memberNamesByUid,
    );
    final isWide = MediaQuery.sizeOf(context).width >= 700;
    if (isWide) {
      return showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 700),
            child: panel,
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
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (_, controller) => panel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final access = EffectiveAccess.forMembership(membership);
    final byDomain = <PermissionDomain, List<MapEntry<Permission, PermissionSource>>>{};
    for (final entry in access.sources.entries) {
      byDomain.putIfAbsent(entry.key.domain, () => []).add(entry);
    }
    final assignedProjects = projects
        .where((p) => membership.projectIds.contains(p.id))
        .toList();
    final managerName = membership.managerUid != null
        ? memberNamesByUid[membership.managerUid] ?? membership.managerUid
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PanelHeader(membership: membership, orgName: orgName),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              _InfoGrid(entries: [
                ('סטטוס', null, MembershipStatusBadge(status: membership.status)),
                ('תפקיד', null, RoleBadge(role: membership.role, compact: true)),
                if (managerName != null) ('מנהל ישיר', managerName, null),
                if (membership.team?.isNotEmpty == true)
                  ('צוות', membership.team!, null),
              ]),
              if (membership.role != null) ...[
                const SizedBox(height: 8),
                Text(
                  EnterpriseRoleLabels.description(membership.role!),
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (membership.orgType == OrganizationType.contractor) ...[
                _SectionTitle(
                  icon: membership.hasOrgWideProjectAccess
                      ? Icons.public_outlined
                      : Icons.push_pin_outlined,
                  title: 'גישה לפרויקטים',
                ),
                const SizedBox(height: 8),
                if (membership.hasOrgWideProjectAccess)
                  const _HintBox(
                    text: 'גישה לכל פרויקטי החברה — כולל פרויקטים חדשים שיווצרו.',
                  )
                else if (assignedProjects.isEmpty)
                  const _HintBox(
                    text: 'ללא שיוך לפרויקטים — המשתמש אינו רואה אף פרויקט.',
                    warning: true,
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final p in assignedProjects)
                        Chip(
                          label: Text(p.name, style: const TextStyle(fontSize: 12)),
                          avatar: const Icon(Icons.folder_outlined, size: 15),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                const SizedBox(height: 16),
              ],
              if (membership.grants.isNotEmpty || membership.revokes.isNotEmpty) ...[
                const _SectionTitle(
                  icon: Icons.tune_outlined,
                  title: 'התאמות אישיות',
                ),
                const SizedBox(height: 8),
                for (final p in membership.grants)
                  _CustomPermissionRow(
                    permission: p,
                    granted: true,
                  ),
                for (final p in membership.revokes)
                  _CustomPermissionRow(
                    permission: p,
                    granted: false,
                  ),
                const SizedBox(height: 16),
              ],
              const _SectionTitle(
                icon: Icons.verified_user_outlined,
                title: 'הרשאות בפועל',
              ),
              const SizedBox(height: 4),
              const Text(
                'מה המשתמש יכול לעשות בפועל, ומאיפה מגיעה כל הרשאה.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 8),
              for (final domain in PermissionDomain.values)
                if (byDomain[domain]?.isNotEmpty == true)
                  _DomainPermissions(
                    domain: domain,
                    entries: byDomain[domain]!,
                    effective: access.permissions,
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.membership, this.orgName});

  final Membership membership;
  final String? orgName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: AppTheme.gradientNavy,
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.white.withValues(alpha: 0.15),
            child: Text(
              membership.displayLabel.characters.first.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  membership.displayLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (membership.email?.isNotEmpty == true)
                  Text(
                    membership.email!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 12.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                if (orgName != null)
                  Text(
                    orgName!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 11.5,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white70),
            tooltip: 'סגור',
          ),
        ],
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.entries});

  final List<(String, String?, Widget?)> entries;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 24,
      runSpacing: 10,
      children: [
        for (final (label, value, child) in entries)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              child ??
                  Text(
                    value ?? '—',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
            ],
          ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: AppTheme.navy),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ],
    );
  }
}

class _HintBox extends StatelessWidget {
  const _HintBox({required this.text, this.warning = false});

  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final color = warning ? AppTheme.amber : AppTheme.teal;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12.5, height: 1.35)),
    );
  }
}

class _CustomPermissionRow extends StatelessWidget {
  const _CustomPermissionRow({required this.permission, required this.granted});

  final Permission permission;
  final bool granted;

  @override
  Widget build(BuildContext context) {
    final color = granted ? AppTheme.emerald : AppTheme.danger;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            granted ? Icons.add_circle_outline : Icons.remove_circle_outline,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              EnterpriseRoleLabels.permissionHebrew(permission),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Text(
            granted ? 'הוענקה' : 'נחסמה',
            style: TextStyle(
              fontSize: 11.5,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DomainPermissions extends StatelessWidget {
  const _DomainPermissions({
    required this.domain,
    required this.entries,
    required this.effective,
  });

  final PermissionDomain domain;
  final List<MapEntry<Permission, PermissionSource>> entries;
  final Set<Permission> effective;

  @override
  Widget build(BuildContext context) {
    final sorted = [...entries]
      ..sort((a, b) => a.key.index.compareTo(b.key.index));
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.borderColor),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceTint,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusMd),
              ),
            ),
            child: Text(
              EnterpriseRoleLabels.domainHebrew(domain),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
            ),
          ),
          for (final entry in sorted)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              child: Row(
                children: [
                  Icon(
                    effective.contains(entry.key)
                        ? Icons.check_circle
                        : Icons.cancel_outlined,
                    size: 15,
                    color: effective.contains(entry.key)
                        ? AppTheme.emerald
                        : AppTheme.danger.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      EnterpriseRoleLabels.permissionHebrew(entry.key),
                      style: TextStyle(
                        fontSize: 12.5,
                        decoration: effective.contains(entry.key)
                            ? null
                            : TextDecoration.lineThrough,
                        color: effective.contains(entry.key)
                            ? AppTheme.textPrimary
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  PermissionSourceChip(source: entry.value),
                ],
              ),
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
