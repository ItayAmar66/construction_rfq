import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/models/access_request.dart';
import 'package:construction_rfq/models/enterprise/organization_type.dart';
import 'package:construction_rfq/repositories/access_request_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    AppMode.enableDemoMode();
    AccessRequestRepository.resetDemo();
  });

  test('empty pending list returns empty state data, not error', () async {
    final repo = AccessRequestRepository();
    final all = await repo.fetchAllPending();
    final org = await repo.fetchPendingForOrg('launch-org-dimri');
    expect(all, isEmpty);
    expect(org, isEmpty);
  });

  test('admin can load all pending requests in demo mode', () async {
    final repo = AccessRequestRepository();
    await repo.createPendingRequest(
      const AccessRequest(
        uid: 'u1',
        email: 'a@test.com',
        fullName: 'A',
        userType: 'commercialCustomer',
        requestedOrgType: OrganizationType.contractor,
        requestedOrgId: 'launch-org-dimri',
        requestedOrgName: 'דימרי',
      ),
    );
    await repo.createPendingRequest(
      const AccessRequest(
        uid: 'u2',
        email: 'b@test.com',
        fullName: 'B',
        userType: 'commercialSupplier',
        requestedOrgType: OrganizationType.supplier,
        requestedOrgId: 'launch-org-frishman',
        requestedOrgName: 'פרישמן',
      ),
    );

    final all = await repo.fetchAllPending();
    expect(all.length, 2);
  });

  test('owner loads only own org pending requests', () async {
    final repo = AccessRequestRepository();
    await repo.createPendingRequest(
      const AccessRequest(
        uid: 'u1',
        email: 'dimri@test.com',
        fullName: 'Dimri',
        userType: 'commercialCustomer',
        requestedOrgType: OrganizationType.contractor,
        requestedOrgId: 'launch-org-dimri',
        requestedOrgName: 'דימרי',
      ),
    );
    await repo.createPendingRequest(
      const AccessRequest(
        uid: 'u2',
        email: 'frishman@test.com',
        fullName: 'Frishman',
        userType: 'commercialSupplier',
        requestedOrgType: OrganizationType.supplier,
        requestedOrgId: 'launch-org-frishman',
        requestedOrgName: 'פרישמן',
      ),
    );

    final dimri = await repo.fetchPendingForOrg('launch-org-dimri');
    final frishman = await repo.fetchPendingForOrg('launch-org-frishman');
    expect(dimri.length, 1);
    expect(dimri.first.email, 'dimri@test.com');
    expect(frishman.length, 1);
    expect(frishman.first.email, 'frishman@test.com');
  });

  test('resolved requests are excluded from pending queries', () async {
    final repo = AccessRequestRepository();
    await repo.createPendingRequest(
      const AccessRequest(
        uid: 'u1',
        email: 'pending@test.com',
        fullName: 'Pending',
        userType: 'commercialCustomer',
        requestedOrgType: OrganizationType.contractor,
        requestedOrgId: 'launch-org-dimri',
        requestedOrgName: 'דימרי',
      ),
    );
    await repo.resolveRequest(uid: 'u1', status: 'approved', actorUid: 'admin');

    final pending = await repo.fetchPendingForOrg('launch-org-dimri');
    expect(pending, isEmpty);
  });

  test('queries sort newest first without Firestore orderBy', () async {
    final repo = AccessRequestRepository();
    await repo.createPendingRequest(
      AccessRequest(
        uid: 'old',
        email: 'old@test.com',
        fullName: 'Old',
        userType: 'commercialCustomer',
        requestedOrgType: OrganizationType.contractor,
        requestedOrgId: 'launch-org-dimri',
        requestedOrgName: 'דימרי',
        createdAt: DateTime(2026, 1, 1),
      ),
    );
    await repo.createPendingRequest(
      AccessRequest(
        uid: 'new',
        email: 'new@test.com',
        fullName: 'New',
        userType: 'commercialCustomer',
        requestedOrgType: OrganizationType.contractor,
        requestedOrgId: 'launch-org-dimri',
        requestedOrgName: 'דימרי',
        createdAt: DateTime(2026, 6, 1),
      ),
    );

    final pending = await repo.fetchPendingForOrg('launch-org-dimri');
    expect(pending.first.uid, 'new');
  });
}
