import 'package:construction_rfq/models/account_status.dart';
import 'package:construction_rfq/models/quote_request.dart';
import 'package:construction_rfq/models/quote_status.dart';
import 'package:construction_rfq/utils/platform_access_gate.dart';
import 'package:construction_rfq/utils/request_exit_navigation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PlatformAccessGateResolver', () {
    test('pending approval user routes to pending gate', () {
      expect(
        PlatformAccessGateResolver.resolve(
          isAuthenticated: true,
          membershipSettled: true,
          hasPlatformAccess: false,
          accountStatus: AccountStatus.pendingApproval,
          membershipLoadError: false,
          isPlatformAdmin: false,
        ),
        PlatformAccessGate.pendingApproval,
      );
    });

    test('active user without membership routes to no permission', () {
      expect(
        PlatformAccessGateResolver.resolve(
          isAuthenticated: true,
          membershipSettled: true,
          hasPlatformAccess: false,
          accountStatus: AccountStatus.active,
          membershipLoadError: false,
          isPlatformAdmin: false,
        ),
        PlatformAccessGate.noPermission,
      );
    });

    test('pending user is not treated as no permission even if access flag wrong', () {
      expect(
        PlatformAccessGateResolver.resolve(
          isAuthenticated: true,
          membershipSettled: true,
          hasPlatformAccess: true,
          accountStatus: AccountStatus.pendingApproval,
          membershipLoadError: false,
          isPlatformAdmin: false,
        ),
        PlatformAccessGate.pendingApproval,
      );
    });
  });

  group('RequestExitNavigation', () {
    test('uses project route when projectId exists', () {
      final request = QuoteRequest(
        id: 'r1',
        customerId: 'c1',
        customerName: 'n',
        customerPhone: 'p',
        customerCity: 'city',
        customerType: 'engineer',
        status: QuoteRequestStatus.sent,
        createdAt: DateTime(2026),
        projectId: 'qa-proj-alpha',
      );
      expect(
        RequestExitNavigation.routeFor(request: request),
        '/projects/qa-proj-alpha',
      );
      expect(
        RequestExitNavigation.labelFor(request: request),
        'חזרה לפרויקט',
      );
    });

    test('falls back to my-requests without project', () {
      expect(RequestExitNavigation.routeFor(), '/my-requests');
      expect(RequestExitNavigation.labelFor(), 'חזרה לבקשות');
    });
  });
}
