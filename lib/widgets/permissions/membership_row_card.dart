import 'package:flutter/material.dart';

import '../../models/enterprise/membership.dart';
import '../../utils/app_theme.dart';
import '../../utils/enterprise_role_labels.dart';

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
    final roleLabel =
        role != null ? EnterpriseRoleLabels.hebrew(role) : 'ללא תפקיד';
    final name =
        displayName?.isNotEmpty == true ? displayName! : membership.uid;
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
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  if (email != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      email!,
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 10,
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.teal.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.teal.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppTheme.teal,
        ),
      ),
    );
  }
}
