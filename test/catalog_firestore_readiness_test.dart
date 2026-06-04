import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Firestore rules/index readiness for catalog + RFQ matching (Phase 12).
void main() {
  final root = Directory.current.path;

  test('catalog collections are signed-in read only', () {
    final rules = File('$root/firestore.rules').readAsStringSync();
    for (final collection in [
      'catalogCategories',
      'catalogProducts',
      'catalogVariants',
      'catalogMeta',
    ]) {
      expect(rules, contains('match /$collection/{'));
      expect(rules, contains('allow read: if isSignedIn();'));
    }
    expect(rules.split('allow write: if false;').length, greaterThan(4));
  });

  test('quoteRequests allow embedded catalog snapshot item updates', () {
    final rules = File('$root/firestore.rules').readAsStringSync();
    expect(rules, contains("'items'"));
    expect(rules, contains('changedOnly(['));
  });

  test('firestore.indexes.json includes catalog variant browse and search indexes',
      () {
    final raw = File('$root/firestore.indexes.json').readAsStringSync();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final indexes = json['indexes'] as List<dynamic>;
    final catalogVariantIndexes = indexes.where((entry) {
      final map = entry as Map<String, dynamic>;
      return map['collectionGroup'] == 'catalogVariants';
    }).toList();

    expect(catalogVariantIndexes.length, greaterThanOrEqualTo(5));

    final hasCategoryBrowse = catalogVariantIndexes.any((entry) {
      final fields = (entry as Map)['fields'] as List;
      return fields.any((f) => (f as Map)['fieldPath'] == 'categoryIds');
    });
    final hasTokenSearch = catalogVariantIndexes.any((entry) {
      final fields = (entry as Map)['fields'] as List;
      return fields.any((f) => (f as Map)['fieldPath'] == 'searchTokens');
    });

    expect(hasCategoryBrowse, isTrue);
    expect(hasTokenSearch, isTrue);
  });

  test('firestore.indexes.json includes quote request and supplier quote indexes',
      () {
    final raw = File('$root/firestore.indexes.json').readAsStringSync();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final indexes = json['indexes'] as List<dynamic>;
    final groups = indexes
        .map((e) => (e as Map<String, dynamic>)['collectionGroup'] as String)
        .toSet();

    expect(groups, contains('quoteRequests'));
    expect(groups, contains('supplierQuotes'));
  });
}
