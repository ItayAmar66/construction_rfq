import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/enterprise_providers.dart';
import '../../providers/providers.dart';
import '../../utils/app_theme.dart';
import '../../utils/enterprise_role_labels.dart';
import '../status_chip.dart';

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

    return StatusChip(
      label: label,
      foreground: AppTheme.navy,
      background: AppTheme.teal.withValues(alpha: 0.12),
      bordered: false,
    );
  }
}
