import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import '../../repositories/invitation_repository.dart';
import '../../providers/enterprise_providers.dart';
import 'pending_invitations_section.dart';

/// Shows pending org invitation accept banner on home/dashboard.
class InvitationAcceptSection extends ConsumerWidget {
  const InvitationAcceptSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitesAsync = ref.watch(pendingInvitationsForUserProvider);
    return invitesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (invites) {
        if (invites.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InvitationAcceptBanner(
            invitations: invites,
            onAccept: (invite) async {
              final session = ref.read(authSessionProvider).valueOrNull;
              final uid = session?.uid ?? '';
              final email = session?.profile?.email ?? '';
              await ref.read(invitationRepositoryProvider).acceptInvitation(
                    inviteId: invite.id,
                    uid: uid,
                    email: email,
                  );
              ref.invalidate(currentUserMembershipsProvider);
              ref.invalidate(pendingInvitationsForUserProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('הצטרפת לחברה')),
                );
              }
            },
          ),
        );
      },
    );
  }
}
