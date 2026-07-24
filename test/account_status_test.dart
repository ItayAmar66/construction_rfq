import 'package:construction_rfq/models/account_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AccountStatus.fromValue', () {
    test('null and empty default to active', () {
      expect(AccountStatus.fromValue(null), AccountStatus.active);
      expect(AccountStatus.fromValue(''), AccountStatus.active);
    });

    test('parses each known value', () {
      expect(
        AccountStatus.fromValue('pendingApproval'),
        AccountStatus.pendingApproval,
      );
      expect(AccountStatus.fromValue('active'), AccountStatus.active);
      expect(AccountStatus.fromValue('disabled'), AccountStatus.disabled);
      expect(AccountStatus.fromValue('rejected'), AccountStatus.rejected);
    });

    test('legacy "blocked" is remapped to disabled on read', () {
      // The enum still has a `blocked` member, but persisted "blocked" must
      // resolve to `disabled` so gating logic has a single canonical value.
      expect(AccountStatus.fromValue('blocked'), AccountStatus.disabled);
    });

    test('unknown values default to active', () {
      expect(AccountStatus.fromValue('banana'), AccountStatus.active);
    });
  });

  group('AccountStatus.canUsePlatform', () {
    test('only active can use the platform', () {
      expect(AccountStatus.active.canUsePlatform, isTrue);
      expect(AccountStatus.pendingApproval.canUsePlatform, isFalse);
      expect(AccountStatus.disabled.canUsePlatform, isFalse);
      expect(AccountStatus.rejected.canUsePlatform, isFalse);
      expect(AccountStatus.blocked.canUsePlatform, isFalse);
    });
  });

  group('AccountStatus.isPendingGate', () {
    test('every non-active status is behind the gate', () {
      expect(AccountStatus.active.isPendingGate, isFalse);
      expect(AccountStatus.pendingApproval.isPendingGate, isTrue);
      expect(AccountStatus.rejected.isPendingGate, isTrue);
      expect(AccountStatus.disabled.isPendingGate, isTrue);
      expect(AccountStatus.blocked.isPendingGate, isTrue);
    });

    test('canUsePlatform and isPendingGate are mutually exclusive', () {
      for (final status in AccountStatus.values) {
        expect(status.canUsePlatform, isNot(status.isPendingGate),
            reason: '$status should be usable XOR gated');
      }
    });
  });
}
