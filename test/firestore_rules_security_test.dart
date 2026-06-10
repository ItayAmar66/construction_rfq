import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Firestore rules hardening coverage (Phase 41 + 64A).
void main() {
  final rules = File('${Directory.current.path}/firestore.rules').readAsStringSync();

  group('Catalog read-only', () {
    const catalogCollections = [
      'products',
      'catalogCategories',
      'catalogProducts',
      'catalogVariants',
      'catalogMeta',
      'appMeta',
    ];

    for (final collection in catalogCollections) {
      test('$collection allows signed-in read only', () {
        expect(rules, contains('match /$collection/{'));
        final start = rules.indexOf('match /$collection/{');
        final end = rules.indexOf('match /', start + 1);
        final block = end > start
            ? rules.substring(start, end)
            : rules.substring(start);
        expect(block, contains('allow read: if isSignedIn();'));
        expect(block, contains('allow write: if false;'));
      });
    }
  });

  group('User role escalation', () {
    test('users block requires valid userType on create', () {
      expect(rules, contains('function validUserType(userType)'));
      expect(rules, contains('function userCreateAllowed()'));
      expect(rules, contains('allow create: if isSignedIn() && uid() == userId && userCreateAllowed()'));
    });

    test('users block locks userType and verified on update', () {
      expect(rules, contains('function userProfileUpdateAllowed()'));
      expect(rules, contains('request.resource.data.userType == resource.data.userType'));
      expect(rules, contains('request.resource.data.verified == resource.data.verified'));
      expect(rules, contains('allow update: if isSignedIn() && uid() == userId && userProfileUpdateAllowed()'));
    });

    test('users disallow client delete', () {
      final start = rules.indexOf('match /users/{userId}');
      final end = rules.indexOf('match /', start + 1);
      final block = rules.substring(start, end);
      expect(block, contains('allow delete: if false;'));
    });

    test('profile updates limited to safe fields', () {
      expect(rules, contains("'name'"));
      expect(rules, contains("'fullName'"));
      expect(rules, contains("'phone'"));
      expect(rules, contains("'city'"));
      expect(rules, contains("'notes'"));
      expect(rules, contains("'updatedAt'"));
    });
  });

  group('Quote and request access', () {
    test('quoteRequests protect customer ownership on create', () {
      expect(rules, contains('match /quoteRequests/{requestId}'));
      expect(rules, contains('function quoteRequestCreateAllowed()'));
      expect(rules, contains('request.resource.data.customerId == uid()'));
    });

    test('quoteRequests validate status and items on create', () {
      expect(rules, contains('function validQuoteRequestStatus(status)'));
      expect(rules, contains('function validRequestItemsList(items)'));
      expect(rules, contains("'ממתין לאישור רכש'"));
      expect(rules, contains("'pendingApproval'"));
    });

    test('quoteRequests customer updates allow embedded items field', () {
      expect(rules, contains("'items'"));
      expect(rules, contains('function requestItemsUnchangedOrValid()'));
      expect(rules, contains('changedOnly(['));
    });

    test('manual request items allow core scalar fields', () {
      expect(rules, contains('function validRequestItem(item)'));
      expect(rules, contains("'productId'"));
      expect(rules, contains("'category'"));
      expect(rules, contains("'unitType'"));
      expect(rules, contains("'quantity'"));
    });

    test('supplierQuotes require supplier ownership on create', () {
      expect(rules, contains('match /supplierQuotes/{quoteId}'));
      expect(rules, contains('function supplierQuoteCreateAllowed()'));
      expect(rules, contains('request.resource.data.supplierId == uid()'));
    });

    test('supplierQuotes validate customer linkage and prices', () {
      expect(rules, contains('function validSupplierQuoteStatus(status)'));
      expect(rules, contains('function validSupplierQuoteItemsList(items)'));
      expect(rules, contains('request.resource.data.totalPrice >= 0'));
      expect(rules, contains('request.resource.data.customerId == linkedRequest.data.customerId'));
    });

    test('supplier quote read allows customer via request doc', () {
      expect(rules, contains('requestDoc(resource.data.requestId)'));
    });

    test('quoteRequestItems require customer ownership on legacy create', () {
      expect(rules, contains('function validLegacyRequestItem(data)'));
      final start = rules.indexOf('match /quoteRequestItems/{itemId}');
      final end = rules.indexOf('match /', start + 1);
      final block = rules.substring(start, end);
      expect(block, contains('requestDoc(request.resource.data.quoteRequestId).data.customerId == uid()'));
      expect(block, contains('allow update, delete: if false;'));
    });

    test('supplierQuoteItems require supplier ownership on legacy create', () {
      expect(rules, contains('function validLegacySupplierQuoteItem(data)'));
      final start = rules.indexOf('match /supplierQuoteItems/{itemId}');
      final end = rules.indexOf('match /', start + 1);
      final block =
          end > start ? rules.substring(start, end) : rules.substring(start);
      expect(block, contains('supplierQuoteDoc(request.resource.data.supplierQuoteId).data.supplierId == uid()'));
      expect(block, contains('allow update, delete: if false;'));
    });
  });

  group('Embedded catalog snapshot fields', () {
    test('rules document embedded catalog fields on quote items', () {
      expect(rules, contains('variantId'));
      expect(rules, contains('isCatalogMatched'));
      expect(rules, contains('isExactMatch'));
      expect(rules, contains('isAlternative'));
      expect(rules, contains('quotedSku'));
    });
  });

  group('Security documentation', () {
    test('SECURITY_NOTES documents role and admin limitations', () {
      final notes =
          File('${Directory.current.path}/SECURITY_NOTES.md').readAsStringSync();
      expect(notes, contains('userType'));
      expect(notes, contains('custom claims'));
      expect(notes, contains('read-only'));
      expect(notes, contains('Manual item'));
    });
  });

  group('Permission regression', () {
    test('rules block client catalog writes', () {
      expect(rules, contains('allow write: if false;'));
    });

    test('rules block user delete', () {
      final start = rules.indexOf('match /users/{userId}');
      final end = rules.indexOf('match /', start + 1);
      expect(rules.substring(start, end), contains('allow delete: if false;'));
    });

    test('supplier quote create requires supplierId match', () {
      expect(rules, contains('request.resource.data.supplierId == uid()'));
    });

    test('legacy quote items block update and delete', () {
      final start = rules.indexOf('match /quoteRequestItems/{itemId}');
      final block = rules.substring(start, rules.indexOf('match /', start + 1));
      expect(block, contains('allow update, delete: if false;'));
    });

    test('valid manual item fields documented in rules', () {
      expect(rules, contains("'productName'"));
      expect(rules, contains("'quantity'"));
    });
  });

  group('Enterprise permission scaffolding', () {
    test('isPlatformAdmin reads custom claim only', () {
      expect(rules, contains('function isPlatformAdmin()'));
      expect(rules, contains('request.auth.token.platformAdmin == true'));
    });

    test('supplierDirectory is read-only for signed-in users', () {
      expect(rules, contains('match /supplierDirectory/{supplierUid}'));
      final start = rules.indexOf('match /supplierDirectory/{supplierUid}');
      final end = rules.indexOf('match /', start + 1);
      final block = rules.substring(start, end);
      expect(block, contains('allow read: if isSignedIn();'));
      expect(block, contains('allow write: if false;'));
    });

    test('quote request create allows draft and pending approval', () {
      expect(rules, contains("'ממתין לאישור רכש'"));
      expect(rules, contains("'pendingApproval'"));
      expect(rules, contains("'טיוטה'"));
      expect(rules, contains("'draft'"));
    });

    test('clients cannot self-assign platformAdmin via users collection', () {
      final start = rules.indexOf('match /users/{userId}');
      final end = rules.indexOf('match /', start + 1);
      final block = rules.substring(start, end);
      expect(block, isNot(contains('platformAdmin')));
    });
  });

  group('Supplier incoming query alignment', () {
    test('rules include supplierCanReadRequest and openToAllSuppliers', () {
      expect(rules, contains('function supplierCanReadRequest('));
      expect(rules, contains('openToAllSuppliers'));
      expect(rules, contains('isPlatformAdmin()'));
    });
  });

  group('Projects collection', () {
    test('project owner can create with ownerUid and status', () {
      expect(rules, contains('function projectOwnerCreateAllowed()'));
      expect(rules, contains('request.resource.data.ownerUid == uid()'));
      expect(rules, contains("status in ['active', 'archived']"));
      expect(rules, contains("request.resource.data.keys().hasAll(['createdAt', 'updatedAt'])"));
    });

    test('project owner can read and update own project', () {
      expect(rules, contains('match /projects/{projectId}'));
      expect(rules, contains('function projectOwnerUpdateAllowed()'));
      final start = rules.indexOf('match /projects/{projectId}');
      final end = rules.indexOf('match /', start + 1);
      final block = rules.substring(start, end);
      expect(block, contains('resource.data.ownerUid == uid()'));
      expect(block, contains('projectOwnerUpdateAllowed()'));
      expect(block, contains('allow delete: if false;'));
    });

    test('other users cannot read private projects without owner match', () {
      final start = rules.indexOf('match /projects/{projectId}');
      final end = rules.indexOf('match /', start + 1);
      final block = rules.substring(start, end);
      expect(block, contains('resource.data.ownerUid == uid()'));
      expect(block, isNot(contains('allow read: if isSignedIn();')));
    });

    test('platformAdmin can read and manage all projects', () {
      final start = rules.indexOf('match /projects/{projectId}');
      final end = rules.indexOf('match /', start + 1);
      final block = rules.substring(start, end);
      expect(block, contains('isPlatformAdmin()'));
      expect(block, contains('projectAdminCreateAllowed()'));
    });

    test('suppliers do not get broad projects read', () {
      final start = rules.indexOf('match /projects/{projectId}');
      final end = rules.indexOf('match /', start + 1);
      final block = rules.substring(start, end);
      expect(block, isNot(contains('isSupplier()')));
    });
  });

  group('Organization scaffolding', () {
    test('org helper functions exist', () {
      expect(rules, contains('function isOrgMember(orgId)'));
      expect(rules, contains('function hasOrgRole(orgId, role)'));
      expect(rules, contains('function hasProjectAccess(projectId)'));
    });

    test('organizations are not client writable', () {
      expect(rules, contains('match /organizations/{orgId}'));
      final start = rules.indexOf('match /organizations/{orgId}');
      final end = rules.indexOf('match /', start + 1);
      expect(rules.substring(start, end), contains('allow write: if false;'));
    });
  });
}
