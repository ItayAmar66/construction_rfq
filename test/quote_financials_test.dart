import 'package:construction_rfq/utils/quote_financials.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QuoteFinancialBreakdown.compute', () {
    test('default VAT rate is 17%', () {
      expect(QuoteFinancialBreakdown.defaultVatRate, 17);
    });

    test('applies VAT to the subtotal (happy path)', () {
      final b = QuoteFinancialBreakdown.compute(subtotal: 1000);
      expect(b.subtotal, 1000);
      expect(b.deliveryCost, 0);
      expect(b.vatRate, 17);
      expect(b.vatAmount, closeTo(170, 1e-9));
      expect(b.totalInclVat, closeTo(1170, 1e-9));
    });

    test('delivery cost is part of the taxable base', () {
      final b = QuoteFinancialBreakdown.compute(
        subtotal: 1000,
        deliveryCost: 100,
      );
      // VAT charged on 1100, not just 1000.
      expect(b.vatAmount, closeTo(187, 1e-9));
      expect(b.totalInclVat, closeTo(1287, 1e-9));
    });

    test('honours a custom VAT rate', () {
      final b = QuoteFinancialBreakdown.compute(subtotal: 200, vatRate: 10);
      expect(b.vatAmount, closeTo(20, 1e-9));
      expect(b.totalInclVat, closeTo(220, 1e-9));
    });

    test('zero VAT rate yields no tax', () {
      final b = QuoteFinancialBreakdown.compute(
        subtotal: 500,
        deliveryCost: 50,
        vatRate: 0,
      );
      expect(b.vatAmount, 0);
      expect(b.totalInclVat, closeTo(550, 1e-9));
    });

    test('clamps a negative subtotal to zero', () {
      final b = QuoteFinancialBreakdown.compute(subtotal: -100);
      expect(b.subtotal, 0);
      expect(b.vatAmount, 0);
      expect(b.totalInclVat, 0);
    });

    test('clamps a negative delivery cost to zero', () {
      final b = QuoteFinancialBreakdown.compute(
        subtotal: 100,
        deliveryCost: -25,
      );
      expect(b.deliveryCost, 0);
      expect(b.vatAmount, closeTo(17, 1e-9));
      expect(b.totalInclVat, closeTo(117, 1e-9));
    });

    test('clamps a negative VAT rate to zero', () {
      final b = QuoteFinancialBreakdown.compute(subtotal: 100, vatRate: -5);
      expect(b.vatRate, 0);
      expect(b.vatAmount, 0);
      expect(b.totalInclVat, 100);
    });
  });

  group('QuoteFinancialBreakdown.toFirestoreMap', () {
    test('mirrors totalInclVat into the legacy totalPrice field', () {
      final b = QuoteFinancialBreakdown.compute(subtotal: 1000);
      final validUntil = DateTime(2026, 8, 1);
      final map = b.toFirestoreMap(
        validUntil: validUntil,
        paymentTerms: 'net30',
      );
      expect(map['subtotal'], 1000);
      expect(map['vatAmount'], closeTo(170, 1e-9));
      expect(map['totalInclVat'], closeTo(1170, 1e-9));
      // Legacy readers rely on totalPrice mirroring the VAT-inclusive total.
      expect(map['totalPrice'], map['totalInclVat']);
      expect(map['validUntil'], validUntil);
      expect(map['paymentTerms'], 'net30');
    });
  });
}
