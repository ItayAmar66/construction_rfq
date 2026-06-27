import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/enterprise_providers.dart';
import '../../utils/hebrew_strings.dart';
import '../../widgets/app_back_leading.dart';

/// Blocks non–platform-admin access to admin management screens.
class AdminPlatformGate extends ConsumerWidget {
  const AdminPlatformGate({
    super.key,
    required this.child,
    this.deniedMessage = 'נדרשת הרשאת מנהל מערכת ב־Firebase',
  });

  final Widget child;
  final String deniedMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(hasPlatformAdminClaimProvider)) {
      return Scaffold(
        appBar: const SecondaryAppBar(title: HebrewStrings.adminConsoleTitle),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              deniedMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      );
    }
    return child;
  }
}

class AdminBackToCockpitButton extends StatelessWidget {
  const AdminBackToCockpitButton({super.key});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => context.go('/admin'),
      icon: const Icon(Icons.arrow_forward),
      label: const Text('חזרה לניהול מערכת'),
    );
  }
}

class AdminBackToOrgListButton extends StatelessWidget {
  const AdminBackToOrgListButton({super.key, required this.listRoute});

  final String listRoute;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => context.go(listRoute),
      icon: const Icon(Icons.arrow_forward),
      label: const Text('חזרה לרשימת חברות'),
    );
  }
}
