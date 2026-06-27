import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Supplier quote eligibility hardening (P0 pre-launch).
void main() {
  final rules =
      File('${Directory.current.path}/firestore.rules').readAsStringSync();

  group('Supplier quote eligibility', () {
    test('requires explicit invite or openToAll for quote create', () {
      expect(rules, contains('function supplierEligibleToQuoteRequest('));
      expect(rules, contains('supplierEligibleToQuoteRequest(linkedRequest.data)'));
      expect(rules, contains('function supplierQuoteCreateOrgAllowed('));
      expect(rules, contains('supplierQuoteCreateOrgAllowed(linkedRequest.data'));
    });

    test('blocks legacy open RFQ without invite constraints', () {
      final start = rules.indexOf('function supplierCanReadRequest(');
      final end = rules.indexOf('function supplierQuoteShippedUpdateAllowed', start);
      final block = rules.substring(start, end);
      expect(block, isNot(contains('!hasInviteConstraints(data)')));
      expect(block, contains('supplierEligibleToQuoteRequest(data)'));
    });

    test('supplier request response patch requires eligibility', () {
      expect(rules, contains('function supplierCanUpdateRequestResponse('));
      expect(
        rules,
        contains('supplierCanUpdateRequestResponse(resource.data)'),
      );
    });

    test('supplier viewer role cannot quote', () {
      expect(rules, contains('function activeSupplierOrgCanQuote('));
      expect(rules, contains("hasOrgRole(orgId, 'supplierOwner')"));
      expect(rules, contains("hasOrgRole(orgId, 'supplierSalesRep')"));
      expect(rules, isNot(contains("hasOrgRole(orgId, 'supplierViewer')")));
    });

    test('invited org must match quote supplierOrgId', () {
      expect(rules, contains('function supplierQuoteOrgEligibleForRequest('));
      expect(rules, contains('orgId in data.invitedSupplierOrgIds'));
    });

    test('duplicate quote create remains blocked', () {
      expect(rules, contains('supplierQuoteDuplicateCreateBlocked(quoteId)'));
    });

    test('supplier quote create requires isSupplier', () {
      final start = rules.indexOf('match /supplierQuotes/{quoteId}');
      final end = rules.indexOf('match /supplierQuoteItems/{itemId}');
      final block = rules.substring(start, end);
      expect(block, contains('allow create: if isSupplier()'));
    });

    test('customer cannot create supplier quote', () {
      final start = rules.indexOf('match /supplierQuotes/{quoteId}');
      final end = rules.indexOf('match /supplierQuoteItems/{itemId}');
      final block = rules.substring(start, end);
      expect(block, isNot(contains('allow create: if isCustomer()')));
    });
  });
}
