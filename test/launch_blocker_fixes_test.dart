import 'dart:io';

import 'package:construction_rfq/models/app_user.dart';
import 'package:construction_rfq/models/enterprise/enterprise_role.dart';
import 'package:construction_rfq/models/enterprise/permission.dart';
import 'package:construction_rfq/models/user_type.dart';
import 'package:construction_rfq/services/effective_permissions.dart';
import 'package:construction_rfq/services/organization_bootstrap_service.dart';
import 'package:construction_rfq/utils/auth_error_messages.dart';
import 'package:construction_rfq/utils/org_id_helpers.dart';
import 'package:construction_rfq/utils/supplier_quote_doc_id.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final rules =
      File('${Directory.current.path}/firestore.rules').readAsStringSync();

  group('Firestore shipped transition', () {
    test('allows approved supplier to mark order shipped', () {
      expect(rules, contains('function supplierCanMarkOrderShipped()'));
      expect(rules, contains('function supplierApprovedQuoteOwner('));
      expect(rules, contains('supplierCanMarkOrderShipped()'));
    });
  });

  group('Firestore project assignment reads', () {
    test('assigned members can read project', () {
      expect(rules, contains('function isProjectAssignee(projectId)'));
      expect(rules, contains('isProjectAssignee(projectId)'));
    });
  });

  group('Firestore org bootstrap', () {
    test('disallows self-serve org create (platform admin only)', () {
      expect(rules, contains('function organizationOwnerBootstrapAllowed('));
      expect(rules, contains('allow create: if isPlatformAdmin();'));
    });
  });

  group('Supplier owner permissions', () {
    test('commercial supplier without membership has catalog only', () {
      final supplier = AppUser(
        id: 's1',
        fullName: 'ספק',
        email: 's@test.com',
        phone: '050',
        userType: UserType.commercialSupplier,
        city: 'חיפה',
        createdAt: DateTime(2026),
      );
      final perms = EffectivePermissions.resolve(user: supplier);
      expect(perms, contains(Permission.viewCatalog));
      expect(perms, isNot(contains(Permission.manageUsers)));
    });

    test('private supplier without membership has catalog only', () {
      final supplier = AppUser(
        id: 's2',
        fullName: 'ספק פרטי',
        email: 'p@test.com',
        phone: '050',
        userType: UserType.privateSupplier,
        city: 'חיפה',
        createdAt: DateTime(2026),
      );
      final perms = EffectivePermissions.resolve(user: supplier);
      expect(perms, contains(Permission.viewCatalog));
      expect(perms, isNot(contains(Permission.manageUsers)));
    });
  });

  group('Org id helpers', () {
    test('legacy fallback is not a real org', () {
      expect(OrgIdHelpers.isLegacyFallback('legacy-abc'), isTrue);
      expect(OrgIdHelpers.isRealOrgId('org-123'), isTrue);
    });
  });

  group('Org bootstrap service', () {
    test('commercial customer should bootstrap', () {
      expect(
        OrganizationBootstrapService.shouldBootstrapOrg(
          UserType.commercialCustomer,
        ),
        isTrue,
      );
      expect(
        OrganizationBootstrapService.ownerRoleFor(UserType.commercialCustomer),
        EnterpriseRole.contractorCompanyOwner,
      );
    });

    test('private customer should not bootstrap org', () {
      expect(
        OrganizationBootstrapService.shouldBootstrapOrg(
          UserType.privateCustomer,
        ),
        isFalse,
      );
    });
  });

  group('Auth error mapping', () {
    test('invalid-credential maps to Hebrew wrong credentials', () {
      expect(
        AuthErrorMessages.from(
          FirebaseAuthException(code: 'invalid-credential'),
        ),
        AuthErrorMessages.wrongCredentials,
      );
    });

    test('email-already-in-use maps to user exists', () {
      expect(
        AuthErrorMessages.from(
          FirebaseAuthException(code: 'email-already-in-use'),
        ),
        AuthErrorMessages.userExists,
      );
    });
  });

  group('Duplicate quote guard', () {
    test('deterministic quote doc id is stable', () {
      expect(
        SupplierQuoteDocId.forRequest(
          quoteRequestId: 'rfq-1',
          supplierId: 'sup-1',
        ),
        'rfq-1__sup-1',
      );
    });
  });
}
