import '../models/app_user.dart';
import '../models/quote_request.dart';
import '../models/quote_request_item.dart';

enum CustomerTargetingMode { open, invited, categoryMatch }

class CustomerTargetingSummary {
  const CustomerTargetingSummary({
    required this.mode,
    required this.title,
    required this.detail,
    this.supplierNames = const [],
  });

  final CustomerTargetingMode mode;
  final String title;
  final String detail;
  final List<String> supplierNames;
}

/// Foundation helpers for supplier targeting (no hard cutover yet).
abstract final class SupplierTargetingHelpers {
  static const qaStressSupplierA = 'ספק עומס A — QA_STRESS_FLOW_002';
  static const qaStressSupplierB = 'ספק עומס B — QA_STRESS_FLOW_002';

  static const qaSupplierPresets = [
    qaStressSupplierA,
    qaStressSupplierB,
  ];

  static bool _nameMatches(String left, String right) =>
      left.trim().toLowerCase() == right.trim().toLowerCase();

  /// Whether a supplier serves the request region/city.
  static bool matchesServiceArea({
    required AppUser supplier,
    required QuoteRequest request,
  }) {
    if (supplier.serviceAreas.isEmpty) return true;
    final city = request.customerCity.trim().toLowerCase();
    if (city.isEmpty) return true;
    return supplier.serviceAreas.any(
      (area) => area.trim().toLowerCase() == city,
    );
  }

  /// Whether supplier category capabilities overlap request catalog lines.
  static bool matchesRequestCategories({
    required AppUser supplier,
    required List<QuoteRequestItem> items,
    List<String>? supplierCategoryIds,
  }) {
    final capabilities = supplierCategoryIds ?? supplier.supplierCategoryIds;
    if (capabilities.isEmpty) return true;

    final requestCategories = items
        .map((item) => item.categoryId ?? item.category)
        .where((value) => value.trim().isNotEmpty)
        .toSet();
    if (requestCategories.isEmpty) return true;

    return requestCategories.any(capabilities.contains);
  }

  /// Invited-only mode when list is non-empty; otherwise broad visibility.
  static bool isSupplierInvited({
    required QuoteRequest request,
    required String supplierId,
    String? supplierName,
  }) {
    final invitedIds = request.invitedSupplierIds;
    if (invitedIds.isNotEmpty) {
      return invitedIds.contains(supplierId);
    }

    final invitedNames = request.invitedSupplierNames;
    if (invitedNames.isEmpty) return true;

    final name = supplierName?.trim() ?? '';
    if (name.isEmpty) return false;
    return invitedNames.any((target) => _nameMatches(target, name));
  }

  /// Combined relevance check — defaults to visible unless invited list excludes.
  static bool isSupplierRelevant({
    required AppUser supplier,
    required QuoteRequest request,
    required List<QuoteRequestItem> items,
  }) {
    if (!isSupplierInvited(
      request: request,
      supplierId: supplier.id,
      supplierName: supplier.fullName,
    )) {
      return false;
    }
    return matchesServiceArea(supplier: supplier, request: request) &&
        matchesRequestCategories(supplier: supplier, items: items);
  }

  /// Hide only when an explicit invite list exists and supplier is not invited.
  static bool shouldShowToSupplier({
    required QuoteRequest request,
    required String supplierId,
    String? supplierName,
  }) {
    if (request.invitedSupplierIds.isEmpty &&
        request.invitedSupplierNames.isEmpty) {
      return true;
    }
    return isSupplierInvited(
      request: request,
      supplierId: supplierId,
      supplierName: supplierName,
    );
  }

  /// Customer-facing targeting mode before RFQ submit.
  static CustomerTargetingSummary customerTargetingSummary({
    required List<QuoteRequestItem> items,
    List<String> invitedSupplierIds = const [],
    List<String> invitedSupplierNames = const [],
  }) {
    final names = invitedSupplierNames
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList();

    if (invitedSupplierIds.isNotEmpty || names.isNotEmpty) {
      final count =
          invitedSupplierIds.isNotEmpty ? invitedSupplierIds.length : names.length;
      final detail = names.isNotEmpty
          ? 'יעד: ${names.join(' · ')}'
          : count == 1
              ? 'הבקשה תוצג לספק מוזמן אחד'
              : 'הבקשה תוצג ל-$count ספקים מוזמנים';
      return CustomerTargetingSummary(
        mode: CustomerTargetingMode.invited,
        title: 'ספקים מוזמנים',
        detail: detail,
        supplierNames: names,
      );
    }

    final catalogCategories = items
        .where((item) => item.isCatalogMatched)
        .map((item) => item.categoryId ?? item.category)
        .where((value) => value.trim().isNotEmpty)
        .toSet();
    if (catalogCategories.isNotEmpty) {
      return CustomerTargetingSummary(
        mode: CustomerTargetingMode.categoryMatch,
        title: 'מתאים לתחומי הקטלוג',
        detail:
            'ספקים עם התאמה ב-${catalogCategories.length} קטגוריות יראו את הבקשה כרלוונטית',
      );
    }

    return const CustomerTargetingSummary(
      mode: CustomerTargetingMode.open,
      title: 'פתוח לכל הספקים',
      detail: 'הבקשה תישלח לכל הספקים הרלוונטיים',
    );
  }

  /// Soft relevance label for supplier incoming list UI.
  static String relevanceLabel({
    required AppUser supplier,
    required QuoteRequest request,
    required List<QuoteRequestItem> items,
  }) {
    if (request.invitedSupplierIds.isNotEmpty ||
        request.invitedSupplierNames.isNotEmpty) {
      return 'הוזמנת לבקשה זו';
    }
    if (supplier.supplierCategoryIds.isNotEmpty &&
        matchesRequestCategories(supplier: supplier, items: items)) {
      return 'מתאים לתחומי הספק';
    }
    return 'פתוח לכל הספקים';
  }
}
