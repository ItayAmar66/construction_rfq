/// Shortens verbose catalog titles for supplier quote line cards.
abstract final class CatalogDisplayName {
  static String forQuoteLine({
    required String productName,
    String? variantName,
    String? catalogProductName,
  }) {
    final base = productName.trim();
    final variant = variantName?.trim() ?? '';
    final catalog = catalogProductName?.trim() ?? '';

    if (variant.isNotEmpty && base.contains(variant) && catalog.isNotEmpty) {
      return catalog;
    }
    if (catalog.isNotEmpty &&
        base.isNotEmpty &&
        _normalize(catalog) == _normalize(base)) {
      return catalog;
    }
    if (variant.isNotEmpty && base.endsWith(' — $variant')) {
      return base;
    }
    return base.isNotEmpty ? base : (catalog.isNotEmpty ? catalog : variant);
  }

  static String _normalize(String value) =>
      value.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
}
