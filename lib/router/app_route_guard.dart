/// Pure route-guard helpers for GoRouter redirect logic (testable).
abstract final class AppRouteGuard {
  static const systemRoutes = {
    '/',
    '/login',
    '/register',
    '/profile-error',
    '/pending-approval',
    '/no-permission',
    '/membership-error',
  };

  static bool isInviteRoute(String location) => location.startsWith('/invite/');

  static bool isAuthRoute(String location) =>
      location == '/login' || location == '/register';

  static bool isSystemRoute(String location) =>
      systemRoutes.contains(location) || isInviteRoute(location);

  /// Deep links (catalog/project/compare/etc.) must survive auth bootstrap.
  static bool preserveLocationDuringBootstrap(String location) =>
      !isSystemRoute(location);

  static bool isShellDeepLink(String location) {
    if (location.startsWith('/projects/')) return true;
    if (location == '/catalog' || location.startsWith('/catalog?')) return true;
    return const {
      '/home',
      '/my-requests',
      '/received-quotes',
      '/active-orders',
      '/incoming',
      '/supplier/orders',
      '/sent-quotes',
      '/profile',
      '/admin',
      '/company',
      '/supplier-company',
    }.contains(location.split('?').first);
  }

  static bool isRootDeepLink(String location) {
    final path = location.split('?').first;
    if (path.startsWith('/compare-quotes/')) return true;
    if (path.startsWith('/request-confirmation')) return true;
    if (path.startsWith('/quote-detail/')) return true;
    if (path.startsWith('/respond/')) return true;
    if (path.startsWith('/tender/')) return true;
    if (path.startsWith('/edit-request/')) return true;
    if (path.startsWith('/product/')) return true;
    if (path == '/cart' || path == '/rfq-draft') return true;
    return false;
  }

  static bool isSupportedDeepLink(String location) =>
      isShellDeepLink(location) || isRootDeepLink(location);
}
