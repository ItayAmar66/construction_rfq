import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/models/auth_session.dart';
import 'package:construction_rfq/models/quote_request.dart';
import 'package:construction_rfq/models/supplier_quote.dart';
import 'package:construction_rfq/providers/dashboard_analytics_provider.dart';
import 'package:construction_rfq/providers/dashboard_tasks_provider.dart';
import 'package:construction_rfq/providers/providers.dart';
import 'package:construction_rfq/screens/customer/customer_dashboard_screen.dart';
import 'package:construction_rfq/services/mock_store.dart';
import 'package:construction_rfq/utils/hebrew_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUp(() {
    AppMode.enableDemoMode();
    MockStore.instance.init();
  });

  tearDown(() {
    AppMode.isDemoMode = false;
  });

  setUpAll(() async {
    await initializeDateFormatting('he');
  });

  testWidgets('customer dashboard shows catalog RFQ entry action', (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith(
            (ref) => AsyncValue.data(MockStore.demoCustomer),
          ),
          authSessionProvider.overrideWith(
            (ref) => Stream.value(
              AuthSession(
                uid: MockStore.demoCustomer.id,
                profile: MockStore.demoCustomer,
              ),
            ),
          ),
          customerRequestsProvider.overrideWith(
            (ref) => Stream.value(<QuoteRequest>[]),
          ),
          customerReceivedQuotesProvider.overrideWith(
            (ref) => Stream.value(<SupplierQuote>[]),
          ),
          customerDashboardTasksProvider.overrideWith((ref) => const []),
          customerDashboardAnalyticsProvider.overrideWith(
            (ref) => const CustomerDashboardAnalytics(
              totalRequests: 0,
              activeRequests: 0,
              receivedQuotesCount: 0,
              approvedOrders: 0,
              monthlySpending: 0,
              unreadQuotes: 0,
              unreadRequestUpdates: 0,
              recentQuotes: [],
              recentRequests: [],
            ),
          ),
        ],
        child: const MaterialApp(home: CustomerDashboardScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text(HebrewStrings.loadingDashboard), findsNothing);

    final entry = find.byKey(const Key('customer_catalog_rfq_entry'));
    if (entry.evaluate().isEmpty) {
      final scrollable = find.descendant(
        of: find.byType(CustomerDashboardScreen),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        entry,
        120,
        scrollable: scrollable,
      );
    }
    await tester.pumpAndSettle();

    expect(entry, findsOneWidget);
    expect(find.text(HebrewStrings.openCatalogForRfq), findsOneWidget);
    expect(find.text(HebrewStrings.openCatalogForRfqHint), findsOneWidget);
  });
}
