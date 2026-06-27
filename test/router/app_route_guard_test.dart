import 'package:construction_rfq/router/app_route_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppRouteGuard deep links', () {
    test('catalog with projectId is preserved during bootstrap', () {
      expect(AppRouteGuard.preserveLocationDuringBootstrap('/catalog'), isTrue);
      expect(AppRouteGuard.isSupportedDeepLink('/catalog'), isTrue);
      expect(AppRouteGuard.isShellDeepLink('/catalog'), isTrue);
    });

    test('project workspace route is a deep link', () {
      expect(
        AppRouteGuard.isSupportedDeepLink('/projects/qa-proj-alpha'),
        isTrue,
      );
      expect(
        AppRouteGuard.preserveLocationDuringBootstrap('/projects/qa-proj-alpha'),
        isTrue,
      );
    });

    test('compare quotes route is a deep link', () {
      expect(
        AppRouteGuard.isSupportedDeepLink('/compare-quotes/rfq-123'),
        isTrue,
      );
      expect(
        AppRouteGuard.preserveLocationDuringBootstrap('/compare-quotes/rfq-123'),
        isTrue,
      );
    });

    test('request confirmation route is a deep link', () {
      expect(
        AppRouteGuard.isSupportedDeepLink('/request-confirmation'),
        isTrue,
      );
    });

    test('system routes are not preserved as deep links', () {
      expect(AppRouteGuard.preserveLocationDuringBootstrap('/'), isFalse);
      expect(AppRouteGuard.preserveLocationDuringBootstrap('/login'), isFalse);
      expect(AppRouteGuard.preserveLocationDuringBootstrap('/home'), isTrue);
    });
  });
}
