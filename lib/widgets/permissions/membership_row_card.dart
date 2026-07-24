import 'package:flutter/material.dart';

import '../../models/enterprise/membership.dart';
import '../../utils/app_theme.dart';
import '../../utils/enterprise_role_labels.dart';
import '../status_chip.dart';

/// A single member card in a membership list.
class MembershipRowCard extends StatelessWidget {
  const MembershipRowCard({
    super.key,
    required this.membership,
    this.displayName,
    this.email,
    this.canEditRole = false,
    this.onEditRole,
  });

  final Membership membership;
  final String? displayName;
  final String? email;
  final bool canEditRole;
  final VoidCallback? onEditRole;

  @override
  Widget build(BuildContext context) {
    final role = membership.roles.firstOrNull;
    final roleLabel = role != null ? EnterpriseRoleLabels.hebrew(role) : 'ללא תפקיד';
    final name = displayName?.isNotEmpty == true
        ? displayName!
        : membership.displayLabel;
    final shownEmail = email ?? membership.email;
    final statusLabel = _statusLabel(membership.status);
    final statusColor = _statusColor(membership.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.navy.withValues(alpha: 0.12),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.navy,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  if (shownEmail != null && shownEmail.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      shownEmail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _RoleBadge(label: roleLabel),
                      const SizedBox(width: 6),
                      StatusChip(
                        label: statusLabel,
                        foreground: statusColor,
                        background: statusColor.withValues(alpha: 0.12),
                        dense: true,
                        bordered: false,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (canEditRole && onEditRole != null)
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: 'שינוי תפקיד',
                onPressed: onEditRole,
              ),
          ],
        ),
      ),
    );
  }

  static String _statusLabel(String status) {
    switch (status) {
      case 'active':
        return 'פעיל';
      case 'pending':
        return 'ממתין';
      case 'blocked':
        return 'חסום';
      default:
        return status;
    }
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return AppTheme.emerald;
      case 'pending':
        return AppTheme.amber;
      case 'blocked':
        return AppTheme.danger;
      default:
        return AppTheme.textSecondary;
    }
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return StatusChip(
      label: label,
      foreground: AppTheme.teal,
      background: AppTheme.teal.withValues(alpha: 0.1),
      dense: true,
    );
  }
}
