import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/models/auth_session.dart';
import 'package:construction_rfq/models/enterprise/audit_event.dart';
import 'package:construction_rfq/models/enterprise/enterprise_role.dart';
import 'package:construction_rfq/models/enterprise/membership.dart';
import 'package:construction_rfq/models/enterprise/organization_invitation.dart';
import 'package:construction_rfq/models/enterprise/organization_type.dart';
import 'package:construction_rfq/models/enterprise/permission.dart';
import 'package:construction_rfq/models/enterprise/project_assignment.dart';
import 'package:construction_rfq/models/user_type.dart';
import 'package:construction_rfq/models/app_user.dart';
import 'package:construction_rfq/providers/admin_providers.dart';
import 'package:construction_rfq/repositories/admin_repository.dart';
import 'package:construction_rfq/providers/enterprise_providers.dart';
import 'package:construction_rfq/providers/providers.dart';
import 'package:construction_rfq/repositories/audit_repository.dart';
import 'package:construction_rfq/repositories/invitation_repository.dart';
import 'package:construction_rfq/repositories/organization_repository.dart';
import 'package:construction_rfq/repositories/project_assignment_repository.dart';
import 'package:construction_rfq/screens/contractor/contractor_company_screen.dart';
import 'package:construction_rfq/screens/invitations/invite_landing_screen.dart';
import 'package:construction_rfq/services/email_invite_service.dart';
import 'package:construction_rfq/services/enterprise_permission_service.dart';
import 'package:construction_rfq/services/mock_store.dart';
import 'package:construction_rfq/utils/invitation_link_builder.dart';
import 'package:construction_rfq/widgets/permissions/audit_events_list.dart';
import 'package:construction_rfq/widgets/permissions/pending_invitations_section.dart';
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
    MockStore.instance.demoMemberships.clear();
    MockStore.instance.demoInvitations.clear();
    MockStore.instance.demoAuditEvents.clear();
    MockStore.instance.demoProjectAssignments.clear();
    MockStore.instance.loginAsDemo(UserType.commercialCustomer);
  });

  group('Invite link', () {
    test('builds path and link', () {
      expect(InvitationLinkBuilder.invitePath('abc'), '/invite/abc');
      expect(InvitationLinkBuilder.inviteLink('abc'), contains('/invite/abc'));
    });

    testWidgets('signed-out shows Hebrew invite message', (tester) async {
      final invite = OrganizationInvitation(
        id: 'inv-guest',
        orgId: 'org-1',
        orgType: OrganizationType.contractor,
        email: 'guest@test.local',
        role: EnterpriseRole.engineer,
        invitedByUid: 'owner-1',
      );
      MockStore.instance.createInvitation(invite);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionProvider.overrideWith(
              (ref) => Stream.value(AuthSession.empty),
            ),
            invitationByIdProvider('inv-guest').overrideWith(
              (ref) async => invite,
            ),
          ],
          child: MaterialApp.router(
            routerConfig: GoRouter(
              routes: [
                GoRoute(
                  path: '/login',
                  builder: (_, __) => const Scaffold(body: Text('login')),
                ),
                GoRoute(
                  path: '/invite/:inviteId',
                  builder: (_, s) => InviteLandingScreen(
                    inviteId: s.pathParameters['inviteId']!,
                  ),
                ),
              ],
              initialLocation: '/invite/inv-guest',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('הוזמנת להצטרף לחברה'), findsOneWidget);
      expect(find.text('התחבר או צור חשבון עם המייל שהוזמן.'), findsOneWidget);
    });

    testWidgets('matching email shows join action', (tester) async {
      final invite = OrganizationInvitation(
        id: 'inv-match',
        orgId: 'org-1',
        orgType: OrganizationType.contractor,
        email: 'match@test.local',
        role: EnterpriseRole.engineer,
        invitedByUid: 'owner-1',
      );
      MockStore.instance.createInvitation(invite);
      final user = AppUser(
        id: MockStore.demoCustomer.id,
        fullName: MockStore.demoCustomer.fullName,
        email: 'match@test.local',
        phone: MockStore.demoCustomer.phone,
        userType: MockStore.demoCustomer.userType,
        city: MockStore.demoCustomer.city,
        createdAt: MockStore.demoCustomer.createdAt,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionProvider.overrideWith(
              (ref) => Stream.value(AuthSession(uid: user.id, profile: user)),
            ),
            invitationByIdProvider('inv-match').overrideWith(
              (ref) async => invite,
            ),
          ],
          child: MaterialApp(
            home: const InviteLandingScreen(inviteId: 'inv-match'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('הצטרף לחברה'), findsOneWidget);
    });

    testWidgets('wrong email blocked', (tester) async {
      final invite = OrganizationInvitation(
        id: 'inv-wrong',
        orgId: 'org-1',
        orgType: OrganizationType.contractor,
        email: 'invited@test.local',
        role: EnterpriseRole.engineer,
        invitedByUid: 'owner-1',
      );
      MockStore.instance.createInvitation(invite);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionProvider.overrideWith(
              (ref) => Stream.value(
                AuthSession(
                  uid: MockStore.demoCustomer.id,
                  profile: MockStore.demoCustomer,
                ),
              ),
            ),
            invitationByIdProvider('inv-wrong').overrideWith(
              (ref) async => invite,
            ),
          ],
          child: MaterialApp(
            home: const InviteLandingScreen(inviteId: 'inv-wrong'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ההזמנה נשלחה למייל אחר'), findsOneWidget);
    });

    testWidgets('accepted status shown', (tester) async {
      final invite = OrganizationInvitation(
        id: 'inv-done',
        orgId: 'org-1',
        orgType: OrganizationType.contractor,
        email: 'done@test.local',
        role: EnterpriseRole.engineer,
        invitedByUid: 'owner-1',
        status: 'accepted',
      );
      final doneUser = AppUser(
        id: MockStore.demoCustomer.id,
        fullName: MockStore.demoCustomer.fullName,
        email: 'done@test.local',
        phone: MockStore.demoCustomer.phone,
        userType: MockStore.demoCustomer.userType,
        city: MockStore.demoCustomer.city,
        createdAt: MockStore.demoCustomer.createdAt,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionProvider.overrideWith(
              (ref) => Stream.value(
                AuthSession(uid: doneUser.id, profile: doneUser),
              ),
            ),
            invitationByIdProvider('inv-done').overrideWith(
              (ref) async => invite,
            ),
          ],
          child: MaterialApp(
            home: const InviteLandingScreen(inviteId: 'inv-done'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ההזמנה כבר התקבלה'), findsOneWidget);
    });
  });

  group('Email delivery foundation', () {
    test('dev delivery returns copy link without secrets', () async {
      final invite = OrganizationInvitation(
        id: 'inv-mail',
        orgId: 'org-1',
        orgType: OrganizationType.contractor,
        email: 'm@test.local',
        role: EnterpriseRole.engineer,
        invitedByUid: 'owner-1',
      );
      final service = DevInviteDeliveryService();
      expect(service.isProductionConfigured, isFalse);
      final result = await service.sendInvitationEmail(invite);
      expect(result.status, InviteDeliveryStatus.copied);
      expect(result.inviteLink, contains('/invite/inv-mail'));
      expect(result.message, contains('העתיק'));
    });

    test('deliverInvitation updates delivery status', () async {
      final repo = InvitationRepository();
      final invite = await repo.createInvitation(
        orgId: 'org-c',
        orgType: OrganizationType.contractor,
        email: 'deliver@test.local',
        role: EnterpriseRole.engineer,
        invitedByUid: 'owner-1',
        canManage: true,
      );
      final result = await repo.deliverInvitation(
        invitation: invite,
        canManage: true,
      );
      expect(result.status, InviteDeliveryStatus.copied);
      final saved = MockStore.instance.getInvitation(invite.id);
      expect(saved?.deliveryStatus, InviteDeliveryStatus.copied);
    });
  });

  group('Audit model and repository', () {
    test('audit event serialization', () {
      final event = AuditEvent(
        id: 'a1',
        actorUid: 'u1',
        orgId: 'org-1',
        entityType: AuditEntityType.invitation,
        entityId: 'inv-1',
        action: AuditAction.invitationCreated,
        summaryHebrew: 'נוצרה הזמנה',
        createdAt: DateTime(2025, 6, 1),
      );
      final parsed = AuditEvent.fromMap('a1', event.toMap());
      expect(parsed.summaryHebrew, 'נוצרה הזמנה');
      expect(parsed.action, AuditAction.invitationCreated);
    });

    test('invite created writes audit event', () async {
      await InvitationRepository().createInvitation(
        orgId: 'org-c',
        orgType: OrganizationType.contractor,
        email: 'audit@test.local',
        role: EnterpriseRole.engineer,
        invitedByUid: 'owner-1',
        canManage: true,
      );
      final events =
          await AuditRepository().watchOrgEvents('org-c').first;
      expect(events.any((e) => e.action == AuditAction.invitationCreated),
          isTrue);
    });

    test('role change writes audit event', () async {
      MockStore.instance.demoMemberships['owner-1'] = Membership(
        uid: 'owner-1',
        orgId: 'org-c',
        orgType: OrganizationType.contractor,
        roles: const [EnterpriseRole.contractorCompanyOwner],
        status: 'active',
      );
      MockStore.instance.demoMemberships['member-1'] = Membership(
        uid: 'member-1',
        orgId: 'org-c',
        orgType: OrganizationType.contractor,
        roles: const [EnterpriseRole.engineer],
        status: 'active',
      );
      await OrganizationRepository().updateMemberRole(
        orgId: 'org-c',
        memberUid: 'member-1',
        newRole: EnterpriseRole.procurementManager,
        actorUid: 'owner-1',
        orgType: OrganizationType.contractor,
      );
      final events =
          await AuditRepository().watchOrgEvents('org-c').first;
      expect(events.any((e) => e.action == AuditAction.roleChanged), isTrue);
    });

    test('project assignment writes audit event', () async {
      await ProjectAssignmentRepository().assignUserToProject(
        projectId: 'p-audit',
        orgId: 'org-c',
        uid: 'eng-1',
        role: EnterpriseRole.engineer,
        actorUid: 'owner-1',
        canManage: true,
      );
      final events =
          await AuditRepository().watchProjectEvents('p-audit').first;
      expect(events.any((e) => e.action == AuditAction.projectAssigned),
          isTrue);
    });
  });

  group('Invite management UI', () {
    testWidgets('pending invites show status and copy link', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PendingInvitationsSection(
              invitations: [
                OrganizationInvitation(
                  id: 'inv-ui',
                  orgId: 'org-1',
                  orgType: OrganizationType.contractor,
                  email: 'ui@test.local',
                  role: EnterpriseRole.engineer,
                  invitedByUid: 'owner-1',
                  createdAt: DateTime(2025, 1, 2),
                ),
              ],
              canManage: true,
              isEmailConfigured: false,
              onCopyLink: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('העתק קישור'), findsOneWidget);
      expect(find.text('ממתין'), findsWidgets);
      expect(find.textContaining('שליחת מייל אמיתית'), findsOneWidget);
    });

    testWidgets('org audit tab empty state', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            orgAuditEventsProvider('org-empty').overrideWith(
              (ref) => Stream.value(const []),
            ),
          ],
          child: const MaterialApp(
            home: OrgAuditHistoryTab(orgId: 'org-empty'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('עדיין אין פעולות להצגה'), findsOneWidget);
    });

    testWidgets('audit event row renders summary', (tester) async {
      final event = AuditEvent(
        id: 'ae-1',
        actorUid: 'admin',
        action: AuditAction.invitationCreated,
        entityType: AuditEntityType.invitation,
        entityId: 'inv-1',
        summaryHebrew: 'נוצרה הזמנה לבדיקה',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AuditEventsList(
              eventsAsync: AsyncValue.data([event]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('נוצרה הזמנה לבדיקה'), findsOneWidget);
    });
  });
}
