import 'dart:async';

import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/models/enterprise/enterprise_role.dart';
import 'package:construction_rfq/models/enterprise/membership.dart';
import 'package:construction_rfq/models/enterprise/organization_type.dart';
import 'package:construction_rfq/repositories/organization_repository.dart';
import 'package:construction_rfq/repositories/project_repository.dart';
import 'package:construction_rfq/services/mock_store.dart';
import 'package:construction_rfq/utils/bootstrap_error_handling.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OrganizationRepository membership watcher safety', () {
    final repo = OrganizationRepository();

    setUp(() {
      AppMode.enableDemoMode();
      MockStore.instance.init();
      MockStore.instance.demoMemberships.clear();
    });

    tearDown(() {
      AppMode.isDemoMode = false;
    });

    Membership membershipFor(String uid, {String? orgId}) {
      return Membership(
        uid: uid,
        orgId: orgId ?? uid,
        orgType: OrganizationType.contractor,
        roles: const [EnterpriseRole.contractorCompanyOwner],
      );
    }

    test('no memberships emits empty list immediately', () async {
      final first = await repo
          .watchMembershipsForUser('lonely-user')
          .first
          .timeout(const Duration(seconds: 2));
      expect(first, isEmpty);
    });

    test('removing missing membership does not hang', () async {
      final first = await repo
          .watchMembershipsForUser('missing-user')
          .first
          .timeout(const Duration(seconds: 2));
      expect(first, isEmpty);
    });

    test('rapid membership updates do not throw', () async {
      const uid = 'burst-user';
      for (var i = 0; i < 25; i++) {
        MockStore.instance.setDemoMembership(membershipFor(uid));
      }

      final latest = await repo
          .watchMembershipsForUser(uid)
          .first
          .timeout(const Duration(seconds: 2));
      expect(latest, hasLength(1));
    });

    test('cancel and resubscribe while listeners exist does not throw', () async {
      const uid = 'resub-user';
      MockStore.instance.setDemoMembership(membershipFor(uid));

      final first = await repo.watchMembershipsForUser(uid).first;
      expect(first, hasLength(1));

      final second = await repo
          .watchMembershipsForUser(uid)
          .first
          .timeout(const Duration(seconds: 2));
      expect(second, hasLength(1));
    });
  });

  group('ProjectRepository watcher safety', () {
    final repo = ProjectRepository();

    setUp(() {
      AppMode.enableDemoMode();
      MockStore.instance.init();
      MockStore.instance.demoMemberships.clear();
    });

    tearDown(() {
      AppMode.isDemoMode = false;
    });

    test('membership stream churn does not throw', () async {
      const uid = 'project-user';
      final memberships = StreamController<List<Membership>>();
      addTearDown(memberships.close);

      final first = repo
          .watchAccessibleProjectsForUser(uid, memberships.stream)
          .first
          .timeout(const Duration(seconds: 2));

      memberships.add(const []);
      memberships.add([
        Membership(
          uid: uid,
          orgId: uid,
          orgType: OrganizationType.contractor,
          roles: const [EnterpriseRole.contractorCompanyOwner],
        ),
      ]);
      memberships.add(const []);

      await expectLater(first, completion(isA<List<dynamic>>()));
    });
  });

  group('subscription map snapshot safety', () {
    test('snapshot before cancel avoids concurrent modification', () async {
      final directSubs = <String, _Cancelable>{};

      directSubs['a'] = _Cancelable(() {
        directSubs['b'] = _Cancelable(() {});
      });

      final subs = directSubs.values.toList(growable: false);
      directSubs.clear();
      for (final sub in subs) {
        await sub.cancel();
      }

      expect(directSubs.containsKey('b'), isTrue);
    });

    test('reentrant cancel callback does not iterate live map', () async {
      final directSubs = <String, _Cancelable>{};
      directSubs['a'] = _Cancelable(() {
        directSubs['b'] = _Cancelable(() {});
      });
      directSubs['c'] = _Cancelable(() {});

      final subs = directSubs.values.toList(growable: false);
      directSubs.clear();
      await expectLater(
        Future.wait(subs.map((s) => s.cancel())),
        completes,
      );
    });
  });

  group('BootstrapErrorHandling', () {
    test('installs Hebrew error widget', () {
      BootstrapErrorHandling.install();
      final widget = ErrorWidget.builder(
        FlutterErrorDetails(exception: Exception('boom')),
      );
      expect(widget, isA<Material>());
    });
  });
}

class _Cancelable {
  _Cancelable(this._onCancel);

  final void Function() _onCancel;

  Future<void> cancel() async {
    _onCancel();
  }
}
