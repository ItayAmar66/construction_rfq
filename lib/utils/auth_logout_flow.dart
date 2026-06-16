import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/enterprise_providers.dart';
import '../providers/providers.dart';

/// Signs out, clears auth-related providers, and navigates to login.
Future<void> signOutAndGoLogin(BuildContext context, WidgetRef ref) async {
  try {
    await ref.read(authServiceProvider).logout();
  } catch (_) {
    // Still route to login so the user can escape no-permission screens.
  }
  ref.invalidate(authSessionProvider);
  ref.invalidate(currentUserMembershipsProvider);
  if (context.mounted) {
    context.go('/login');
  }
}
