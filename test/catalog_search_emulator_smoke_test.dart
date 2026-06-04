import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:construction_rfq/catalog_import/import_config.dart';
import 'package:construction_rfq/firebase_options.dart';
import 'package:construction_rfq/models/catalog/catalog_search_query.dart';
import 'package:construction_rfq/repositories/catalog_search/firestore_catalog_search_repository.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repository smoke tests against local Firestore emulator data.
///
/// Run after gate import:
///   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 \
///   flutter test test/catalog_search_emulator_smoke_test.dart
void main() {
  final hasEmulator = CatalogImportSafety.isEmulatorHostConfigured;
  final verificationSummary = File(
    'tools/catalog_import/out/emulator_verification/summary.json',
  );

  test(
    'emulator verification summary includes searchFields PASS',
    () {
      final json =
          jsonDecode(verificationSummary.readAsStringSync()) as Map<String, dynamic>;
      expect(json['passed'], isTrue);
      expect(json['variantCount'], 31551);
      final searchFields = json['searchFields'] as Map<String, dynamic>?;
      expect(searchFields, isNotNull, reason: 're-run ./tools/catalog_import/run_emulator_gate.sh');
      expect(searchFields!['passed'], isTrue);
      expect(searchFields['variantsFailed'], 0);
    },
    skip: !verificationSummary.existsSync() ||
        !_summaryHasSearchFields(verificationSummary),
  );

  test(
    'CatalogSearchRepository smoke on emulator catalog',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      final repo = FirestoreCatalogSearchRepository();

      final tree = await repo.getCategoryTree();
      expect(tree.length, 418);

      final browseCandidates = tree
          .where((c) => c.hasProducts && c.productCount > 0)
          .toList();
      expect(browseCandidates, isNotEmpty);
      final browseCategory = browseCandidates.first.id;

      final browse = await repo.browseVariantsByCategory(
        CatalogSearchQuery(categoryId: browseCategory, limit: 10),
      );
      expect(browse.hits, isNotEmpty);
      expect(browse.hits.length, lessThanOrEqualTo(10));

      final hit = browse.hits.first;
      expect(await repo.getVariantById(hit.variant.id), isNotNull);
      expect(await repo.getProductById(hit.variant.productId), isNotNull);

      final hebrewTerms = ['דבק', 'בלוק', 'צבע'];
      var termsWithHits = 0;
      for (final term in hebrewTerms) {
        final page = await repo.searchVariants(
          CatalogSearchQuery(text: term, limit: 5),
        );
        if (page.hits.isNotEmpty) termsWithHits++;
      }
      expect(
        termsWithHits,
        greaterThanOrEqualTo(2),
        reason: 'expected at least 2 of $hebrewTerms to return hits',
      );

      final skuProbe = await repo.searchVariants(
        const CatalogSearchQuery(text: 'fx', limit: 5),
      );
      if (skuProbe.hits.isNotEmpty) {
        expect(skuProbe.hits.first.variant.skuLower, isNotEmpty);
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
    skip: !hasEmulator,
  );
}

bool _summaryHasSearchFields(File file) {
  try {
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    return json.containsKey('searchFields');
  } catch (_) {
    return false;
  }
}
