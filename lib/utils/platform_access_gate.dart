import 'package:flutter/foundation.dart';

import '../models/account_status.dart';

/// Resolved app entry gate after auth + membership bootstrap.
enum PlatformAccessGate {
  loading,
  granted,
  pendingApproval,
  noPermission,
  membershipError,
}

abstract final class PlatformAccessGateResolver {
  static Duration get bootstrapTimeout =>
      kDebugMode ? Duration.zero : const Duration(seconds: 10);

  static PlatformAccessGate resolve({
    required bool isAuthenticated,
    required bool membershipSettled,
    required bool hasPlatformAccess,
    required AccountStatus? accountStatus,
    required bool membershipLoadError,
    required bool isPlatformAdmin,
  }) {
    if (!isAuthenticated) return PlatformAccessGate.loading;
    if (!membershipSettled) return PlatformAccessGate.loading;

    final status = accountStatus ?? AccountStatus.active;
    if (!isPlatformAdmin &&
        (status == AccountStatus.pendingApproval ||
            status == AccountStatus.blocked)) {
      return PlatformAccessGate.pendingApproval;
    }

    if (hasPlatformAccess || isPlatformAdmin) {
      return PlatformAccessGate.granted;
    }
    if (membershipLoadError && !isPlatformAdmin) {
      return PlatformAccessGate.membershipError;
    }
    return PlatformAccessGate.noPermission;
  }
}
