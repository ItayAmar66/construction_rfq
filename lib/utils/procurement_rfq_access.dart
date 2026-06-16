import '../models/enterprise/enterprise_role.dart';
import '../models/enterprise/membership.dart';
import '../models/quote_request.dart';

/// Org-scoped procurement actions on engineer-created RFQs.
abstract final class ProcurementRfqAccess {
  static bool sharesContractorOrg({
    required QuoteRequest request,
    required String orgId,
  }) {
    final requestOrgId = request.contractorOrgId;
    return requestOrgId != null &&
        requestOrgId.isNotEmpty &&
        requestOrgId == orgId;
  }

  static bool canManageOrgRequest({
    required QuoteRequest request,
    required List<Membership> memberships,
    String? orgId,
  }) {
    final resolvedOrgId = orgId ?? request.contractorOrgId;
    if (resolvedOrgId == null || resolvedOrgId.isEmpty) return false;
    if (!sharesContractorOrg(request: request, orgId: resolvedOrgId)) {
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
  }) {
    if (actorUid.isEmpty) return false;
    return canManageOrgRequest(
      request: request,
      memberships: memberships,
      orgId: orgId,
    );
  }

  static bool canApproveQuoteForRequest({
    required String actorUid,
    required QuoteRequest request,
    required List<Membership> memberships,
    String? orgId,
  }) {
    if (actorUid.isEmpty) return false;
    final requestOrgId = request.contractorOrgId;
    if (requestOrgId != null && requestOrgId.isNotEmpty) {
      return canManageOrgRequest(
        request: request,
        memberships: memberships,
        orgId: orgId ?? requestOrgId,
      );
    }
    return request.customerId == actorUid;
  }
}
