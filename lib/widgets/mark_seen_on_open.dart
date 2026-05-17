import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Calls [onMarkSeen] once when the screen is first shown.
class MarkSeenOnOpen extends ConsumerStatefulWidget {
  const MarkSeenOnOpen({
    super.key,
    required this.onMarkSeen,
    required this.child,
  });

  final Future<void> Function(WidgetRef ref) onMarkSeen;
  final Widget child;

  @override
  ConsumerState<MarkSeenOnOpen> createState() => _MarkSeenOnOpenState();
}

class _MarkSeenOnOpenState extends ConsumerState<MarkSeenOnOpen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _mark());
  }

  Future<void> _mark() async {
    try {
      await widget.onMarkSeen(ref);
    } catch (_) {
      // Badge reset is best-effort; list data still loads from Firestore.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
