import '../../models/catalog/catalog_search_query.dart';
import 'firestore_catalog_search_query_builder.dart';

/// Encodes [FirestoreCatalogSearchPlan] as Firestore REST `:runQuery` body.
abstract final class FirestoreRestStructuredQueryEncoder {
  static Map<String, dynamic> encode({
    required String collectionId,
    required FirestoreCatalogSearchPlan plan,
    required int limit,
  }) {
    final filters = <Map<String, dynamic>>[];

    for (final entry in plan.equalityFilters.entries) {
      filters.add(_fieldFilter(
        entry.key,
        'EQUAL',
        _encodeValue(entry.value),
      ));
    }

    if (plan.arrayContainsField != null && plan.arrayContainsValue != null) {
      filters.add(_fieldFilter(
        plan.arrayContainsField!,
        'ARRAY_CONTAINS',
        {'stringValue': plan.arrayContainsValue},
      ));
    }

    if (plan.rangeField != null &&
        plan.rangeStart != null &&
        plan.rangeEnd != null) {
      filters.add(_fieldFilter(
        plan.rangeField!,
        'GREATER_THAN_OR_EQUAL',
        {'stringValue': plan.rangeStart},
      ));
      filters.add(_fieldFilter(
        plan.rangeField!,
        'LESS_THAN',
        {'stringValue': plan.rangeEnd},
      ));
    }

    return {
      'structuredQuery': {
        'from': [
          {'collectionId': collectionId},
        ],
        if (filters.isNotEmpty)
          'where': filters.length == 1
              ? filters.first
              : {
                  'compositeFilter': {
                    'op': 'AND',
                    'filters': filters,
                  },
                },
        'orderBy': [
          {
            'field': {'fieldPath': plan.orderByField},
            'direction': 'ASCENDING',
          },
        ],
        'limit': limit,
      },
    };
  }

  static Map<String, dynamic> encodeFromSearchQuery({
    required String collectionId,
    required CatalogSearchQuery query,
    required int limit,
  }) {
    return encode(
      collectionId: collectionId,
      plan: FirestoreCatalogSearchQueryBuilder.plan(query),
      limit: limit,
    );
  }

  static Map<String, dynamic> _fieldFilter(
    String fieldPath,
    String op,
    Map<String, dynamic> value,
  ) {
    return {
      'fieldFilter': {
        'field': {'fieldPath': fieldPath},
        'op': op,
        'value': value,
      },
    };
  }

  static Map<String, dynamic> _encodeValue(Object value) {
    if (value is bool) return {'booleanValue': value};
    if (value is int) return {'integerValue': value.toString()};
    if (value is double) return {'doubleValue': value};
    return {'stringValue': value.toString()};
  }
}
