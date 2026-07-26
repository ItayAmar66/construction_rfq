import 'package:construction_rfq/models/app_user.dart';
import 'package:construction_rfq/models/auth_session.dart';
import 'package:construction_rfq/models/enterprise/enterprise_role.dart';
import 'package:construction_rfq/models/enterprise/organization_invitation.dart';
import 'package:construction_rfq/models/enterprise/organization_type.dart';
import 'package:construction_rfq/models/user_type.dart';
import 'package:construction_rfq/utils/auth_error_messages.dart';
import 'package:construction_rfq/providers/providers.dart';
import 'package:construction_rfq/repositories/invitation_repository.dart';
import 'package:construction_rfq/screens/auth/verify_email_screen.dart';
import 'package:construction_rfq/screens/invitations/invite_landing_screen.dart';
import 'package:construction_rfq/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeVerifyAuthService extends AuthService {
  _FakeVerifyAuthService({this.verifiedOnCheck = false, this.resendError});

  int resendCalls = 0;
  int checkCalls = 0;
  final bool verifiedOnCheck;
  final Object? resendError;

  @override
  Future<void> resendVerificationEmail() async {
    resendCalls++;
    if (resendError != null) throw resendError!;
  }

  @override
  Future<bool> refreshVerificationStatus() async {
    checkCalls++;
    return verifiedOnCheck;
  }
}

AuthSession _session({required bool emailVerified}) => AuthSession(
      uid: 'uid-invitee',
      profile: AppUser(
        id: 'uid-invitee',
        fullName: 'משתמש מוזמן',
        email: 'invitee@test.com',
        phone: '050',
        userType: UserType.commercialCustomer,
        city: 'תל אביב',
        createdAt: DateTime(2026),
      ),
      emailVerified: emailVerified,
    );

void main() {
  group('VerifyEmailScreen', () {
    testWidgets('resend sends verification email and starts cooldown',
        (tester) async {
      final fakeAuth = _FakeVerifyAuthService();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(fakeAuth),
            authSessionProvider
                .overrideWith((ref) => Stream.value(_session(emailVerified: false))),
          ],
          child: MaterialApp(
            home: VerifyEmailScreen(redirect: '/pending-approval'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('שלח שוב מייל אימות'), findsOneWidget);
      await tester.tap(find.text('שלח שוב מייל אימות'));
      await tester.pumpAndSettle();

      expect(fakeAuth.resendCalls, 1);
      expect(find.text('מייל אימות חדש נשלח'), findsOneWidget);
      // Cooldown started: button now shows the countdown label, not the
      // original resend label.
      expect(find.text('שלח שוב מייל אימות'), findsNothing);
    });

    testWidgets('resend surfaces a user-facing error on failure', (tester) async {
      final fakeAuth = _FakeVerifyAuthService(
        resendError: Exception(AuthErrorMessages.tooManyRequests),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(fakeAuth),
            authSessionProvider
                .overrideWith((ref) => Stream.value(_session(emailVerified: false))),
          ],
          child: MaterialApp(
            home: VerifyEmailScreen(redirect: '/pending-approval'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('שלח שוב מייל אימות'));
      await tester.pumpAndSettle();

      expect(fakeAuth.resendCalls, 1);
      expect(find.textContaining('נשלחו יותר מדי בקשות'), findsOneWidget);
    });

    testWidgets('check button navigates to redirect once verified', (tester) async {
      final fakeAuth = _FakeVerifyAuthService(verifiedOnCheck: true);
      final router = GoRouter(
        initialLocation: '/verify-email',
        routes: [
          GoRoute(
            path: '/verify-email',
            builder: (_, __) =>
                const VerifyEmailScreen(redirect: '/pending-approval'),
          ),
          GoRoute(
            path: '/pending-approval',
            builder: (_, __) => const Scaffold(body: Text('pending-approval')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(fakeAuth),
            authSessionProvider
                .overrideWith((ref) => Stream.value(_session(emailVerified: false))),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('בדקתי, המשך'));
      await tester.pumpAndSettle();

      expect(fakeAuth.checkCalls, 1);
      expect(find.text('pending-approval'), findsOneWidget);
    });

    testWidgets('check button shows not-yet-verified message when still unverified',
        (tester) async {
      final fakeAuth = _FakeVerifyAuthService(verifiedOnCheck: false);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(fakeAuth),
            authSessionProvider
                .overrideWith((ref) => Stream.value(_session(emailVerified: false))),
          ],
          child: MaterialApp(
            home: VerifyEmailScreen(redirect: '/pending-approval'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('בדקתי, המשך'));
      await tester.pumpAndSettle();

      expect(fakeAuth.checkCalls, 1);
      expect(find.textContaining('המייל עדיין לא אומת'), findsOneWidget);
    });
  });

  group('InviteLandingScreen unverified-email gate', () {
    OrganizationInvitation invite() => OrganizationInvitation(
          id: 'inv-1',
          orgId: 'org-1',
          orgType: OrganizationType.contractor,
          email: 'invitee@test.com',
          role: EnterpriseRole.engineer,
          status: 'pending',
          invitedByUid: 'uid-owner',
          createdAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(days: 7)),
        );

    testWidgets('shows verify-email prompt instead of the accept button',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionProvider
                .overrideWith((ref) => Stream.value(_session(emailVerified: false))),
            invitationByIdProvider('inv-1').overrideWith((ref) async => invite()),
          ],
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: '/invite/inv-1',
              routes: [
                GoRoute(
                  path: '/verify-email',
                  builder: (_, __) => const Scaffold(body: Text('verify-email')),
                ),
                GoRoute(
                  path: '/invite/:inviteId',
                  builder: (_, s) => InviteLandingScreen(
                    inviteId: s.pathParameters['inviteId']!,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('נדרש אימות כתובת מייל'), findsOneWidget);
      expect(find.text('הצטרף לחברה'), findsNothing);

      await tester.tap(find.text('לאימות המייל'));
      await tester.pumpAndSettle();
      expect(find.text('verify-email'), findsOneWidget);
    });

    testWidgets('verified invitee sees the normal accept button', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionProvider
                .overrideWith((ref) => Stream.value(_session(emailVerified: true))),
            invitationByIdProvider('inv-1').overrideWith((ref) async => invite()),
          ],
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: '/invite/inv-1',
              routes: [
                GoRoute(
                  path: '/invite/:inviteId',
                  builder: (_, s) => InviteLandingScreen(
                    inviteId: s.pathParameters['inviteId']!,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('נדרש אימות כתובת מייל'), findsNothing);
      expect(find.text('הצטרף לחברה'), findsOneWidget);
    });
  });
}
