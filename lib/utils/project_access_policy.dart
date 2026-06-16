import '../models/enterprise/enterprise_role.dart';
import '../models/enterprise/membership.dart';
import 'org_id_helpers.dart';

/// Role-aware project listing rules (mirrors Firestore security filtering).
abstract final class ProjectAccessPolicy {
  static Set<String> activeOrgIds(Iterable<Membership> memberships) {
    return memberships
        .where((m) => m.status == 'active')
        .map((m) => m.orgId)
        .where(OrgIdHelpers.isRealOrgId)
        .toSet();
  }

  static Set<String> assignedProjectIds(Iterable<Membership> memberships) {
    return memberships
        .where((m) => m.status == 'active')
        .expand((m) => m.projectIds)
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  static bool canSeeOrgWideProjects(Iterable<Membership> memberships) {
    return memberships.any(
      (m) =>
          m.status == 'active' &&
          (m.hasRole(EnterpriseRole.contractorCompanyOwner) ||
              m.hasRole(EnterpriseRole.procurementManager)),
    );
  }

  static bool isAssignedOnlyMember(Iterable<Membership> memberships) {
    final active =
        memberships.where((m) => m.status == 'active').toList(growable: false);
    if (active.isEmpty) return false;
    const assignedRoles = {
      EnterpriseRole.engineer,
      EnterpriseRole.contractorViewer,
      EnterpriseRole.projectManager,
    };
    return active.every(
      (m) =>
          m.roles.isNotEmpty &&
          m.roles.every(assignedRoles.contains),
    );
  }
}
