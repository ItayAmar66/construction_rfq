import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_route_guard.dart';

import '../screens/auth/pending_approval_screen.dart';
import '../screens/auth/no_permission_screen.dart';
import '../screens/auth/membership_load_error_screen.dart';
import '../providers/enterprise_providers.dart';
import '../providers/providers.dart';
import '../utils/platform_access_gate.dart';
import '../screens/invitations/invite_landing_screen.dart';
import '../screens/admin/admin_console_screen.dart';
import '../screens/admin/admin_company_detail_screen.dart';
import '../screens/admin/admin_org_list_screen.dart';
import '../screens/admin/admin_projects_screen.dart';
import '../screens/admin/admin_users_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/contractor/contractor_company_screen.dart';
import '../screens/auth/profile_error_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/catalog/catalog_selector_demo_screen.dart';
import '../screens/catalog/material_catalog_screen.dart';
import '../screens/customer/product_catalog_screen.dart';
import '../screens/dev/catalog_admin_ops_screen.dart';
import '../screens/customer/cart_screen.dart';
import '../screens/customer/customer_active_orders_screen.dart';
import '../screens/customer/customer_dashboard_screen.dart';
import '../screens/customer/customer_quote_detail_screen.dart';
import '../screens/customer/customer_received_quotes_screen.dart';
import '../screens/customer/customer_requests_screen.dart';
import '../screens/customer/edit_request_screen.dart';
import '../screens/customer/product_catalog_screen.dart';
import '../screens/customer/product_detail_screen.dart';
import '../screens/customer/quote_compare_screen.dart';
import '../screens/customer/shipment_receipt_confirmation_screen.dart';
import '../screens/customer/request_confirmation_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/projects/project_workspace_screen.dart';
import '../screens/supplier/incoming_requests_screen.dart';
import '../screens/supplier/supplier_company_screen.dart';
import '../screens/supplier/sent_quotes_screen.dart';
import '../screens/supplier/supplier_dashboard_screen.dart';
import '../screens/supplier/supplier_order_detail_screen.dart';
import '../screens/supplier/supplier_orders_history_screen.dart';
import '../screens/supplier/supplier_orders_to_fulfill_screen.dart';
import '../screens/supplier/supplier_quote_response_screen.dart';
import '../screens/supplier/tender_bid_screen.dart';
import '../widgets/app_shell.dart';
import '../widgets/loading_view.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  var refreshScheduled = false;

  void scheduleRefresh() {
    if (refreshScheduled) return;
    refreshScheduled = true;
    scheduleMicrotask(() {
      refreshScheduled = false;
      refresh.value++;
    });
  }

  ref.listen(authSessionProvider, (_, __) => scheduleRefresh());
  ref.listen(resolvedAuthSessionProvider, (_, __) => scheduleRefresh());
  ref.listen(authBootstrapSettledProvider, (_, __) => scheduleRefresh());
  ref.listen(currentUserMembershipsProvider, (_, __) => scheduleRefresh());
  ref.listen(membershipBootstrapSettledProvider, (_, __) => scheduleRefresh());
  ref.listen(platformAccessGateProvider, (_, __) => scheduleRefresh());
  ref.listen(forceLoginProvider, (_, __) => scheduleRefresh());
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final preserveDeepLink =
          AppRouteGuard.preserveLocationDuringBootstrap(location);
      final isAuthRoute = AppRouteGuard.isAuthRoute(location);
      final isInviteRoute = AppRouteGuard.isInviteRoute(location);
      final isSplash = location == '/';
      final isProfileError = location == '/profile-error';
      final isPendingApproval = location == '/pending-approval';
      final isNoPermission = location == '/no-permission';
      final isMembershipError = location == '/membership-error';

      if (ref.read(forceLoginProvider)) {
        return isAuthRoute ? null : '/login';
      }

      final sessionAsync = ref.read(resolvedAuthSessionProvider);

      return sessionAsync.when(
        loading: () {
          if (isSplash || isInviteRoute || preserveDeepLink) return null;
          return '/';
        },
        error: (_, __) => isAuthRoute || isInviteRoute ? null : '/login',
        data: (session) {
          if (!session.isAuthenticated) {
            return isAuthRoute || isInviteRoute ? null : '/login';
          }

          if (session.profileMissing) {
            return isProfileError ? null : '/profile-error';
          }

          if (session.profile == null) {
            if (preserveDeepLink) return null;
            return isSplash ? null : '/';
          }

          final gate = ref.read(platformAccessGateProvider);
          switch (gate) {
            case PlatformAccessGate.loading:
              if (isSplash || isInviteRoute || preserveDeepLink) return null;
              return '/';
            case PlatformAccessGate.membershipError:
              return isMembershipError || isInviteRoute
                  ? null
                  : '/membership-error';
            case PlatformAccessGate.pendingApproval:
              if (isAuthRoute) return null;
              return isPendingApproval || isInviteRoute ? null : '/pending-approval';
            case PlatformAccessGate.noPermission:
              if (isAuthRoute) return null;
              return isNoPermission || isInviteRoute ? null : '/no-permission';
            case PlatformAccessGate.granted:
              if (isPendingApproval ||
                  isNoPermission ||
                  isMembershipError) {
                return '/home';
              }
              if (isAuthRoute || isSplash || isProfileError) {
                return '/home';
              }
              return null;
          }
        },
      );
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(
        path: '/invite/:inviteId',
        builder: (_, state) => InviteLandingScreen(
          inviteId: state.pathParameters['inviteId']!,
        ),
      ),
      GoRoute(
        path: '/profile-error',
        builder: (_, __) => const ProfileErrorScreen(),
      ),
      GoRoute(
        path: '/pending-approval',
        builder: (_, __) => const PendingApprovalScreen(),
      ),
      GoRoute(
        path: '/no-permission',
        builder: (_, __) => const NoPermissionScreen(),
      ),
      GoRoute(
        path: '/membership-error',
        builder: (_, __) => const MembershipLoadErrorScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => AppShell(
          currentPath: state.matchedLocation,
          child: child,
        ),
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, __) {
              final session = ref.read(resolvedAuthSessionProvider).valueOrNull;
              final user = session?.profile;
              if (user == null) {
                return const Scaffold(body: LoadingView());
              }
              if (user.userType.isSupplier) {
                return const SupplierDashboardScreen();
              }
              return const CustomerDashboardScreen();
            },
          ),
          GoRoute(
            path: '/my-requests',
            builder: (_, __) => const CustomerRequestsScreen(),
          ),
          GoRoute(
            path: '/received-quotes',
            builder: (_, __) => const CustomerReceivedQuotesScreen(),
          ),
          GoRoute(
            path: '/catalog',
            builder: (_, __) => const MaterialCatalogScreen(),
          ),
          GoRoute(
            path: '/active-orders',
            builder: (_, __) => const CustomerActiveOrdersScreen(),
          ),
          GoRoute(
            path: '/incoming',
            builder: (_, __) => const IncomingRequestsScreen(),
          ),
          GoRoute(
            path: '/supplier/orders',
            builder: (_, __) => const SupplierOrdersToFulfillScreen(),
          ),
          GoRoute(
            path: '/sent-quotes',
            builder: (_, __) => const SentQuotesScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (_, __) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/admin',
            builder: (_, __) => const AdminConsoleScreen(),
            routes: [
              GoRoute(
                path: 'contractors',
                builder: (_, __) => const AdminContractorCompaniesScreen(),
              ),
              GoRoute(
                path: 'suppliers',
                builder: (_, __) => const AdminSupplierCompaniesScreen(),
              ),
              GoRoute(
                path: 'users',
                builder: (_, __) => const AdminUsersManagementScreen(),
              ),
              GoRoute(
                path: 'projects',
                builder: (_, __) => const AdminProjectsManagementScreen(),
              ),
              GoRoute(
                path: 'company/:orgId',
                builder: (_, state) => AdminCompanyDetailScreen(
                  orgId: state.pathParameters['orgId']!,
                  initialTab: AdminCompanyDetailScreen.tabFromQuery(
                    state.uri.queryParameters['tab'],
                  ),
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/company',
            builder: (_, __) => const ContractorCompanyScreen(),
          ),
          GoRoute(
            path: '/supplier-company',
            builder: (_, __) => const SupplierCompanyScreen(),
          ),
          GoRoute(
            path: '/projects/:projectId',
            builder: (_, state) => ProjectWorkspaceScreen(
              projectId: state.pathParameters['projectId']!,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/product/:id',
        builder: (_, state) =>
            ProductDetailScreen(productId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/cart', builder: (_, __) => const CartScreen()),
      GoRoute(path: '/rfq-draft', builder: (_, __) => const CartScreen()),
      GoRoute(
        path: '/request-confirmation',
        builder: (_, state) => RequestConfirmationScreen(
          requestId: state.uri.queryParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: '/edit-request/:requestId',
        builder: (_, state) => EditRequestScreen(
          requestId: state.pathParameters['requestId']!,
        ),
      ),
      GoRoute(
        path: '/compare-quotes/:requestId',
        builder: (_, state) => QuoteCompareScreen(
          requestId: state.pathParameters['requestId']!,
        ),
      ),
      GoRoute(
        path: '/shipment-receipt/:requestId',
        builder: (_, state) => ShipmentReceiptConfirmationScreen(
          requestId: state.pathParameters['requestId']!,
        ),
      ),
      GoRoute(
        path: '/quote-detail/:quoteId',
        builder: (_, state) => CustomerQuoteDetailScreen(
          quoteId: state.pathParameters['quoteId']!,
          requestId: state.uri.queryParameters['requestId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/respond/:requestId',
        builder: (_, state) => SupplierQuoteResponseScreen(
          requestId: state.pathParameters['requestId']!,
        ),
      ),
      GoRoute(
        path: '/tender/:requestId',
        builder: (_, state) => TenderBidScreen(
          requestId: state.pathParameters['requestId']!,
        ),
      ),
      GoRoute(
        path: '/supplier/orders-history',
        builder: (_, __) => const SupplierOrdersHistoryScreen(),
      ),
      GoRoute(
        path: '/supplier/order/:quoteId',
        builder: (_, state) => SupplierOrderDetailScreen(
          quoteId: state.pathParameters['quoteId']!,
          requestId: state.uri.queryParameters['requestId'] ?? '',
        ),
      ),
      if (kDebugMode) ...[
        GoRoute(
          path: '/dev/legacy-catalog',
          builder: (_, __) => const ProductCatalogScreen(),
        ),
        GoRoute(
          path: '/dev/catalog-selector',
          builder: (_, __) => const CatalogSelectorDemoScreen(),
        ),
        GoRoute(
          path: '/dev/catalog-ops',
          builder: (_, __) => const CatalogAdminOpsScreen(),
        ),
      ],
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('שגיאה')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            state.error?.toString() ?? 'שגיאת ניווט',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  );
});
