import '../models/enterprise/enterprise_role.dart';
import '../models/enterprise/membership.dart';
import '../models/quote_request.dart';

/// Org-scoped procurement actions on engineer-created RFQs.
abstract final class ProcurementRfqAccess {
  static String? resolveContractorOrgId({
    required QuoteRequest request,
    String? orgId,
    String? projectOrgId,
  }) {
    final onDoc = request.contractorOrgId;
    if (onDoc != null && onDoc.isNotEmpty) return onDoc;
    if (projectOrgId != null && projectOrgId.isNotEmpty) return projectOrgId;
    if (orgId != null && orgId.isNotEmpty) return orgId;
    return null;
  }

  static bool sharesContractorOrg({
    required QuoteRequest request,
    required String orgId,
    String? projectOrgId,
  }) {
    if (orgId.isEmpty) return false;
    final requestOrgId = request.contractorOrgId;
    if (requestOrgId != null && requestOrgId.isNotEmpty) {
      return requestOrgId == orgId;
    }
    final fallbackOrgId = projectOrgId;
    if (fallbackOrgId == null || fallbackOrgId.isEmpty) return false;
    if (fallbackOrgId != orgId) return false;
    final projectId = request.projectId;
    return projectId != null && projectId.isNotEmpty;
  }

  static bool canManageOrgRequest({
    required QuoteRequest request,
    required List<Membership> memberships,
    String? orgId,
    String? projectOrgId,
  }) {
    final resolvedOrgId = resolveContractorOrgId(
      request: request,
      orgId: orgId,
      projectOrgId: projectOrgId,
    );
    if (resolvedOrgId == null || resolvedOrgId.isEmpty) return false;
    if (!sharesContractorOrg(
      request: request,
      orgId: resolvedOrgId,
      projectOrgId: projectOrgId,
    )) {
      return false;
    }
    return memberships.any(
      (m) =>
          m.status == 'active' &&
          m.orgId == resolvedOrgId &&
          (m.hasRole(EnterpriseRole.procurementManager) ||
              m.hasRole(EnterpriseRole.contractorCompanyOwner)),
    );
  }

  static bool canSendApprovedToSuppliers({
    required String actorUid,
    required QuoteRequest request,
    required List<Membership> memberships,
    String? orgId,
    String? projectOrgId,
  }) {
    if (actorUid.isEmpty) return false;
    return canManageOrgRequest(
      request: request,
      memberships: memberships,
      orgId: orgId,
      projectOrgId: projectOrgId,
    );
  }

  static bool canApproveQuoteForRequest({
    required String actorUid,
    required QuoteRequest request,
    required List<Membership> memberships,
    String? orgId,
    String? projectOrgId,
  }) {
    if (actorUid.isEmpty) return false;
    final effectiveOrgId = resolveContractorOrgId(
      request: request,
      orgId: orgId,
      projectOrgId: projectOrgId,
    );
    if (effectiveOrgId != null && effectiveOrgId.isNotEmpty) {
      return canManageOrgRequest(
        request: request,
        memberships: memberships,
        orgId: effectiveOrgId,
        projectOrgId: projectOrgId,
      );
    }
    return request.customerId == actorUid;
  }
}
