/// Deterministic supplier quote document id: one quote per supplier org per RFQ.
abstract final class SupplierQuoteDocId {
  static String forRequest({
    required String quoteRequestId,
    required String supplierId,
    String? supplierOrgId,
  }) {
    final orgKey = supplierOrgId?.trim();
    if (orgKey != null && orgKey.isNotEmpty) {
      return '${quoteRequestId}__$orgKey';
    }
    return '${quoteRequestId}__$supplierId';
  }

  /// Tender bids keep one document per version (full bid history, with
  /// superseded versions marked outdated) instead of one mutable document —
  /// still deterministic per version, so a concurrent resubmission racing on
  /// the same version number is rejected server-side instead of silently
  /// overwriting or duplicating.
  static String forTenderBid({
    required String quoteRequestId,
    required String supplierId,
    String? supplierOrgId,
    required int bidVersion,
  }) {
    final base = forRequest(
      quoteRequestId: quoteRequestId,
      supplierId: supplierId,
      supplierOrgId: supplierOrgId,
    );
    return '${base}__v$bidVersion';
  }
}
