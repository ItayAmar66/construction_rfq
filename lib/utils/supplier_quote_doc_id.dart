/// Deterministic supplier quote document id: one quote per supplier per RFQ.
abstract final class SupplierQuoteDocId {
  static String forRequest({
    required String quoteRequestId,
    required String supplierId,
  }) =>
      '${quoteRequestId}__${supplierId}';
}
