import '../models/enterprise/enterprise_role.dart';
import '../models/enterprise/membership.dart';
import '../models/quote_request.dart';
import '../models/quote_status.dart';
import '../models/receipt_status.dart';
import 'procurement_rfq_access.dart';

/// Contractor-side receipt confirmation permissions.
abstract final class ShipmentReceiptAccess {
  static bool canConfirmReceiptForRequest({
    required String actorUid,
    required QuoteRequest request,
    required List<Membership> memberships,
    String? orgId,
    String? projectOrgId,
    // Live uids from the project's own /assignments subcollection — the
    // authoritative source firestore.rules' isProjectAssignee actually
    // checks. membership.projectIds is a derived cache that can go stale
    // (see ProjectAssignmentRepository/InvitationRepository); pass this
    // when available so the UI doesn't show a confirm-receipt action for a
    // project the caller was removed from (or hide one for a project
    // they're actually assigned to but whose cache write hasn't landed).
    // Falls back to the cache when not supplied, to preserve existing
    // behavior for callers without a live listener at hand.
    Set<String>? liveProjectAssigneeUids,
  }) {
    if (actorUid.isEmpty) return false;
    if (!request.statusAllowsReceiptConfirmation) return false;
    if (request.receiptStatus?.isFinal == true) return false;

    final effectiveOrgId = ProcurementRfqAccess.resolveContractorOrgId(
      request: request,
      orgId: orgId,
      projectOrgId: projectOrgId,
    );
    if (effectiveOrgId != null && effectiveOrgId.isNotEmpty) {
      if (!ProcurementRfqAccess.sharesContractorOrg(
        request: request,
        orgId: effectiveOrgId,
        projectOrgId: projectOrgId,
      )) {
        return false;
      }
      return memberships.any(
        (m) =>
            m.status == 'active' &&
            m.orgId == effectiveOrgId &&
            (m.hasRole(EnterpriseRole.procurementManager) ||
                m.hasRole(EnterpriseRole.contractorOwner) ||
                m.hasRole(EnterpriseRole.engineer) ||
                m.hasRole(EnterpriseRole.projectManager)) &&
            // Mirrors firestore.rules' canConfirmReceiptForRequest: roles
            // that default to org-wide access pass unconditionally; others
            // (engineer/projectManager without orgWideProjectAccess) must be
            // assigned to the request's own project.
            (m.hasOrgWideProjectAccess ||
                (request.projectId != null &&
                    (liveProjectAssigneeUids != null
                        ? liveProjectAssigneeUids.contains(actorUid)
                        : m.projectIds.contains(request.projectId)))),
      );
    }
    return request.customerId == actorUid;
  }

  static bool canViewReceiptForRequest({
    required QuoteRequest request,
    required List<Membership> memberships,
    String? orgId,
    String? projectOrgId,
    required String actorUid,
  }) {
    if (canConfirmReceiptForRequest(
      actorUid: actorUid,
      request: request,
      memberships: memberships,
      orgId: orgId,
      projectOrgId: projectOrgId,
    )) {
      return true;
    }
    final effectiveOrgId = ProcurementRfqAccess.resolveContractorOrgId(
      request: request,
      orgId: orgId,
      projectOrgId: projectOrgId,
    );
    if (effectiveOrgId != null && effectiveOrgId.isNotEmpty) {
      if (!ProcurementRfqAccess.sharesContractorOrg(
        request: request,
        orgId: effectiveOrgId,
        projectOrgId: projectOrgId,
      )) {
        return false;
      }
      return memberships.any(
        (m) =>
            m.status == 'active' &&
            m.orgId == effectiveOrgId &&
            m.hasRole(EnterpriseRole.contractorViewer),
      );
    }
    return request.customerId == actorUid;
  }

  static bool requestNeedsReceiptConfirmation(QuoteRequest request) {
    return request.status == QuoteRequestStatus.pendingReceipt ||
        (request.status == QuoteRequestStatus.shipped &&
            request.receiptStatus != ReceiptStatus.receivedFull &&
            request.receiptStatus != ReceiptStatus.receivedWithIssues);
  }
}
