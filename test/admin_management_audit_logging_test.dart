import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// HIGH-6 regression: AdminManagementRepository's org/membership/project
/// writes must be audit-logged, matching AdminApprovalService and
/// TeamPermissionsService, which already do this for comparable actions.
///
/// No fake Firestore is wired into this project's test setup, so this is a
/// structural check (mirrors the established pattern in
/// firestore_rules_security_test.dart for verifying rules content) rather
/// than an integration test — it fails if a write method's audit call is
/// ever removed or its action constant changed without updating this test.
void main() {
  final source =
      File('lib/repositories/admin_management_repository.dart').readAsStringSync();

  test('AdminManagementRepository depends on AuditRepository', () {
    expect(source, contains('final AuditRepository _auditRepository'));
    expect(source, contains("import 'audit_repository.dart'"));
  });

  String bodyOf(String signature, {String? untilNext}) {
    final start = source.indexOf(signature);
    expect(start, greaterThan(-1), reason: '$signature not found');
    final end = untilNext != null
        ? source.indexOf(untilNext, start)
        : source.indexOf('\n  Future<', start + signature.length);
    return source.substring(start, end == -1 ? source.length : end);
  }

  test('createOrganization is audit-logged', () {
    final body = bodyOf('Future<Organization> createOrganization({');
    expect(body, contains('_auditOrgAction('));
    expect(body, contains('AuditAction.organizationCreated'));
  });

  test('updateOrganizationDetails is audit-logged', () {
    final body = bodyOf('Future<Organization> updateOrganizationDetails({');
    expect(body, contains('_auditOrgAction('));
    expect(body, contains('AuditAction.organizationUpdated'));
  });

  test('updateOrganizationOwner is audit-logged', () {
    final body = bodyOf('Future<Organization> updateOrganizationOwner({');
    expect(body, contains('_auditOrgAction('));
    expect(body, contains('AuditAction.organizationOwnerChanged'));
  });

  test('upsertMembership is audit-logged', () {
    final body = bodyOf('Future<Membership> upsertMembership({');
    expect(body, contains('_auditMembershipAction('));
    expect(body, contains('AuditAction.membershipUpserted'));
  });

  test('updateMembership is audit-logged', () {
    final body = bodyOf('Future<Membership> updateMembership({');
    expect(body, contains('_auditMembershipAction('));
    expect(body, contains('AuditAction.membershipUpdated'));
  });

  test('assignProjectMember is audit-logged', () {
    final body = bodyOf('Future<void> assignProjectMember({');
    expect(body, contains('AuditLogger.record('));
    expect(body, contains('AuditAction.projectAssigned'));
  });

  test('createProjectAsAdmin is audit-logged', () {
    final body = bodyOf(
      'Future<Project> createProjectAsAdmin({',
      untilNext: 'String buildCreateUserCommand',
    );
    expect(body, contains('AuditLogger.record('));
    expect(body, contains('AuditAction.projectCreated'));
  });

  test('actorUid is required wherever a write is now audit-logged', () {
    // createOrganization/updateOrganizationDetails/updateOrganizationOwner
    // had no actor attribution at all before this fix.
    for (final signature in [
      'Future<Organization> createOrganization({',
      'Future<Organization> updateOrganizationDetails({',
      'Future<Organization> updateOrganizationOwner({',
    ]) {
      final body = bodyOf(signature, untilNext: '}) async {');
      expect(
        body,
        contains('required String actorUid'),
        reason: '$signature must require actorUid to attribute its audit event',
      );
    }
  });
}
