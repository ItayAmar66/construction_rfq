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
}
