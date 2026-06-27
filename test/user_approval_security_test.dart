import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final rules = File('${Directory.current.path}/firestore.rules').readAsStringSync();

  group('User approval access control', () {
    test('accessRequests collection exists with owner read/create/update rules', () {
      expect(rules, contains('match /accessRequests/{requestUid}'));
      expect(rules, contains('canManageOrgMemberships(resource.data.requestedOrgId)'));
      expect(rules, contains("request.resource.data.status == 'pending'"));
      expect(rules, contains('isPlatformAdmin()'));
    });

    test('registration stores requested org fields', () {
      expect(rules, contains("'requestedOrgName'"));
      expect(rules, contains("'requestedOrgType'"));
    });

    test('owner can approve pending users into own org', () {
      expect(rules, contains('function userOwnerApprovalUpdateAllowed(userId)'));
      expect(rules, contains('function membershipOwnerApprovalCreateAllowed(orgId, memberUid)'));
      expect(rules, contains('targetUser.accountStatus == \'pendingApproval\''));
    });

    test('owner can disable/reactivate team members', () {
      expect(rules, contains('function userOrgManagerStatusUpdateAllowed(userId)'));
      expect(rules, contains('function membershipManagerUpdateAllowed(orgId, memberUid)'));
    });

    test('rejected and disabled account statuses supported', () {
      expect(rules, contains("'rejected'"));
      expect(rules, contains("'disabled'"));
    });

    test('owners cannot assign platformAdmin via membership roles validation', () {
      expect(rules, contains("!('platformAdmin' in request.resource.data.roles)"));
      expect(rules, contains("role != 'platformAdmin'"));
    });

    test('pending users blocked from active platform access', () {
      expect(rules, contains('function userHasActivePlatformAccess()'));
      expect(rules, contains("userDoc().data.accountStatus == 'active'"));
    });

    test('user update includes owner approval path', () {
      final start = rules.indexOf('match /users/{userId}');
      final end = rules.indexOf('match /accessRequests/{requestUid}');
      final block = rules.substring(start, end);
      expect(block, contains('userOwnerApprovalUpdateAllowed(userId)'));
      expect(block, contains('userOrgManagerStatusUpdateAllowed(userId)'));
    });
  });
}
