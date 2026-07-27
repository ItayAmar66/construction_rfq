import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/enterprise_providers.dart';
import '../../utils/app_theme.dart';
import '../../widgets/design_system/design_system.dart';

/// Shown when membership discovery fails (distinct from pending approval).
class MembershipLoadErrorScreen extends ConsumerWidget {
  const MembershipLoadErrorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('טעינת הרשאות')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_reset_outlined,
                  size: 64, color: AppTheme.amberDark),
              const SizedBox(height: 24),
              const Text(
                'לא הצלחנו לטעון הרשאות. נסה לרענן',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'אם הבעיה נמשכת, ודא שהוזמנת לחברה או פנה למנהל המערכת.\n'
                'מנהלי מערכת יכולים להמשיך לקונסולה גם ללא שיוך חברה.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              PrimaryButton.icon(
                icon: Icons.refresh,
                label: 'רענון',
                expand: false,
                onPressed: () =>
                    ref.invalidate(currentUserMembershipsProvider),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
