import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _connectivityProvider = Provider<Connectivity>((ref) => Connectivity());

/// Raw OS-level connectivity changes (wifi/cellular/none), not a guarantee
/// of actual internet reachability.
final connectivityStatusProvider =
    StreamProvider<List<ConnectivityResult>>((ref) {
  final connectivity = ref.watch(_connectivityProvider);
  return connectivity.onConnectivityChanged;
});

/// True once we've positively observed no network interface is connected.
/// Defaults to false (assume online) while the first reading is pending, so
/// the banner doesn't flash on a normal cold start.
final isOfflineProvider = Provider<bool>((ref) {
  final status = ref.watch(connectivityStatusProvider);
  return status.maybeWhen(
    data: (results) =>
        results.isEmpty || results.every((r) => r == ConnectivityResult.none),
    orElse: () => false,
  );
});
