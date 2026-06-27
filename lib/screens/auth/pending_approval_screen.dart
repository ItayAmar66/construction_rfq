import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/account_status.dart';
import '../../providers/providers.dart';
import '../../utils/auth_logout_flow.dart';
import '../../utils/hebrew_strings.dart';

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

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    status == AccountStatus.rejected
                        ? Icons.cancel_outlined
                        : status == AccountStatus.disabled ||
                                status == AccountStatus.blocked
                            ? Icons.block_outlined
                            : Icons.hourglass_top_outlined,
                    size: 56,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    body,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                  ),
                  if (user?.requestedOrgName?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 12),
                    Text(
                      'חברה מבוקשת: ${user!.requestedOrgName}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => signOutAndGoLogin(context, ref),
                    child: const Text(HebrewStrings.logout),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
