import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_mode.dart';
import '../models/app_user.dart';
import '../models/auth_session.dart';
import '../models/product.dart';
import '../models/quote_request.dart';
import '../models/quote_status.dart';
import '../models/supplier_quote.dart';
import '../services/auth_service.dart';
import '../services/product_service.dart';
import '../services/quote_service.dart';
import '../services/seed_service.dart';

/// Keeps catalog scroll position when returning from product details.
final catalogScrollControllerProvider = Provider<ScrollController>((ref) {
  final controller = ScrollController();
  ref.onDispose(controller.dispose);
  return controller;
});

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final productServiceProvider = Provider<ProductService>((ref) => ProductService());
final quoteServiceProvider = Provider<QuoteService>((ref) => QuoteService());
final seedServiceProvider = Provider<SeedService>((ref) => SeedService());

/// Firebase Auth uid stream (legacy compat).
final authStateProvider = StreamProvider<String?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

/// Combined auth + Firestore profile — drives routing and guards.
final authSessionProvider = StreamProvider<AuthSession>((ref) {
  return ref.watch(authServiceProvider).watchAuthSession();
});

/// Current profile from session (null while loading or signed out).
final currentUserProvider = Provider<AsyncValue<AppUser?>>((ref) {
  final session = ref.watch(authSessionProvider);
  return session.when(
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
    data: (s) {
      if (!s.isAuthenticated) return const AsyncValue.data(null);
      if (s.profileMissing) {
        return AsyncValue.error(
          Exception('פרופיל המשתמש לא נמצא בשרת. פנה לתמיכה או הירשם מחדש.'),
          StackTrace.empty,
        );
      }
      return AsyncValue.data(s.profile);
    },
  );
});

final productsProvider = StreamProvider<List<Product>>((ref) {
  if (!AppMode.useFirebase && !AppMode.isDemoMode) {
    return Stream.value(<Product>[]);
  }
  return ref.watch(productServiceProvider).watchProducts();
});

final requestQuotesProvider =
    StreamProvider.family<List<SupplierQuote>, String>((ref, requestId) {
  return ref.watch(quoteServiceProvider).watchQuotesForRequest(requestId);
});

final productCategoriesProvider = FutureProvider<List<String>>((ref) async {
  return ref.watch(productServiceProvider).getCategories();
});

final customerRequestsProvider = StreamProvider<List<QuoteRequest>>((ref) {
  final session = ref.watch(authSessionProvider).valueOrNull;
  final user = session?.profile;
  if (user == null) return Stream.value(<QuoteRequest>[]);
  return ref.watch(quoteServiceProvider).watchCustomerRequests(user.id);
});

final incomingRequestsProvider = StreamProvider<List<QuoteRequest>>((ref) {
  final session = ref.watch(authSessionProvider).valueOrNull;
  final user = session?.profile;
  if (user == null) return Stream.value(<QuoteRequest>[]);
  return ref.watch(quoteServiceProvider).watchIncomingRequestsForSupplier(user.id);
});

final customerReceivedQuotesProvider =
    StreamProvider<List<SupplierQuote>>((ref) {
  final session = ref.watch(authSessionProvider).valueOrNull;
  final user = session?.profile;
  if (user == null) return Stream.value(<SupplierQuote>[]);
  return ref.watch(quoteServiceProvider).watchCustomerReceivedQuotes(user.id);
});

/// Live map: quoteRequestId → total supplier quotes received.
final quoteCountByRequestProvider = StreamProvider<Map<String, int>>((ref) {
  final session = ref.watch(authSessionProvider).valueOrNull;
  final user = session?.profile;
  if (user == null) return Stream.value(<String, int>{});

  return ref.watch(quoteServiceProvider).watchCustomerReceivedQuotes(user.id).map(
    (quotes) {
      final counts = <String, int>{};
      for (final quote in quotes) {
        final id = quote.quoteRequestId;
        counts[id] = (counts[id] ?? 0) + 1;
      }
      return counts;
    },
  );
});

/// Unread supplier quotes per request (for request card badges).
final unreadQuoteCountByRequestProvider =
    StreamProvider<Map<String, int>>((ref) {
  final session = ref.watch(authSessionProvider).valueOrNull;
  final user = session?.profile;
  if (user == null) return Stream.value(<String, int>{});

  return ref
      .watch(quoteServiceProvider)
      .watchCustomerReceivedQuotes(user.id)
      .map((quotes) {
    final counts = <String, int>{};
    for (final quote in quotes) {
      if (!quote.isUnreadByCustomer) continue;
      final id = quote.quoteRequestId;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts;
  });
});

final supplierSentQuotesProvider = StreamProvider<List<SupplierQuote>>((ref) {
  final session = ref.watch(authSessionProvider).valueOrNull;
  final user = session?.profile;
  if (user == null) return Stream.value(<SupplierQuote>[]);
  return ref.watch(quoteServiceProvider).watchSupplierSentQuotes(user.id);
});

final supplierQuoteProvider =
    StreamProvider.family<SupplierQuote?, String>((ref, quoteId) {
  return ref.watch(quoteServiceProvider).watchSupplierQuote(quoteId);
});

final quoteRequestProvider =
    StreamProvider.family<QuoteRequest?, String>((ref, requestId) {
  return ref.watch(quoteServiceProvider).watchQuoteRequest(requestId);
});

final supplierOrdersToFulfillProvider =
    StreamProvider<List<SupplierQuote>>((ref) {
  final session = ref.watch(authSessionProvider).valueOrNull;
  final user = session?.profile;
  if (user == null) return Stream.value(<SupplierQuote>[]);
  return ref.watch(quoteServiceProvider).watchSupplierOrdersToFulfill(user.id);
});

final supplierOrderHistoryProvider =
    StreamProvider<List<SupplierQuote>>((ref) {
  final session = ref.watch(authSessionProvider).valueOrNull;
  final user = session?.profile;
  if (user == null) return Stream.value(<SupplierQuote>[]);
  return ref.watch(quoteServiceProvider).watchSupplierOrderHistory(user.id);
});

// ——— Live count providers (derived from Firestore streams above) ———

final customerRequestsCountProvider = Provider<int>((ref) {
  return ref.watch(customerRequestsProvider).valueOrNull?.length ?? 0;
});

final customerReceivedQuotesCountProvider = Provider<int>((ref) {
  return ref.watch(customerReceivedQuotesProvider).valueOrNull?.length ?? 0;
});

/// Dashboard badges: unread / unseen only.
final customerUnreadRequestsCountProvider = Provider<int>((ref) {
  final requests = ref.watch(customerRequestsProvider).valueOrNull ?? [];
  return requests.where((r) => r.hasUnreadStatusForCustomer()).length;
});

final customerUnreadReceivedQuotesCountProvider = Provider<int>((ref) {
  final quotes = ref.watch(customerReceivedQuotesProvider).valueOrNull ?? [];
  return quotes.where((q) => q.isUnreadByCustomer).length;
});

final customerActiveOrdersProvider = Provider<List<QuoteRequest>>((ref) {
  final requests = ref.watch(customerRequestsProvider).valueOrNull ?? [];
  return requests
      .where(
        (r) =>
            r.status == QuoteRequestStatus.ordered ||
            r.status == QuoteRequestStatus.shipped,
      )
      .toList();
});

final customerActiveOrdersCountProvider = Provider<int>((ref) {
  return ref.watch(customerActiveOrdersProvider).length;
});

final customerUnreadActiveOrdersCountProvider = Provider<int>((ref) {
  return ref
      .watch(customerActiveOrdersProvider)
      .where((r) => r.hasUnreadStatusForCustomer())
      .length;
});

final incomingRequestsCountProvider = Provider<int>((ref) {
  return ref.watch(incomingRequestsProvider).valueOrNull?.length ?? 0;
});

final incomingUnseenCountProvider = Provider<int>((ref) {
  final supplierId = ref.watch(authSessionProvider).valueOrNull?.profile?.id;
  if (supplierId == null) return 0;
  final requests = ref.watch(incomingRequestsProvider).valueOrNull ?? [];
  return requests.where((r) => r.isUnseenBySupplier(supplierId)).length;
});

final supplierSentQuotesCountProvider = Provider<int>((ref) {
  return ref.watch(supplierSentQuotesProvider).valueOrNull?.length ?? 0;
});

final supplierOrdersToFulfillCountProvider = Provider<int>((ref) {
  return ref.watch(supplierOrdersToFulfillProvider).valueOrNull?.length ?? 0;
});

final supplierUnreadOrdersToFulfillCountProvider = Provider<int>((ref) {
  final quotes = ref.watch(supplierOrdersToFulfillProvider).valueOrNull ?? [];
  return quotes.where((q) => q.isUnreadOrderBySupplier).length;
});

final supplierOrderHistoryCountProvider = Provider<int>((ref) {
  return ref.watch(supplierOrderHistoryProvider).valueOrNull?.length ?? 0;
});
