import 'package:flutter/material.dart';

import '../../models/enterprise/enterprise_role.dart';
import '../../models/enterprise/membership.dart';
import '../../services/effective_permissions.dart';
import '../../utils/app_theme.dart';
import '../../utils/enterprise_role_labels.dart';

/// Shared visual language for roles, statuses, access modes and permission
/// sources across all permissions screens.
abstract final class AccessBadgeStyle {
  static Color roleColor(EnterpriseRole? role) {
    if (role == null) return AppTheme.textSecondary;
    if (role == EnterpriseRole.platformAdmin) return AppTheme.navyDark;
    if (role.isOwnerRole) return AppTheme.navy;
    if (role.isOrgAdminRole) return AppTheme.teal;
    switch (role) {
      case EnterpriseRole.procurementManager:
      case EnterpriseRole.supplierSales:
        return AppTheme.emerald;
      case EnterpriseRole.projectManager:
      case EnterpriseRole.supplierOperations:
        return AppTheme.amber;
      case EnterpriseRole.engineer:
        return AppTheme.tealLight;
      default:
        return AppTheme.textSecondary;
    }
  }
}

class RoleBadge extends StatelessWidget {
  const RoleBadge({super.key, required this.role, this.compact = false});

  final EnterpriseRole? role;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = AccessBadgeStyle.roleColor(role);
    final label = role != null ? EnterpriseRoleLabels.hebrew(role!) : 'ללא תפקיד';
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (role?.isOwnerRole == true) ...[
            Icon(Icons.workspace_premium_outlined, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 11.5 : 12.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MembershipStatusBadge extends StatelessWidget {
  const MembershipStatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      'active' => ('פעיל', AppTheme.emerald, Icons.check_circle_outline),
      'disabled' => ('מושבת', AppTheme.danger, Icons.block_outlined),
      'pending' => ('ממתין', AppTheme.amber, Icons.hourglass_empty),
      'invited' => ('הוזמן', AppTheme.amber, Icons.mail_outline),
      _ => (status, AppTheme.textSecondary, Icons.help_outline),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class ProjectAccessBadge extends StatelessWidget {
  const ProjectAccessBadge({
    super.key,
    required this.membership,
    this.assignedCount,
  });

  final Membership membership;
  final int? assignedCount;

  @override
  Widget build(BuildContext context) {
    final orgWide = membership.hasOrgWideProjectAccess;
    final count = assignedCount ?? membership.projectIds.length;
    final color = orgWide ? AppTheme.teal : AppTheme.navyLight;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            orgWide ? Icons.public_outlined : Icons.push_pin_outlined,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            orgWide ? 'כל הפרויקטים' : '$count פרויקטים משויכים',
            style: TextStyle(fontSize: 11.5, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class PermissionSourceChip extends StatelessWidget {
  const PermissionSourceChip({super.key, required this.source});

  final PermissionSource source;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (source) {
      PermissionSource.role => ('מהתפקיד', AppTheme.teal),
      PermissionSource.customGrant => ('הרשאה מותאמת', AppTheme.amber),
      PermissionSource.revoked => ('נחסמה', AppTheme.danger),
      PermissionSource.platformAdmin => ('מנהל מערכת', AppTheme.navyDark),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
