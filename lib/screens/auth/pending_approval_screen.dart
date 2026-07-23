import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/account_status.dart';
import '../../providers/providers.dart';
import '../../utils/app_theme.dart';
import '../../utils/auth_logout_flow.dart';
import '../../utils/hebrew_strings.dart';
import '../../widgets/auth/auth_scaffold.dart';

/// Shown when a registered user awaits approval or account is blocked/rejected.
class PendingApprovalScreen extends ConsumerWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authSessionProvider).valueOrNull?.profile;
    final status = user?.accountStatus ?? AccountStatus.pendingApproval;
    final theme = Theme.of(context);

    final title = switch (status) {
      AccountStatus.rejected => 'הבקשה נדחתה',
      AccountStatus.disabled || AccountStatus.blocked => 'החשבון מושבת',
      AccountStatus.pendingApproval => 'החשבון ממתין לאישור',
      AccountStatus.active => 'החשבון ממתין לאישור',
    };

    final body = switch (status) {
      AccountStatus.rejected =>
        'הבקשה שלך לגישה למערכת נדחתה. ניתן לפנות למנהל החברה או למנהל המערכת.',
      AccountStatus.disabled || AccountStatus.blocked =>
        'החשבון הושבת. פנה למנהל החברה או למנהל המערכת.',
      AccountStatus.pendingApproval =>
        'ההרשמה נקלטה. מנהל החברה או מנהל המערכת יאשרו את הגישה שלך בקרוב.',
      AccountStatus.active => 'ההרשמה נקלטה.',
    };

    final (icon, accent) = switch (status) {
      AccountStatus.rejected => (Icons.cancel_outlined, AppTheme.danger),
      AccountStatus.disabled ||
      AccountStatus.blocked =>
        (Icons.block_outlined, AppTheme.textSecondary),
      AccountStatus.pendingApproval ||
      AccountStatus.active =>
        (Icons.hourglass_top_outlined, AppTheme.amber),
    };

    return AuthScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: AuthBrandmark()),
          const SizedBox(height: 28),
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: accent),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
              height: 1.45,
            ),
          ),
          if (user?.requestedOrgName?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 18),
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceTint,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.apartment_outlined,
                        size: 16, color: AppTheme.textSecondary),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'חברה מבוקשת: ${user!.requestedOrgName}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 26),
          FilledButton.icon(
            onPressed: () => signOutAndGoLogin(context, ref),
            icon: const Icon(Icons.logout, size: 18),
            label: const Text(HebrewStrings.logout),
          ),
        ],
      ),
    );
  }
}
