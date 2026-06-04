import 'dart:convert';
import 'dart:io';

import '../models/catalog/catalog_search_query.dart';
import '../models/catalog/catalog_variant.dart';
import '../repositories/catalog_search/catalog_search_repository.dart';
import '../repositories/catalog_search/emulator_rest_catalog_search_repository.dart';

/// Live search smoke checks against emulator catalog data (VM-safe REST).
class CatalogSearchEmulatorSmoke {
  static const defaultHebrewTerms = ['דבק', 'בלוק', 'צבע'];

  static Future<CatalogSearchSmokeResult> run(
    CatalogSearchRepository repo, {
    File? verificationSummary,
    List<String> hebrewTerms = defaultHebrewTerms,
  }) async {
    final errors = <String>[];

    if (verificationSummary != null && verificationSummary.existsSync()) {
      try {
        final json = jsonDecode(verificationSummary.readAsStringSync())
            as Map<String, dynamic>;
        if (json['passed'] != true) {
          errors.add('verification summary passed != true');
        }
        final searchFields = json['searchFields'] as Map<String, dynamic>?;
        if (searchFields == null) {
          errors.add('verification summary missing searchFields');
        } else if (searchFields['passed'] != true) {
          errors.add('searchFields.passed != true');
        }
      } catch (e) {
        errors.add('failed to read verification summary: $e');
      }
    }

    final tree = await repo.getCategoryTree();
    if (tree.isEmpty) {
      errors.add('category tree is empty');
    } else if (tree.length != 418) {
      errors.add('category tree count ${tree.length} != 418');
    }

    final seed = await _resolveBrowseSeed(repo);
    if (seed == null) {
      errors.add(
        'no imported variant with categoryIds found for browse smoke',
      );
      return CatalogSearchSmokeResult(
        passed: false,
        errors: errors,
        categoryCount: tree.length,
      );
    }

    final browseCategory = seed.categoryId;
    final browse = await repo.browseVariantsByCategory(
      CatalogSearchQuery(categoryId: browseCategory, limit: 10),
    );
    if (browse.hits.isEmpty) {
      errors.add(
        'category browse returned no hits for $browseCategory '
        '(from variant ${seed.variant.id})',
      );
    } else {
      if (browse.hits.length > 10) {
        errors.add('browse page exceeded limit');
      }

      final hit = browse.hits.first;
      if (await repo.getVariantById(hit.variant.id) == null) {
        errors.add('getVariantById failed for ${hit.variant.id}');
      }
      if (await repo.getProductById(hit.variant.productId) == null) {
        errors.add('getProductById failed for ${hit.variant.productId}');
      }

      if (await repo.getVariantById(seed.variant.id) == null) {
        errors.add('getVariantById failed for seed ${seed.variant.id}');
      }

      if (browse.hasMore && browse.nextPageToken != null) {
        final page2 = await repo.browseVariantsByCategory(
          CatalogSearchQuery(
            categoryId: browseCategory,
            limit: 1,
            pageToken: browse.nextPageToken,
          ),
        );
        if (page2.hits.isEmpty) {
          errors.add('browse pagination returned empty second page');
        }
      }

      var termsWithHits = 0;
      final terms = <String>[...hebrewTerms];
      final sampled = hit.variant.searchTokens
          .where((t) => t.length >= 2)
          .take(3);
      terms.addAll(sampled);

      for (final term in terms.toSet()) {
        final page = await repo.searchVariants(
          CatalogSearchQuery(text: term, limit: 5),
        );
        if (page.hits.isNotEmpty) termsWithHits++;
      }

      if (termsWithHits < 3) {
        errors.add(
          'text search returned hits for only $termsWithHits terms '
          '(expected >= 3)',
        );
      }

      final skuSample = hit.variant.skuLower.isNotEmpty
          ? hit.variant.skuLower
          : seed.variant.skuLower;
      if (skuSample.isNotEmpty) {
        final prefix =
            skuSample.length >= 3 ? skuSample.substring(0, 3) : skuSample;
        final skuPage = await repo.searchVariants(
          CatalogSearchQuery(text: prefix, limit: 5),
        );
        if (skuPage.hits.isEmpty) {
          errors.add('SKU-like search returned no hits for prefix $prefix');
        }
      }
    }

    return CatalogSearchSmokeResult(
      passed: errors.isEmpty,
      errors: errors,
      categoryCount: tree.length,
      browseHits: browse.hits.length,
      browseCategoryId: browseCategory,
    );
  }

  static Future<({String categoryId, CatalogVariant variant})?>
      _resolveBrowseSeed(CatalogSearchRepository repo) async {
    if (repo is EmulatorRestCatalogSearchRepository) {
      return repo.pickBrowseSeedFromVariants();
    }
    return null;
  }
}

class CatalogSearchSmokeResult {
  const CatalogSearchSmokeResult({
    required this.passed,
    this.errors = const [],
    this.categoryCount = 0,
    this.browseHits = 0,
    this.browseCategoryId,
  });

  final bool passed;
  final List<String> errors;
  final int categoryCount;
  final int browseHits;
  final String? browseCategoryId;
}
