import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/account_status.dart';
import '../../providers/providers.dart';
import '../../utils/auth_logout_flow.dart';
import '../../utils/hebrew_strings.dart';

/// Shown when a registered user awaits platform or company approval.
class PendingApprovalScreen extends ConsumerWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authSessionProvider).valueOrNull?.profile;
    final isBlocked = user?.accountStatus == AccountStatus.blocked;
    final theme = Theme.of(context);

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
                    Icons.hourglass_top_outlined,
                    size: 56,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isBlocked ? 'החשבון חסום' : 'החשבון ממתין לאישור',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isBlocked
                        ? 'פנה לתמיכה לקבלת עזרה.'
                        : 'ההרשמה נקלטה, אך עדיין לא אושרה על ידי מנהל המערכת או מנהל החברה.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                  ),
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
