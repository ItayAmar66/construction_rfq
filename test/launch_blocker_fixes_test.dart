import 'dart:io';

import 'package:construction_rfq/models/app_user.dart';
import 'package:construction_rfq/models/enterprise/enterprise_role.dart';
import 'package:construction_rfq/models/enterprise/membership.dart';
import 'package:construction_rfq/models/enterprise/organization_type.dart';
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
  final indexes =
      File('${Directory.current.path}/firestore.indexes.json').readAsStringSync();

  group('Firestore membership discovery', () {
    test('allows collection group read for own uid field', () {
      expect(rules, contains('resource.data.uid == uid()'));
    });

    test('memberships collection group uses uid rule without explicit index', () {
      expect(rules, contains('resource.data.uid == uid()'));
      // Single-field memberships uid CG index removed — Firebase auto-indexes it.
      expect(indexes, isNot(contains('"collectionGroup": "memberships"')));
    });
  });

  group('Firestore contractor RFQ reads', () {
    test('procurement and owner can read org quote requests', () {
      expect(rules, contains('function contractorOrgCanReadRequest('));
      expect(rules, contains('contractorOrgCanReadRequest(resource.data)'));
    });

    test('contractorOrgId status index exists', () {
      expect(indexes, contains('"fieldPath": "contractorOrgId"'));
    });
  });

  group('Firestore engineer project create', () {
    test('project create requires contractor company owner role', () {
      expect(rules, contains('function projectCreateRoleAllowed()'));
      expect(rules, contains("hasOrgRole(orgId, 'contractorCompanyOwner')"));
    });
  });

  group('Firestore supplier org RFQs', () {
    test('supplier invited by org membership', () {
      expect(rules, contains('function supplierInvitedByOrg('));
      expect(rules, contains('supplierInvitedByOrg(data)'));
    });

    test('invitedSupplierOrgIds query index exists', () {
      expect(indexes, contains('"fieldPath": "invitedSupplierOrgIds"'));
    });
  });

  group('Firestore shipped transition', () {
    test('supplier quote shipped requires approved status', () {
      expect(rules, contains('function supplierQuoteShippedUpdateAllowed()'));
      expect(rules, contains("resource.data.status in ['אושרה', 'approved']"));
      expect(rules, contains('supplierQuoteShippedUpdateAllowed()'));
    });

    test('allows approved supplier to mark order shipped on request', () {
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

    test('assignment collection group uses uid rule without explicit index', () {
      expect(rules, contains('resource.data.uid == uid()'));
      // Single-field assignments CG index removed — Firebase auto-indexes it.
      expect(indexes, isNot(contains('"collectionGroup": "assignments"')));
    });
  });

  group('Membership display label', () {
    test('prefers email and displayName over uid', () {
      const membership = Membership(
        uid: 'abcdefghijklmnop',
        orgId: 'org-1',
        orgType: OrganizationType.contractor,
        email: 'proc@test.com',
        displayName: 'רכש בדיקה',
      );
      expect(membership.displayLabel, 'רכש בדיקה');
    });

    test('falls back to shortened uid', () {
      const membership = Membership(
        uid: 'abcdefghijklmnop',
        orgId: 'org-1',
        orgType: OrganizationType.contractor,
      );
      expect(membership.displayLabel, 'abcdefgh…');
    });
  });

  group('Engineer permissions', () {
    test('engineer cannot create projects in app matrix', () {
      final perms = EffectivePermissions.resolve(
        user: AppUser(
          id: 'eng-1',
          fullName: 'מהנדס',
          email: 'eng@test.com',
          phone: '050',
          userType: UserType.commercialCustomer,
          city: 'תל אביב',
          createdAt: DateTime(2026),
        ),
        memberships: [
          Membership(
            uid: 'eng-1',
            orgId: 'org-1',
            orgType: OrganizationType.contractor,
            roles: const [EnterpriseRole.engineer],
          ),
        ],
      );
      expect(perms, isNot(contains(Permission.manageProjects)));
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
  });

  group('Duplicate quote guard', () {
    test('deterministic quote doc id uses supplier org when provided', () {
      expect(
        SupplierQuoteDocId.forRequest(
          quoteRequestId: 'rfq-1',
          supplierId: 'sup-1',
          supplierOrgId: 'org-supplier',
        ),
        'rfq-1__org-supplier',
      );
    });

    test('legacy quote doc id falls back to supplier uid', () {
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
