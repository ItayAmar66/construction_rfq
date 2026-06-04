import '../utils/firestore_parsing.dart';
import '../utils/payment_terms.dart';
import '../utils/quote_financials.dart';

/// Saved supplier defaults for new quotes (users.supplierDefaults).
class SupplierQuoteDefaults {
  const SupplierQuoteDefaults({
    this.deliveryTimeHint = '2-3 ימי עסקים',
    this.deliveryCost = 0,
    this.vatRate = QuoteFinancialBreakdown.defaultVatRate,
    this.paymentTerms = PaymentTerms.defaultValue,
    this.validityDays = 14,
  });

  final String deliveryTimeHint;
  final double deliveryCost;
  final double vatRate;
  final String paymentTerms;
  final int validityDays;

  factory SupplierQuoteDefaults.fromMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return const SupplierQuoteDefaults();
    return SupplierQuoteDefaults(
      deliveryTimeHint: FirestoreParsing.parseString(
        map['deliveryTimeHint'],
        defaultValue: '2-3 ימי עסקים',
      ),
      deliveryCost: FirestoreParsing.parseDouble(map['deliveryCost']),
      vatRate: FirestoreParsing.parseDouble(
        map['vatRate'],
        defaultValue: QuoteFinancialBreakdown.defaultVatRate,
      ),
      paymentTerms: FirestoreParsing.parseString(
        map['paymentTerms'],
        defaultValue: PaymentTerms.defaultValue,
      ),
      validityDays: FirestoreParsing.parseInt(map['validityDays'], defaultValue: 14),
    );
  }

  Map<String, dynamic> toMap() => {
        'deliveryTimeHint': deliveryTimeHint,
        'deliveryCost': deliveryCost,
        'vatRate': vatRate,
        'paymentTerms': paymentTerms,
        'validityDays': validityDays,
      };
}
