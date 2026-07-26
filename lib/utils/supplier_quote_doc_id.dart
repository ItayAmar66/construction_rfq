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

  /// Deterministic id for one tender counter-bid version: each re-bid gets
  /// its own immutable doc (`__v{bidVersion}` suffix) so bid history survives,
  /// while still satisfying firestore.rules' deterministic-id requirement.
  static String forTenderBid({
    required String quoteRequestId,
    required String supplierId,
    String? supplierOrgId,
    required int bidVersion,
  }) {
    return '${forRequest(
      quoteRequestId: quoteRequestId,
      supplierId: supplierId,
      supplierOrgId: supplierOrgId,
    )}__v$bidVersion';
  }
}
