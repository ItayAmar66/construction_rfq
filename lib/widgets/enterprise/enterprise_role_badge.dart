import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/enterprise_providers.dart';
import '../../providers/providers.dart';
import '../../utils/app_theme.dart';
import '../../utils/enterprise_role_labels.dart';

class EnterpriseRoleBadge extends ConsumerWidget {
  const EnterpriseRoleBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authSessionProvider).valueOrNull?.profile;
    final memberships =
        ref.watch(currentUserMembershipsProvider).valueOrNull ?? const [];
    final label = EnterpriseRoleLabels.primaryLabel(
      user: user,
      memberships: memberships,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.teal.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppTheme.navy,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
