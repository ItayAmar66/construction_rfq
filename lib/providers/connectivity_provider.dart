import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// True when the device reports at least one active network interface.
/// Best-effort only (a Wi-Fi/cell connection can still have no real internet
/// access) — used to surface an honest "offline" state, not to gate writes;
/// Firestore's own offline queueing remains the source of truth for whether
/// a write actually lands.
final isOnlineProvider = StreamProvider<bool>((ref) {
  final connectivity = Connectivity();
  return connectivity.onConnectivityChanged.map(
    (results) => !results.contains(ConnectivityResult.none),
  );
});
