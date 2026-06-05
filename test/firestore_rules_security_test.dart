import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Firestore rules hardening coverage (Phase 41).
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

  group('Quote and request access', () {
    test('quoteRequests protect customer ownership on create', () {
      expect(rules, contains('match /quoteRequests/{requestId}'));
      expect(rules, contains('request.resource.data.customerId == uid()'));
    });

    test('quoteRequests customer updates allow embedded items field', () {
      expect(rules, contains("'items'"));
      expect(rules, contains('changedOnly(['));
    });

    test('supplierQuotes require supplier ownership on create', () {
      expect(rules, contains('match /supplierQuotes/{quoteId}'));
      expect(rules, contains('request.resource.data.supplierId == uid()'));
    });

    test('supplier quote read allows customer via request doc', () {
      expect(rules, contains('requestDoc(resource.data.requestId)'));
    });

    test('quoteRequestItems disallow client updates', () {
      final start = rules.indexOf('match /quoteRequestItems/{itemId}');
      final end = rules.indexOf('match /', start + 1);
      final block = rules.substring(start, end);
      expect(block, contains('allow update, delete: if false;'));
    });

    test('supplierQuoteItems disallow client updates', () {
      final start = rules.indexOf('match /supplierQuoteItems/{itemId}');
      final end = rules.indexOf('match /', start + 1);
      final block =
          end > start ? rules.substring(start, end) : rules.substring(start);
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
}
