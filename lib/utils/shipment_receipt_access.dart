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
                m.hasRole(EnterpriseRole.contractorCompanyOwner) ||
                m.hasRole(EnterpriseRole.engineer) ||
                m.hasRole(EnterpriseRole.projectManager)),
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
