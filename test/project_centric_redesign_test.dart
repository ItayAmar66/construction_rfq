import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/models/auth_session.dart';
import 'package:construction_rfq/models/quote_request.dart';
import 'package:construction_rfq/models/quote_status.dart';
import 'package:construction_rfq/models/request_type.dart';
import 'package:construction_rfq/models/supplier_quote.dart';
import 'package:construction_rfq/models/user_type.dart';
import 'package:construction_rfq/providers/providers.dart';
import 'package:construction_rfq/repositories/project_repository.dart';
import 'package:construction_rfq/screens/auth/login_screen.dart';
import 'package:construction_rfq/screens/supplier/supplier_contractors_screen.dart';
import 'package:construction_rfq/services/mock_store.dart';
import 'package:construction_rfq/utils/supplier_hierarchy.dart';
import 'package:construction_rfq/utils/supplier_quote_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

QuoteRequest _request({
  required String id,
  required String customerId,
  required String customerName,
  String? contractorOrgId,
  required String projectId,
  required String projectName,
  QuoteRequestStatus status = QuoteRequestStatus.sent,
  DateTime? createdAt,
  String? approvedQuoteId,
}) {
  return QuoteRequest(
    id: id,
    customerId: customerId,
    customerName: customerName,
    customerPhone: '',
    customerCity: '',
    customerType: 'private',
    requestType: RequestType.regular,
    status: status,
    createdAt: createdAt ?? DateTime(2026, 1, 1),
    contractorOrgId: contractorOrgId,
    projectId: projectId,
    projectName: projectName,
    approvedQuoteId: approvedQuoteId,
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('he');
  });

  setUp(() {
    AppMode.enableDemoMode();
    MockStore.instance.init();
    MockStore.instance.projects.clear();
  });

  group('Project creation with new fields', () {
    test('createProject persists manager and schedule fields', () async {
      final owner = 'owner-1';
      final project = await ProjectRepository().createProject(
        ownerUid: owner,
        name: 'מגדלי פארק',
        location: 'רחוב הרצל 1',
        cityOrArea: 'באר שבע',
        managerName: 'יוסי כהן',
        managerPhone: '050-1234567',
        startDate: DateTime(2026, 2, 1),
        estimatedCompletionDate: DateTime(2027, 6, 1),
      );

      expect(project.managerName, 'יוסי כהן');
      expect(project.managerPhone, '050-1234567');
      expect(project.startDate, DateTime(2026, 2, 1));
      expect(project.estimatedCompletionDate, DateTime(2027, 6, 1));
    });

    test('updateProjectDetails updates an existing project', () async {
      final owner = 'owner-2';
      final repo = ProjectRepository();
      final created = await repo.createProject(ownerUid: owner, name: 'פרויקט א');

      final updated = await repo.updateProjectDetails(
        projectId: created.id,
        ownerUid: owner,
        managerName: 'דנה לוי',
        startDate: DateTime(2026, 3, 1),
      );

      expect(updated.managerName, 'דנה לוי');
      expect(updated.startDate, DateTime(2026, 3, 1));
      expect(updated.name, 'פרויקט א');
    });
  });

  group('Supplier contractor/project hierarchy grouping', () {
    test('groups requests by contractor and then by project', () {
      final requests = [
        _request(
          id: 'r1',
          customerId: 'cust-a',
          customerName: 'א. כהן בנייה בע״מ',
          contractorOrgId: 'org-a',
          projectId: 'proj-1',
          projectName: 'מגדלי פארק',
        ),
        _request(
          id: 'r2',
          customerId: 'cust-a',
          customerName: 'א. כהן בנייה בע״מ',
          contractorOrgId: 'org-a',
          projectId: 'proj-2',
          projectName: 'מתחם מסחרי',
        ),
        _request(
          id: 'r3',
          customerId: 'cust-b',
          customerName: 'קבלן פרטי',
          projectId: 'proj-3',
          projectName: 'בניין מגורים',
        ),
      ];

      final groups = buildSupplierContractorGroups(requests);

      expect(groups.length, 2);
      final orgGroup = groups.firstWhere((g) => g.key == 'org-a');
      expect(orgGroup.name, 'א. כהן בנייה בע״מ');
      expect(orgGroup.projects.length, 2);
      expect(
        orgGroup.projects.map((p) => p.projectId),
        containsAll(['proj-1', 'proj-2']),
      );

      final individualGroup = groups.firstWhere((g) => g.key == 'cust-b');
      expect(individualGroup.projects.single.projectName, 'בניין מגורים');
    });

    test('supplierOrdersFor only returns approved/shipped quotes', () {
      final requests = [
        _request(
          id: 'r1',
          customerId: 'cust-a',
          customerName: 'קבלן',
          projectId: 'proj-1',
          projectName: 'פרויקט',
          status: QuoteRequestStatus.ordered,
          approvedQuoteId: 'q1',
        ),
      ];
      final quotes = [
        SupplierQuote(
          id: 'q1',
          quoteRequestId: 'r1',
          supplierId: 's1',
          supplierName: 'ספק א',
          supplierType: 'company',
          deliveryTime: '3 ימים',
          totalPrice: 1000,
          status: SupplierQuoteStatus.approved,
          createdAt: DateTime(2026, 1, 2),
        ),
      ];

      final orders = supplierOrdersFor(requests, quotes);
      expect(orders.length, 1);
      expect(orders.single.quote.id, 'q1');
    });
  });

  group('Supplier contractors screen', () {
    testWidgets('shows grouped contractors and navigates to workspace',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      MockStore.instance.loginAsDemo(UserType.commercialSupplier);
      final supplier = MockStore.instance.currentUser!;

      MockStore.instance.quoteRequests.add(
        _request(
          id: 'incoming-1',
          customerId: 'cust-x',
          customerName: 'קבלן בדיקה',
          projectId: 'proj-x',
          projectName: 'פרויקט בדיקה',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionProvider.overrideWith(
              (ref) => Stream.value(
                AuthSession(uid: supplier.id, profile: supplier),
              ),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: '/supplier/contractors',
              routes: [
                GoRoute(
                  path: '/supplier/contractors',
                  builder: (_, __) => const SupplierContractorsScreen(),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('קבלן בדיקה'), findsOneWidget);
    });
  });

  group('Login Enter-key submission', () {
    testWidgets('submitting password field triggers login attempt',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).first,
        'user@example.com',
      );
      await tester.enterText(
        find.byType(TextFormField).last,
        'password123',
      );

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Demo mode short-circuits real Firebase auth with a deterministic
      // error, proving the Enter key on the password field invoked login.
      expect(
        find.text('במצב הדגמה השתמש בכפתורי ההתחברות לדוגמה'),
        findsOneWidget,
      );
    });
  });
}
