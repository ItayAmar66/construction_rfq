import '../models/enterprise/membership.dart';
import '../models/enterprise/organization_invitation.dart';

/// Fills missing membership identity from org-scoped invitation snapshots.
abstract final class MembershipIdentityEnricher {
  static List<Membership> enrich({
    required List<Membership> memberships,
    required List<OrganizationInvitation> invitations,
  }) {
    if (memberships.isEmpty) return memberships;
    return memberships
        .map((membership) => enrichOne(
              membership: membership,
              invitations: invitations,
            ))
        .toList(growable: false);
  }

  static Membership enrichOne({
    required Membership membership,
    required List<OrganizationInvitation> invitations,
  }) {
    final hasEmail = membership.email?.trim().isNotEmpty == true;
    final hasName = membership.displayName?.trim().isNotEmpty == true;
    if (hasEmail && hasName) return membership;

    OrganizationInvitation? invite;
    for (final candidate in invitations) {
      if (candidate.orgId != membership.orgId) continue;
      if (candidate.acceptedByUid == membership.uid ||
          candidate.email.trim().toLowerCase() ==
              (membership.email ?? '').trim().toLowerCase()) {
        invite = candidate;
        break;
      }
    }
    if (invite == null) return membership;

    return Membership(
      uid: membership.uid,
      orgId: membership.orgId,
      orgType: membership.orgType,
      roles: membership.roles,
      status: membership.status,
      projectIds: membership.projectIds,
      createdBy: membership.createdBy,
      createdAt: membership.createdAt,
      updatedAt: membership.updatedAt,
      email: hasEmail ? membership.email : invite.email,
      displayName: hasName ? membership.displayName : invite.displayName,
    );
  }
}
