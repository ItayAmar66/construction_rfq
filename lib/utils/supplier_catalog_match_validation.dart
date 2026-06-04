import '../models/quote_request_item.dart';
import 'hebrew_strings.dart';

/// Validation helpers for supplier exact/alternative catalog quoting.
abstract final class SupplierCatalogMatchValidation {
  /// Returns an error message when an included alternative line lacks a note.
  static String? missingAlternativeNote({
    required QuoteRequestItem item,
    required bool isExactMatch,
    required bool includeInQuote,
    required double unitPrice,
    required String supplierNotes,
  }) {
    if (!item.isCatalogMatched || isExactMatch) return null;
    if (!includeInQuote || unitPrice <= 0) return null;
    if (supplierNotes.trim().isEmpty) {
      return HebrewStrings.alternativeNoteRequired;
    }
    return null;
  }
}
