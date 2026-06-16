/// Test hook: when true, logout uses hard redirect path on non-web tests.
bool debugSimulateHardWebLoginRedirect = false;

var hardLoginRedirectCount = 0;

bool get usesHardWebLoginRedirect => debugSimulateHardWebLoginRedirect;

/// Non-web: no browser navigation (caller uses GoRouter).
void hardRedirectToLogin() {
  hardLoginRedirectCount++;
}
