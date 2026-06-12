import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/models/auth_session.dart';
import 'package:construction_rfq/models/enterprise/project.dart';
import 'package:construction_rfq/models/enterprise/project_status.dart';
import 'package:construction_rfq/providers/project_providers.dart';
import 'package:construction_rfq/providers/providers.dart';
import 'package:construction_rfq/repositories/project_repository.dart';
import 'package:construction_rfq/services/mock_store.dart';
import 'package:construction_rfq/screens/projects/project_workspace_screen.dart';
import 'package:construction_rfq/models/user_type.dart';
import 'package:construction_rfq/utils/project_order_helpers.dart';
import 'package:construction_rfq/widgets/projects/catalog_project_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('he');
  });

  setUp(() {
    AppMode.enableDemoMode();
    MockStore.instance.init();
    MockStore.instance.projects.clear();
    MockStore.instance.loginAsDemo(UserType.commercialCustomer);
  });

  group('ProjectOrderHelpers', () {
    Project projectWithStatus(String status) => Project(
          id: 'p1',
          ownerUid: 'u1',
          name: 'אתר בדיקה',
          location: 'תל אביב',
          status: status,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );

    test('active project can start new order', () {
      expect(
        ProjectOrderHelpers.canStartNewOrder(
          projectWithStatus(ProjectStatus.active),
        ),
        isTrue,
      );
      expect(
        ProjectOrderHelpers.blockedMessage(
          projectWithStatus(ProjectStatus.active),
        ),
        isNull,
      );
    });

    test('completed project is blocked', () {
      final p = projectWithStatus(ProjectStatus.completed);
      expect(ProjectOrderHelpers.canStartNewOrder(p), isFalse);
      expect(
        ProjectOrderHelpers.blockedMessage(p),
        contains('הפרויקט הסתיים'),
      );
    });

    test('deletion pending project is blocked', () {
      final p = projectWithStatus(ProjectStatus.deletionPending);
      expect(ProjectOrderHelpers.canStartNewOrder(p), isFalse);
      expect(
        ProjectOrderHelpers.blockedMessage(p),
        contains('ממתין למחיקה'),
      );
    });

    test('catalog route carries projectId', () {
      expect(
        ProjectOrderHelpers.catalogRouteForProject('abc'),
        '/catalog?projectId=abc',
      );
      expect(
        ProjectOrderHelpers.rfqDraftRouteForProject('abc'),
        '/rfq-draft?projectId=abc',
      );
    });
  });

  testWidgets('workspace order CTA opens catalog with projectId',
      (tester) async {
    final owner = MockStore.instance.currentUser!.id;
    final project = await ProjectRepository().createProject(
      ownerUid: owner,
      name: 'Catalog Flow',
      location: 'Site 2',
    );
    String? capturedCatalogProjectId;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(
            (ref) => Stream.value(
              AuthSession(
                uid: owner,
                profile: MockStore.instance.currentUser,
              ),
            ),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/projects/:projectId',
                builder: (_, state) => ProjectWorkspaceScreen(
                  projectId: state.pathParameters['projectId']!,
                ),
              ),
              GoRoute(
                path: '/catalog',
                builder: (_, state) {
                  capturedCatalogProjectId =
                      state.uri.queryParameters['projectId'];
                  return const SizedBox(key: Key('catalog-stub'));
                },
              ),
            ],
            initialLocation: '/projects/${project.id}',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('הזמנה חדשה'), findsOneWidget);
    await tester.tap(find.text('הזמנה חדשה'));
    await tester.pumpAndSettle();

    expect(capturedCatalogProjectId, project.id);
  });

  testWidgets('catalog shows project context banner', (tester) async {
    final owner = MockStore.instance.currentUser!.id;
    final project = await ProjectRepository().createProject(
      ownerUid: owner,
      name: 'Banner Project',
      location: 'חיפה',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(
            (ref) => Stream.value(
              AuthSession(
                uid: owner,
                profile: MockStore.instance.currentUser,
              ),
            ),
          ),
          projectProvider(project.id).overrideWith(
            (ref) => Stream.value(project),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: CatalogProjectBanner(
              projectName: project.name,
              projectLocation: project.locationLine,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('הזמנה לפרויקט: Banner Project'), findsOneWidget);
  });

  testWidgets('completed project shows blocked snackbar on order tap',
      (tester) async {
    final owner = MockStore.instance.currentUser!.id;
    final repo = ProjectRepository();
    final project = await repo.createProject(
      ownerUid: owner,
      name: 'Done Site',
    );
    await repo.completeProject(projectId: project.id, ownerUid: owner);
    var navigatedToCatalog = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(
            (ref) => Stream.value(
              AuthSession(
                uid: owner,
                profile: MockStore.instance.currentUser,
              ),
            ),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/projects/:projectId',
                builder: (_, state) => ProjectWorkspaceScreen(
                  projectId: state.pathParameters['projectId']!,
                ),
              ),
              GoRoute(
                path: '/catalog',
                builder: (_, __) {
                  navigatedToCatalog = true;
                  return const SizedBox();
                },
              ),
            ],
            initialLocation: '/projects/${project.id}',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('הזמנה חדשה'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(navigatedToCatalog, isFalse);
    expect(find.textContaining('הפרויקט הסתיים'), findsOneWidget);
  });
}
