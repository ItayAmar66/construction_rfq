import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_mode.dart';
import '../providers/providers.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/profile_error_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/customer/cart_screen.dart';
import '../screens/customer/customer_dashboard_screen.dart';
import '../screens/customer/customer_active_orders_screen.dart';
import '../screens/customer/customer_quote_detail_screen.dart';
import '../screens/customer/customer_received_quotes_screen.dart';
import '../screens/customer/customer_requests_screen.dart';
import '../screens/customer/product_catalog_screen.dart';
import '../screens/customer/product_detail_screen.dart';
import '../screens/customer/quote_compare_screen.dart';
import '../screens/customer/request_confirmation_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/supplier/incoming_requests_screen.dart';
import '../screens/supplier/supplier_dashboard_screen.dart';
import '../screens/supplier/supplier_order_detail_screen.dart';
import '../screens/supplier/supplier_orders_history_screen.dart';
import '../screens/supplier/supplier_orders_to_fulfill_screen.dart';
import '../screens/supplier/supplier_quote_response_screen.dart';
import '../screens/supplier/sent_quotes_screen.dart';
import '../widgets/loading_view.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authSessionProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final sessionAsync = ref.read(authSessionProvider);
      final location = state.matchedLocation;
      final isAuthRoute =
          location == '/login' || location == '/register';
      final isSplash = location == '/';
      final isProfileError = location == '/profile-error';

      return sessionAsync.when(
        loading: () => isSplash ? null : '/',
        error: (_, __) => isAuthRoute ? null : '/login',
        data: (session) {
          if (!session.isAuthenticated) {
            return isAuthRoute || isSplash ? null : '/login';
          }

          if (session.profileMissing) {
            return isProfileError ? null : '/profile-error';
          }

          if (session.profile == null) {
            return isSplash ? null : '/';
          }

          if (isAuthRoute || isSplash || isProfileError) {
            return '/home';
          }

          return null;
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
        path: '/profile-error',
        builder: (_, __) => const ProfileErrorScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (_, __) {
          final session = ref.read(authSessionProvider).valueOrNull;
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
        path: '/catalog',
        builder: (_, __) => const ProductCatalogScreen(),
      ),
      GoRoute(
        path: '/product/:id',
        builder: (_, state) =>
            ProductDetailScreen(productId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/cart', builder: (_, __) => const CartScreen()),
      GoRoute(
        path: '/request-confirmation',
        builder: (_, state) => RequestConfirmationScreen(
          requestId: state.uri.queryParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: '/my-requests',
        builder: (_, __) => const CustomerRequestsScreen(),
      ),
      GoRoute(
        path: '/active-orders',
        builder: (_, __) => const CustomerActiveOrdersScreen(),
      ),
      GoRoute(
        path: '/received-quotes',
        builder: (_, __) => const CustomerReceivedQuotesScreen(),
      ),
      GoRoute(
        path: '/compare-quotes/:requestId',
        builder: (_, state) => QuoteCompareScreen(
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
        path: '/incoming',
        builder: (_, __) => const IncomingRequestsScreen(),
      ),
      GoRoute(
        path: '/respond/:requestId',
        builder: (_, state) => SupplierQuoteResponseScreen(
          requestId: state.pathParameters['requestId']!,
        ),
      ),
      GoRoute(
        path: '/sent-quotes',
        builder: (_, __) => const SentQuotesScreen(),
      ),
      GoRoute(
        path: '/supplier/orders',
        builder: (_, __) => const SupplierOrdersToFulfillScreen(),
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
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
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
