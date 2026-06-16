import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/enterprise_providers.dart';
import '../providers/providers.dart';
import 'auth_logout_redirect.dart';

/// Signs out, clears auth-related providers, and navigates to login.
Future<void> signOutAndGoLogin(BuildContext context, WidgetRef ref) async {
  final container = ProviderScope.containerOf(context, listen: false);
  container.read(forceLoginProvider.notifier).state = true;

  try {
    await ref.read(authServiceProvider).logout();
  } catch (_) {
    // Best-effort sign-out; still escape no-permission on web.
  }

  container.invalidate(currentUserMembershipsProvider);
  container.read(forceLoginProvider.notifier).state = false;

  if (usesHardWebLoginRedirect) {
    hardRedirectToLogin();
    return;
  }

  if (context.mounted) {
    context.go('/login');
  }
}
