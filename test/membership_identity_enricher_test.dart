import 'package:construction_rfq/models/enterprise/enterprise_role.dart';
import 'package:construction_rfq/models/enterprise/membership.dart';
import 'package:construction_rfq/models/enterprise/organization_invitation.dart';
import 'package:construction_rfq/models/enterprise/organization_type.dart';
import 'package:construction_rfq/utils/membership_identity_enricher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('enriches membership email from accepted invitation', () {
    const membership = Membership(
      uid: 'proc-1',
      orgId: 'org-1',
      orgType: OrganizationType.contractor,
      roles: [EnterpriseRole.procurementManager],
    );
    const invitation = OrganizationInvitation(
      id: 'inv-1',
      orgId: 'org-1',
      orgType: OrganizationType.contractor,
      email: 'qa.contractor.big.procurement@test.com',
      displayName: 'רכש QA',
      role: EnterpriseRole.procurementManager,
      status: 'accepted',
      invitedByUid: 'owner-1',
      acceptedByUid: 'proc-1',
    );

    final enriched = MembershipIdentityEnricher.enrichOne(
      membership: membership,
      invitations: const [invitation],
    );

    expect(enriched.email, 'qa.contractor.big.procurement@test.com');
    expect(enriched.displayLabel, 'רכש QA');
  });
}
