import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/models/auth_session.dart';
import 'package:construction_rfq/models/quote_request.dart';
import 'package:construction_rfq/models/quote_request_item.dart';
import 'package:construction_rfq/models/quote_status.dart';
import 'package:construction_rfq/models/user_type.dart';
import 'package:construction_rfq/repositories/project_repository.dart';
import 'package:construction_rfq/repositories/request_repository.dart';
import 'package:construction_rfq/models/auth_session.dart';
import 'package:construction_rfq/providers/project_providers.dart';
import 'package:construction_rfq/providers/providers.dart';
import 'package:construction_rfq/services/mock_store.dart';
import 'package:construction_rfq/utils/hebrew_strings.dart';
import 'package:construction_rfq/utils/project_display_helpers.dart';
import 'package:construction_rfq/widgets/projects/dashboard_projects_section.dart';
import 'package:construction_rfq/widgets/projects/project_context_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return ProviderScope(
    overrides: [
      authSessionProvider.overrideWith(
        (ref) => Stream.value(
          AuthSession(
            uid: MockStore.instance.currentUser?.id,
            profile: MockStore.instance.currentUser,
          ),
        ),
      ),
    ],
    child: MaterialApp(home: child),
  );
}

QuoteRequest _requestWithProject() {
  return QuoteRequest(
    id: 'r1',
    customerId: 'c1',
    customerName: 'קבלן',
    customerPhone: '050',
    customerCity: 'תל אביב',
    customerType: 'commercialCustomer',
    status: QuoteRequestStatus.sent,
    createdAt: DateTime(2026),
    projectId: 'p1',
    projectName: 'מגדלי הים',
    projectLocation: 'אתר 12 · הרצליה',
  );
}

void main() {
  setUp(() {
    AppMode.enableDemoMode();
    MockStore.instance.init();
    MockStore.instance.projects.clear();
    MockStore.instance.quoteRequests.clear();
    MockStore.instance.loginAsDemo(UserType.commercialCustomer);
  });

  group('Project model/repository', () {
    test('create project saves model', () async {
      final repo = ProjectRepository();
      final project = await repo.createProject(
        ownerUid: 'cust-1',
        name: 'מגדלי הים',
        location: 'אתר 12',
        cityOrArea: 'הרצליה',
      );
      expect(project.name, 'מגדלי הים');
      expect(project.ownerUid, 'cust-1');
      expect(project.locationLine, contains('אתר 12'));
      expect(MockStore.instance.projects.length, 1);
    });
  });

  group('Project display', () {
    test('chip label includes project prefix', () {
      expect(
        ProjectDisplayHelpers.chipLabel(_requestWithProject()),
        'פרויקט: מגדלי הים · אתר 12 · הרצליה',
      );
    });

    test('legacy request without project still works', () {
      final request = QuoteRequest(
        id: 'r2',
        customerId: 'c1',
        customerName: 'קבלן',
        customerPhone: '050',
        customerCity: 'תל אביב',
        customerType: 'commercialCustomer',
        status: QuoteRequestStatus.sent,
        createdAt: DateTime(2026),
      );
      expect(ProjectDisplayHelpers.chipLabel(request), isNull);
    });
  });

  group('RFQ submit', () {
    test('submit writes project snapshots', () async {
      MockStore.instance.loginAsDemo(UserType.commercialCustomer);
      final customer = MockStore.instance.currentUser!;
      final repo = RequestRepository();
      final requestId = await repo.submitQuoteRequest(
        customer: customer,
        requestItems: const [
          QuoteRequestItem(
            id: 'i1',
            quoteRequestId: '',
            productId: 'p1',
            productName: 'דבק',
            category: 'דבקים',
            unitType: 'יח',
            quantity: 2,
          ),
        ],
        projectId: 'proj-1',
        projectName: 'מגדל א',
        projectLocation: 'רחוב הים 1',
      );
      final saved = MockStore.instance.quoteRequests
          .firstWhere((r) => r.id == requestId);
      expect(saved.projectId, 'proj-1');
      expect(saved.projectName, 'מגדל א');
      expect(saved.projectLocation, 'רחוב הים 1');
    });

    test('submit without project still works', () async {
      MockStore.instance.loginAsDemo(UserType.commercialCustomer);
      final customer = MockStore.instance.currentUser!;
      final repo = RequestRepository();
      final requestId = await repo.submitQuoteRequest(
        customer: customer,
        requestItems: const [
          QuoteRequestItem(
            id: 'i1',
            quoteRequestId: '',
            productId: 'p1',
            productName: 'דבק',
            category: 'דבקים',
            unitType: 'יח',
            quantity: 1,
          ),
        ],
      );
      final saved = MockStore.instance.quoteRequests
          .firstWhere((r) => r.id == requestId);
      expect(saved.projectId, isNull);
    });
  });

  testWidgets('home empty state shows create first project', (tester) async {
    await tester.pumpWidget(_wrap(const DashboardProjectsSection()));
    await tester.pumpAndSettle();
    expect(find.text(HebrewStrings.emptyProjects), findsOneWidget);
    expect(find.text(HebrewStrings.createFirstProject), findsOneWidget);
  });

  testWidgets('project card appears after project exists', (tester) async {
    MockStore.instance.createProject(
      ownerUid: MockStore.instance.currentUser!.id,
      name: 'פרויקט בדיקה',
      location: 'אתר 3',
      cityOrArea: 'חיפה',
    );

    await tester.pumpWidget(_wrap(const DashboardProjectsSection()));
    await tester.pumpAndSettle();
    expect(find.text('פרויקט בדיקה'), findsOneWidget);
    expect(find.text(HebrewStrings.newProjectRequest), findsOneWidget);
  });

  testWidgets('project context chip renders on request', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProjectContextChip(request: _requestWithProject()),
        ),
      ),
    );
    expect(find.textContaining('פרויקט: מגדלי הים'), findsOneWidget);
  });
}
