import 'package:construction_rfq/models/enterprise/enterprise_role.dart';
import 'package:construction_rfq/models/enterprise/membership.dart';
import 'package:construction_rfq/models/enterprise/organization_type.dart';
import 'package:construction_rfq/models/quote_request.dart';
import 'package:construction_rfq/models/quote_status.dart';
import 'package:construction_rfq/utils/procurement_rfq_access.dart';
import 'package:flutter_test/flutter_test.dart';

Membership _membership(String orgId, List<EnterpriseRole> roles) {
  return Membership(
    uid: 'proc-2',
    orgId: orgId,
    orgType: OrganizationType.contractor,
    roles: roles,
    status: 'active',
  );
}

QuoteRequest _request({
  String? contractorOrgId,
  String? projectId,
  String customerId = 'engineer-1',
}) {
  return QuoteRequest(
    id: 'req-1',
    customerId: customerId,
    customerName: 'Engineer',
    customerPhone: '0500000000',
    customerCity: 'Tel Aviv',
    customerType: 'engineer',
    status: QuoteRequestStatus.sent,
    createdAt: DateTime(2026, 1, 1),
    contractorOrgId: contractorOrgId,
    projectId: projectId,
  );
}

void main() {
  const alphaOrg = 'qa-org-contractor-alpha';
  final procurementMembership = [
    _membership(alphaOrg, const [EnterpriseRole.procurementManager]),
  ];

  test('procurement can approve when contractorOrgId matches org', () {
    final request = _request(contractorOrgId: alphaOrg, projectId: 'qa-proj-alpha');
    expect(
      ProcurementRfqAccess.canApproveQuoteForRequest(
        actorUid: 'proc-2',
        request: request,
        memberships: procurementMembership,
        orgId: alphaOrg,
      ),
      isTrue,
    );
  });

  test('procurement can approve via project org when contractorOrgId missing', () {
    final request = _request(projectId: 'qa-proj-alpha');
    expect(
      ProcurementRfqAccess.canApproveQuoteForRequest(
        actorUid: 'proc-2',
        request: request,
        memberships: procurementMembership,
        orgId: alphaOrg,
        projectOrgId: alphaOrg,
      ),
      isTrue,
    );
  });

  test('procurement cannot approve unrelated org request', () {
    final request = _request(contractorOrgId: 'other-org', projectId: 'qa-proj-alpha');
    expect(
      ProcurementRfqAccess.canApproveQuoteForRequest(
        actorUid: 'proc-2',
        request: request,
        memberships: procurementMembership,
        orgId: alphaOrg,
        projectOrgId: alphaOrg,
      ),
      isFalse,
    );
  });

  test('engineer customer fallback when no org on request', () {
    final request = _request(customerId: 'engineer-1');
    expect(
      ProcurementRfqAccess.canApproveQuoteForRequest(
        actorUid: 'engineer-1',
        request: request,
        memberships: const [],
      ),
      isTrue,
    );
    expect(
      ProcurementRfqAccess.canApproveQuoteForRequest(
        actorUid: 'proc-2',
        request: request,
        memberships: procurementMembership,
        orgId: alphaOrg,
      ),
      isFalse,
    );
  });
}
