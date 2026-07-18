import '../models/enterprise/membership.dart';
import 'org_id_helpers.dart';

/// Role-aware project listing rules (mirrors Firestore security filtering).
///
/// Project access has exactly two modes:
/// 1. Organization-wide access ([Membership.hasOrgWideProjectAccess]).
/// 2. Explicit assignment under `projects/{projectId}/assignments/{uid}` —
///    `membership.projectIds` is only a derived compatibility cache of it.
abstract final class ProjectAccessPolicy {
  static Set<String> activeOrgIds(Iterable<Membership> memberships) {
    return memberships
        .where((m) => m.isActive)
        .map((m) => m.orgId)
        .where(OrgIdHelpers.isRealOrgId)
        .toSet();
  }

  static Set<String> assignedProjectIds(Iterable<Membership> memberships) {
    return memberships
        .where((m) => m.isActive)
        .expand((m) => m.projectIds)
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  static bool canSeeOrgWideProjects(Iterable<Membership> memberships) {
    return memberships.any((m) => m.isActive && m.hasOrgWideProjectAccess);
  }

  static bool isAssignedOnlyMember(Iterable<Membership> memberships) {
    final active = memberships.where((m) => m.isActive).toList(growable: false);
    if (active.isEmpty) return false;
    return active.every(
      (m) => m.roles.isNotEmpty && !m.hasOrgWideProjectAccess,
    );
  }
}
