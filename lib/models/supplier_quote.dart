import '../utils/firestore_parsing.dart';
import '../utils/payment_terms.dart';
import '../utils/quote_financials.dart';
import '../utils/supplier_quote_status.dart';
import 'supplier_quote_item.dart';

class SupplierQuote {
  const SupplierQuote({
    required this.id,
    required this.quoteRequestId,
    required this.supplierId,
    required this.supplierName,
    required this.supplierType,
    required this.deliveryTime,
    this.notes,
    required this.totalPrice,
    required this.status,
    required this.createdAt,
    this.items = const [],
    this.seenByCustomer = false,
    this.seenOrderBySupplier = false,
    this.isTenderBid = false,
    this.bidVersion = 1,
    this.subtotal = 0,
    this.deliveryCost = 0,
    this.vatRate = QuoteFinancialBreakdown.defaultVatRate,
    this.vatAmount = 0,
    this.totalInclVat = 0,
    this.validUntil,
    this.paymentTerms = PaymentTerms.defaultValue,
    this.supplierOrgId,
  });

  final String id;
  final String quoteRequestId;
  final String supplierId;
  final String supplierName;
  final String supplierType;
  final String deliveryTime;
  final String? notes;
  final double totalPrice;
  final String status;
  final DateTime createdAt;
  final List<SupplierQuoteItem> items;
  final bool seenByCustomer;
  final bool seenOrderBySupplier;
  final bool isTenderBid;
  final int bidVersion;
  final double subtotal;
  final double deliveryCost;
  final double vatRate;
  final double vatAmount;
  final double totalInclVat;
  final DateTime? validUntil;
  final String paymentTerms;
  final String? supplierOrgId;

  /// Amount shown to users (new quotes use totalInclVat; legacy uses totalPrice).
  double get displayTotal =>
      totalInclVat > 0 ? totalInclVat : totalPrice;

  double get displaySubtotal {
    if (subtotal > 0) return subtotal;
    if (items.isEmpty) return totalPrice;
    return items.fold<double>(0, (s, i) => s + i.totalItemPrice);
  }

  bool get isUnreadByCustomer => !seenByCustomer;

  bool get isUnreadOrderBySupplier =>
      status == SupplierQuoteStatus.approved && !seenOrderBySupplier;

  bool get isOutdated => status == SupplierQuoteStatus.outdated;

  factory SupplierQuote.fromMap(String id, Map<String, dynamic> map) {
    final requestId = FirestoreParsing.parseString(
      map['requestId'],
      defaultValue: FirestoreParsing.parseString(map['quoteRequestId']),
    );

    final itemMaps = FirestoreParsing.parseEmbeddedItemMaps(map['items']);
    final items = itemMaps
        .asMap()
        .entries
        .map(
          (e) => SupplierQuoteItem.fromEmbedded(
            quoteId: id,
            map: e.value,
            index: e.key,
          ),
        )
        .toList();

    final status = FirestoreParsing.parseString(
      map['status'],
      defaultValue: SupplierQuoteStatus.sent,
    );

    final totalPrice = FirestoreParsing.parseDouble(map['totalPrice']);
    final totalInclVat = FirestoreParsing.parseDouble(map['totalInclVat']);
    final subtotal = FirestoreParsing.parseDouble(map['subtotal']);
    final resolvedInclVat = totalInclVat > 0 ? totalInclVat : totalPrice;

    return SupplierQuote(
      id: id,
      quoteRequestId: requestId,
      supplierId: FirestoreParsing.parseString(map['supplierId']),
      supplierName: FirestoreParsing.parseString(map['supplierName']),
      supplierType: FirestoreParsing.parseString(map['supplierType']),
      deliveryTime: FirestoreParsing.parseString(map['deliveryTime']),
      notes: FirestoreParsing.parseNullableString(map['notes']),
      totalPrice: totalPrice,
      status: status,
      createdAt:
          FirestoreParsing.parseDate(map['createdAt']) ?? DateTime.now(),
      items: items,
      seenByCustomer: FirestoreParsing.parseBool(map['seenByCustomer']),
      seenOrderBySupplier:
          FirestoreParsing.parseBool(map['seenOrderBySupplier']),
      isTenderBid: FirestoreParsing.parseBool(map['isTenderBid']),
      bidVersion: FirestoreParsing.parseInt(map['bidVersion'], defaultValue: 1),
      subtotal: subtotal,
      deliveryCost: FirestoreParsing.parseDouble(map['deliveryCost']),
      vatRate: FirestoreParsing.parseDouble(
        map['vatRate'],
        defaultValue: QuoteFinancialBreakdown.defaultVatRate,
      ),
      vatAmount: FirestoreParsing.parseDouble(map['vatAmount']),
      totalInclVat: resolvedInclVat,
      validUntil: FirestoreParsing.parseDate(map['validUntil']),
      paymentTerms: FirestoreParsing.parseString(
        map['paymentTerms'],
        defaultValue: PaymentTerms.defaultValue,
      ),
      supplierOrgId: FirestoreParsing.parseNullableString(map['supplierOrgId']),
    );
  }

  Map<String, dynamic> toMap() {
    final incl = displayTotal;
    return {
      'requestId': quoteRequestId,
      'quoteRequestId': quoteRequestId,
      'supplierId': supplierId,
      if (supplierOrgId != null && supplierOrgId!.isNotEmpty)
        'supplierOrgId': supplierOrgId,
      'supplierName': supplierName,
      'supplierType': supplierType,
      'deliveryTime': deliveryTime,
      'notes': notes,
      'totalPrice': incl,
      'subtotal': displaySubtotal,
      'deliveryCost': deliveryCost,
      'vatRate': vatRate,
      'vatAmount': vatAmount,
      'totalInclVat': incl,
      if (validUntil != null) 'validUntil': validUntil,
      'paymentTerms': paymentTerms,
      'status': status,
      'createdAt': createdAt,
      'items': items.map((i) => i.toEmbeddedMap()).toList(),
      'seenByCustomer': seenByCustomer,
      'seenOrderBySupplier': seenOrderBySupplier,
      'isTenderBid': isTenderBid,
      'bidVersion': bidVersion,
    };
  }
}
