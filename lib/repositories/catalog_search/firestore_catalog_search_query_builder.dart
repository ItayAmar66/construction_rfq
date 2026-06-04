import 'package:cloud_firestore/cloud_firestore.dart';

import '../../catalog_import/catalog_text_utils.dart';
import '../../models/catalog/catalog_search_query.dart';

/// Describes how a [CatalogSearchQuery] maps to Firestore (testable without network).
enum CatalogFirestoreSearchStrategy {
  categoryBrowse,
  searchToken,
  namePrefix,
  skuPrefix,
  productVariants,
}

class FirestoreCatalogSearchPlan {
  const FirestoreCatalogSearchPlan({
    required this.strategy,
    required this.orderByField,
    this.arrayContainsField,
    this.arrayContainsValue,
    this.rangeField,
    this.rangeStart,
    this.rangeEnd,
    this.equalityFilters = const {},
  });

  final CatalogFirestoreSearchStrategy strategy;
  final String orderByField;
  final String? arrayContainsField;
  final String? arrayContainsValue;
  final String? rangeField;
  final String? rangeStart;
  final String? rangeEnd;
  final Map<String, Object> equalityFilters;
}

/// Builds Firestore queries for variant search (no full-collection scans).
abstract final class FirestoreCatalogSearchQueryBuilder {
  static FirestoreCatalogSearchPlan plan(CatalogSearchQuery query) {
    final filters = <String, Object>{};
    if (!query.includeInactive) {
      filters['isActive'] = true;
    }

    if (query.hasCategory) {
      return FirestoreCatalogSearchPlan(
        strategy: CatalogFirestoreSearchStrategy.categoryBrowse,
        orderByField: query.sort == CatalogSearchSort.sortOrder
            ? 'sortOrder'
            : 'displayNameLower',
        arrayContainsField: 'categoryIds',
        arrayContainsValue: query.categoryId!.trim(),
        equalityFilters: filters,
      );
    }

    final normalized = query.hasText
        ? CatalogTextUtils.normalizeForSearch(query.text!)
        : '';

    if (normalized.isEmpty) {
      return FirestoreCatalogSearchPlan(
        strategy: CatalogFirestoreSearchStrategy.namePrefix,
        orderByField: 'displayNameLower',
        rangeField: 'displayNameLower',
        rangeStart: '',
        rangeEnd: '\uf8ff',
        equalityFilters: filters,
      );
    }

    final tokens = CatalogTextUtils.buildSearchTokens(
      name: normalized,
      maxTokens: 5,
    );
    final skuLike = normalized.length <= 32 &&
        RegExp(r'^[a-z0-9\-]+$').hasMatch(normalized.replaceAll(' ', ''));

    if (skuLike && normalized.length >= 3) {
      return FirestoreCatalogSearchPlan(
        strategy: CatalogFirestoreSearchStrategy.skuPrefix,
        orderByField: 'skuLower',
        rangeField: 'skuLower',
        rangeStart: normalized,
        rangeEnd: '$normalized\uf8ff',
        equalityFilters: filters,
      );
    }

    final token = tokens.firstWhere(
      (t) => t.length >= 2,
      orElse: () => normalized,
    );
    if (token.length >= 2) {
      return FirestoreCatalogSearchPlan(
        strategy: CatalogFirestoreSearchStrategy.searchToken,
        orderByField: 'displayNameLower',
        arrayContainsField: 'searchTokens',
        arrayContainsValue: token,
        equalityFilters: filters,
      );
    }

    return FirestoreCatalogSearchPlan(
      strategy: CatalogFirestoreSearchStrategy.namePrefix,
      orderByField: 'displayNameLower',
      rangeField: 'displayNameLower',
      rangeStart: normalized,
      rangeEnd: '$normalized\uf8ff',
      equalityFilters: filters,
    );
  }

  static Query<Map<String, dynamic>> apply(
    Query<Map<String, dynamic>> base,
    FirestoreCatalogSearchPlan plan,
  ) {
    Query<Map<String, dynamic>> q = base;

    for (final entry in plan.equalityFilters.entries) {
      q = q.where(entry.key, isEqualTo: entry.value);
    }

    if (plan.arrayContainsField != null && plan.arrayContainsValue != null) {
      q = q.where(
        plan.arrayContainsField!,
        arrayContains: plan.arrayContainsValue,
      );
    }

    if (plan.rangeField != null &&
        plan.rangeStart != null &&
        plan.rangeEnd != null) {
      q = q
          .where(plan.rangeField!, isGreaterThanOrEqualTo: plan.rangeStart)
          .where(plan.rangeField!, isLessThan: plan.rangeEnd);
    }

    return q.orderBy(plan.orderByField);
  }

  static ({String? nameLower, String? docId}) parsePageToken(String? token) {
    if (token == null || token.isEmpty) return (nameLower: null, docId: null);
    final parts = token.split('|');
    if (parts.length < 2) return (nameLower: null, docId: null);
    return (nameLower: parts[0], docId: parts[1]);
  }

  static String encodePageToken(String orderKey, String docId) =>
      '$orderKey|$docId';
}
