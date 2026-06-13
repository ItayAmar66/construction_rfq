import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/enterprise/organization_invitation.dart';
import '../../providers/enterprise_providers.dart';
import '../../providers/providers.dart';
import '../../repositories/invitation_repository.dart';
import '../../models/enterprise/organization_type.dart';
import '../../utils/app_theme.dart';
import '../../utils/enterprise_role_labels.dart';
import '../../utils/invitation_link_builder.dart';
import '../../utils/user_facing_error.dart';
import '../../widgets/loading_view.dart';

class InviteLandingScreen extends ConsumerStatefulWidget {
  const InviteLandingScreen({super.key, required this.inviteId});

  final String inviteId;

  @override
  ConsumerState<InviteLandingScreen> createState() =>
      _InviteLandingScreenState();
}

class _InviteLandingScreenState extends ConsumerState<InviteLandingScreen> {
  bool _accepting = false;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider).valueOrNull;
    final inviteAsync = ref.watch(invitationByIdProvider(widget.inviteId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/login');
            }
          },
        ),
        title: const Text('הזמנה להצטרפות'),
      ),
      body: inviteAsync.when(
        loading: () => const LoadingView(message: 'טוען הזמנה...'),
        error: (_, __) => _messageBody(
          title: 'שגיאה בטעינת ההזמנה',
          body: 'נסו שוב מאוחר יותר.',
        ),
        data: (invite) {
          if (session == null || !session.isAuthenticated) {
            return _messageBody(
              title: 'הוזמנת להצטרף לחברה',
              body: 'התחבר או צור חשבון עם המייל שהוזמן.',
              actions: [
                FilledButton(
                  onPressed: () => context.go(
                    '/login?redirect=${Uri.encodeComponent('/invite/${widget.inviteId}')}',
                  ),
                  child: const Text('התחבר'),
                ),
                OutlinedButton(
                  onPressed: () => context.go('/register'),
                  child: const Text('צור חשבון'),
                ),
              ],
            );
          }

          if (invite == null) {
            return _messageBody(
              title: 'ההזמנה לא נמצאה',
              body: 'ייתכן שהקישור אינו תקין או שפג תוקפו.',
            );
          }

          return _buildInviteState(context, invite, session.profile?.email ?? '');
        },
      ),
    );
  }

  Widget _buildInviteState(
    BuildContext context,
    OrganizationInvitation invite,
    String userEmail,
  ) {
    if (invite.status == 'accepted') {
      return _messageBody(
        title: 'ההזמנה כבר התקבלה',
        body: 'כבר הצטרפת לחברה זו.',
        actions: [
          FilledButton(
            onPressed: () => context.go('/home'),
            child: const Text('לדף הבית'),
          ),
        ],
      );
    }
    if (invite.status == 'cancelled') {
      return _messageBody(
        title: 'ההזמנה בוטלה',
        body: 'ההזמנה אינה פעילה יותר.',
      );
    }
    if (invite.isExpired) {
      return _messageBody(
        title: 'תוקף ההזמנה פג',
        body: 'פנו למנהל החברה לקבלת הזמנה חדשה.',
      );
    }

    final emailMatch =
        invite.email.toLowerCase() == userEmail.trim().toLowerCase();
    if (!emailMatch) {
      return _messageBody(
        title: 'ההזמנה נשלחה למייל אחר',
        body: 'ההזמנה נשלחה ל-${invite.email}. '
            'התחבר עם המייל המוזמן.',
      );
    }

    return _messageBody(
      title: 'הוזמנת להצטרף לחברה',
      body: 'תפקיד: ${EnterpriseRoleLabels.hebrew(invite.role)}\n'
          'חברה: ${_orgLabel(invite)}',
      actions: [
        FilledButton(
          onPressed: _accepting
              ? null
              : () => _accept(context, invite, userEmail),
          child: _accepting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('הצטרף לחברה'),
        ),
      ],
    );
  }

  Future<void> _accept(
    BuildContext context,
    OrganizationInvitation invite,
    String email,
  ) async {
    setState(() => _accepting = true);
    try {
      final session = ref.read(authSessionProvider).valueOrNull;
      await ref.read(invitationRepositoryProvider).acceptInvitation(
            inviteId: invite.id,
            uid: session?.uid ?? '',
            email: email,
            actorName: session?.profile?.fullName,
          );
      ref.invalidate(currentUserMembershipsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('הצטרפת לחברה')),
        );
        context.go(
          invite.orgType == OrganizationType.supplier ? '/home' : '/home',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _accepting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingError(e))),
        );
      }
    }
  }

  String _orgLabel(OrganizationInvitation invite) {
    if (invite.displayName?.isNotEmpty == true) return invite.displayName!;
    return invite.orgId;
  }

  Widget _messageBody({
    required String title,
    required String body,
    List<Widget> actions = const [],
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.mail_outline, size: 48, color: AppTheme.teal.withValues(alpha: 0.8)),
              const SizedBox(height: 16),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Text(body,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, height: 1.4)),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: actions,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> copyInviteLink(OrganizationInvitation invite) async {
  final link =
      invite.inviteLink ?? InvitationLinkBuilder.inviteLink(invite.id);
  await Clipboard.setData(ClipboardData(text: link));
}

/// Copy invite link to clipboard helper (by id).
Future<void> copyInviteLinkById(BuildContext context, String inviteId) async {
  final link = InvitationLinkBuilder.inviteLink(inviteId);
  await Clipboard.setData(ClipboardData(text: link));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('קישור ההזמנה הועתק')),
    );
  }
}
