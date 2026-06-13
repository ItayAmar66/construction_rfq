/// Helpers for distinguishing real Firestore org ids from legacy UI fallbacks.
abstract final class OrgIdHelpers {
  static bool isLegacyFallback(String? orgId) {
    if (orgId == null || orgId.isEmpty) return true;
    return orgId.startsWith('legacy-');
  }

  static bool isRealOrgId(String? orgId) => !isLegacyFallback(orgId);
}
