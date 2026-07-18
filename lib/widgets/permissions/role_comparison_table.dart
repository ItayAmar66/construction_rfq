import 'package:flutter/material.dart';

import '../../models/enterprise/enterprise_role.dart';
import '../../models/enterprise/organization_type.dart';
import '../../models/enterprise/permission.dart';
import '../../services/enterprise_permission_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/enterprise_role_labels.dart';
import 'access_badges.dart';

/// Side-by-side comparison of the default permissions of every role in one
/// organization type — rows are permissions grouped by domain, columns are
/// roles.
class RoleComparisonTable extends StatelessWidget {
  const RoleComparisonTable({super.key, required this.orgType});

  final OrganizationType orgType;

  static Future<void> show({
    required BuildContext context,
    required OrganizationType orgType,
  }) {
    final table = RoleComparisonTable(orgType: orgType);
    final isWide = MediaQuery.sizeOf(context).width >= 700;
    if (isWide) {
      return showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860, maxHeight: 720),
            child: table,
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
        builder: (_, __) => table,
      ),
    );
  }

  List<EnterpriseRole> get _roles => orgType == OrganizationType.contractor
      ? const [
          EnterpriseRole.contractorOwner,
          EnterpriseRole.contractorAdmin,
          EnterpriseRole.procurementManager,
          EnterpriseRole.projectManager,
          EnterpriseRole.engineer,
          EnterpriseRole.contractorViewer,
        ]
      : const [
          EnterpriseRole.supplierOwner,
          EnterpriseRole.supplierAdmin,
          EnterpriseRole.supplierSales,
          EnterpriseRole.supplierOperations,
          EnterpriseRole.supplierViewer,
        ];

  @override
  Widget build(BuildContext context) {
    final roles = _roles;
    final permissionsByRole = {
      for (final role in roles)
        role: EnterprisePermissionService.permissionsForRole(role),
    };
    final relevantPermissions = Permission.values
        .where((p) => permissionsByRole.values.any((set) => set.contains(p)))
        .toList();
    final byDomain = <PermissionDomain, List<Permission>>{};
    for (final p in relevantPermissions) {
      byDomain.putIfAbsent(p.domain, () => []).add(p);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
          child: Row(
            children: [
              const Icon(Icons.compare_arrows_outlined,
                  size: 20, color: AppTheme.navy),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'השוואת תפקידים',
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
            'הרשאות ברירת המחדל של כל תפקיד. התאמות אישיות של משתמש ספציפי אינן מוצגות כאן.',
            style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: _buildTable(byDomain, roles, permissionsByRole),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTable(
    Map<PermissionDomain, List<Permission>> byDomain,
    List<EnterpriseRole> roles,
    Map<EnterpriseRole, Set<Permission>> permissionsByRole,
  ) {
    const labelWidth = 190.0;
    const roleWidth = 92.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(width: labelWidth),
            for (final role in roles)
              SizedBox(
                width: roleWidth,
                child: Center(child: RoleBadge(role: role, compact: true)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        for (final domain in PermissionDomain.values)
          if (byDomain[domain]?.isNotEmpty == true) ...[
            Container(
              width: labelWidth + roleWidth * roles.length,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                color: AppTheme.surfaceTint,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                EnterpriseRoleLabels.domainHebrew(domain),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ),
            for (final permission in byDomain[domain]!)
              Row(
                children: [
                  SizedBox(
                    width: labelWidth,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      child: Text(
                        EnterpriseRoleLabels.permissionHebrew(permission),
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                  ),
                  for (final role in roles)
                    SizedBox(
                      width: roleWidth,
                      child: Center(
                        child: permissionsByRole[role]!.contains(permission)
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
          ],
      ],
    );
  }
}
