import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';

/// Keeps custom claims (platformAdmin, etc.) fresh app-wide so a revocation
/// is honored promptly instead of waiting for the SDK's own up-to-~1-hour
/// token cache. Forces a re-check (via invalidating authSessionProvider,
/// which force-refreshes the ID token — see AuthService.watchAuthSession):
/// - on every Firebase idToken change event (idTokenChangesProvider)
/// - when the app/tab regains foreground (AppLifecycleState.resumed — on
///   Flutter web this also fires when a hidden tab becomes visible again)
/// - on a periodic fallback timer
///
/// A short cooldown guards against a refresh-triggered token refresh firing
/// idTokenChangesProvider again and re-triggering itself in a loop.
class ClaimRefreshObserver extends ConsumerStatefulWidget {
  const ClaimRefreshObserver({
    super.key,
    required this.child,
    this.periodicInterval = const Duration(minutes: 7),
    this.cooldown = const Duration(seconds: 3),
  });

  final Widget child;
  final Duration periodicInterval;
  final Duration cooldown;

  @override
  ConsumerState<ClaimRefreshObserver> createState() =>
      _ClaimRefreshObserverState();
}

class _ClaimRefreshObserverState extends ConsumerState<ClaimRefreshObserver>
    with WidgetsBindingObserver {
  Timer? _timer;
  DateTime? _lastRefresh;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(widget.periodicInterval, (_) => _refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  void _refresh() {
    if (!mounted) return;
    final now = DateTime.now();
    if (_lastRefresh != null &&
        now.difference(_lastRefresh!) < widget.cooldown) {
      return;
    }
    _lastRefresh = now;
    ref.invalidate(authSessionProvider);
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<void>>(idTokenChangesProvider, (previous, next) {
      // Skip the initial subscription — authSessionProvider already forces
      // a fresh token on its own first build, no need to refresh again.
      if (previous == null) return;
      _refresh();
    });
    return widget.child;
  }
}
