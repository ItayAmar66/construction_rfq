/// Platform admin detection — never trust client profile fields alone.
abstract final class PlatformAdmin {
  static const claimKey = 'platformAdmin';

  /// UI-only bootstrap until custom claim is assigned (not used for Firestore auth).
  static const bootstrapEmails = [
    'itayamar206@gmail.com',
    'admin@admin.com',
  ];

  static bool fromCustomClaims(Map<String, dynamic>? claims) {
    if (claims == null) return false;
    final value = claims[claimKey];
    return value == true || value == 'true';
  }

  static bool fromBootstrapAllowlist({
    required String uid,
    required String email,
    List<String> allowedUids = const [],
    List<String> allowedEmails = const [],
  }) {
    if (allowedUids.contains(uid)) return true;
    final normalized = email.trim().toLowerCase();
    return allowedEmails.map((e) => e.trim().toLowerCase()).contains(normalized);
  }
}
