import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Runs [action] only when [mounted]; avoids Riverpod ref use after dispose.
void safeRefAction<T extends ConsumerState>(
  T state,
  void Function(WidgetRef ref) action,
) {
  if (!state.mounted) return;
  action(state.ref);
}
