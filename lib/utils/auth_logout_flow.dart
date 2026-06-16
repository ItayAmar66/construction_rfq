import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/enterprise_providers.dart';
import '../providers/providers.dart';

/// Signs out, clears auth-related providers, and navigates to login.
Future<void> signOutAndGoLogin(BuildContext context, WidgetRef ref) async {
  final container = ProviderScope.containerOf(context, listen: false);
  container.read(forceLoginProvider.notifier).state = true;
  if (context.mounted) {
    context.go('/login');
  }

  try {
    await ref.read(authServiceProvider).logout();
  } catch (_) {
    // Still clear local state so the user can escape no-permission screens.
  }

  container.invalidate(currentUserMembershipsProvider);
  unawaited(_clearForceLoginWhenSignedOut(container));
}

Future<void> _clearForceLoginWhenSignedOut(ProviderContainer container) async {
  for (var attempt = 0; attempt < 80; attempt++) {
    final session = container.read(resolvedAuthSessionProvider).valueOrNull;
    if (session == null || !session.isAuthenticated) {
      container.read(forceLoginProvider.notifier).state = false;
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  container.read(forceLoginProvider.notifier).state = false;
}
