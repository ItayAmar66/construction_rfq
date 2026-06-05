import '../models/app_user.dart';
import '../models/quote_request.dart';
import '../models/quote_request_item.dart';

/// Foundation helpers for supplier targeting (no hard cutover yet).
abstract final class SupplierTargetingHelpers {
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
  }) {
    final invited = request.invitedSupplierIds;
    if (invited.isEmpty) return true;
    return invited.contains(supplierId);
  }

  /// Combined relevance check — defaults to visible unless invited list excludes.
  static bool isSupplierRelevant({
    required AppUser supplier,
    required QuoteRequest request,
    required List<QuoteRequestItem> items,
  }) {
    if (!isSupplierInvited(request: request, supplierId: supplier.id)) {
      return false;
    }
    return matchesServiceArea(supplier: supplier, request: request) &&
        matchesRequestCategories(supplier: supplier, items: items);
  }

  /// Hide only when an explicit invite list exists and supplier is not invited.
  static bool shouldShowToSupplier({
    required QuoteRequest request,
    required String supplierId,
  }) {
    if (request.invitedSupplierIds.isEmpty) return true;
    return isSupplierInvited(request: request, supplierId: supplierId);
  }

  /// Soft relevance label for supplier incoming list UI.
  static String relevanceLabel({
    required AppUser supplier,
    required QuoteRequest request,
    required List<QuoteRequestItem> items,
  }) {
    if (request.invitedSupplierIds.isNotEmpty) {
      return 'הוזמנת לבקשה זו';
    }
    if (supplier.supplierCategoryIds.isNotEmpty &&
        matchesRequestCategories(supplier: supplier, items: items)) {
      return 'מתאים לתחומי הספק';
    }
    return 'פתוח לכל הספקים';
  }
}
