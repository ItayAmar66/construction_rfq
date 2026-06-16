import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final rules =
      File('${Directory.current.path}/firestore.rules').readAsStringSync();

  test('requires deterministic doc id and blocks active duplicates', () {
    expect(rules, contains('function supplierQuoteDeterministicDocId('));
    expect(rules, contains('supplierQuoteDeterministicDocId(quoteId'));
    expect(rules, contains('supplierQuoteDuplicateCreateBlocked(quoteId)'));
    expect(rules, contains('supplierQuoteOrgKey(data)'));
  });
}
