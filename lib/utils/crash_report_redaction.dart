/// Strips likely-sensitive substrings from developer-authored crash-report
/// text (log messages/reasons) before it leaves the device. Defense-in-depth
/// only — call sites should already avoid logging secrets/PII directly.
abstract final class CrashReportRedaction {
  static final _email = RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+');
  // Long opaque tokens: Firebase Auth ID tokens, invite/doc ids, API keys…
  static final _longToken = RegExp(r'\b[A-Za-z0-9_-]{24,}\b');

  static String redact(String text) {
    return text
        .replaceAll(_email, '[email]')
        .replaceAll(_longToken, '[redacted]');
  }
}
