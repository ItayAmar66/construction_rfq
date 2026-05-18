/// VAT and totals for supplier quotes.
class QuoteFinancialBreakdown {
  const QuoteFinancialBreakdown({
    required this.subtotal,
    required this.deliveryCost,
    required this.vatRate,
    required this.vatAmount,
    required this.totalInclVat,
  });

  final double subtotal;
  final double deliveryCost;
  final double vatRate;
  final double vatAmount;
  final double totalInclVat;

  static const double defaultVatRate = 17;

  static QuoteFinancialBreakdown compute({
    required double subtotal,
    double deliveryCost = 0,
    double vatRate = defaultVatRate,
  }) {
    final safeSubtotal = subtotal < 0 ? 0.0 : subtotal;
    final safeDelivery = deliveryCost < 0 ? 0.0 : deliveryCost;
    final rate = vatRate < 0 ? 0.0 : vatRate;
    final taxable = safeSubtotal + safeDelivery;
    final vatAmount = (taxable * rate / 100).toDouble();
    return QuoteFinancialBreakdown(
      subtotal: safeSubtotal,
      deliveryCost: safeDelivery,
      vatRate: rate,
      vatAmount: vatAmount,
      totalInclVat: taxable + vatAmount,
    );
  }

  Map<String, dynamic> toFirestoreMap({
    required DateTime validUntil,
    required String paymentTerms,
  }) =>
      {
        'subtotal': subtotal,
        'deliveryCost': deliveryCost,
        'vatRate': vatRate,
        'vatAmount': vatAmount,
        'totalInclVat': totalInclVat,
        'totalPrice': totalInclVat,
        'validUntil': validUntil,
        'paymentTerms': paymentTerms,
      };
}
