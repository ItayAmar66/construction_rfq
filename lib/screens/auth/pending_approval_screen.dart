import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/account_status.dart';
import '../../providers/enterprise_providers.dart';
import '../../providers/providers.dart';
import '../../utils/hebrew_strings.dart';

/// Shown when a registered user awaits platform or company approval.
class PendingApprovalScreen extends ConsumerWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider).valueOrNull;
    final user = session?.profile;
    final hasMembership =
        (ref.watch(currentUserMembershipsProvider).valueOrNull ?? const [])
            .any((m) => m.status == 'active');

    return Scaffold(
      appBar: AppBar(title: const Text('ממתין לאישור')),
      body: Center(
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
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  user?.accountStatus == AccountStatus.blocked
                      ? 'החשבון חסום'
                      : 'ממתין לאישור מנהל מערכת',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  user?.accountStatus == AccountStatus.blocked
                      ? 'פנה לתמיכה לקבלת עזרה.'
                      : hasMembership
                          ? 'החשבון מחובר לארגון. ממתין להפעלה מלאה.'
                          : 'ניתן להתחבר, אך שימוש במערכת ייפתח לאחר אישור מנהל מערכת '
                              'או הזמנה ממנהל חברה/ספק קיים.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.4,
                      ),
                ),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () async {
                    await ref.read(authServiceProvider).logout();
                    if (context.mounted) {
                      // ignore: use_build_context_synchronously
                      Navigator.of(context).popUntil((r) => r.isFirst);
                    }
                  },
                  child: const Text(HebrewStrings.logout),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
