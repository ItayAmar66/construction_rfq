import '../utils/firestore_parsing.dart';
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

    return SupplierQuote(
      id: id,
      quoteRequestId: requestId,
      supplierId: FirestoreParsing.parseString(map['supplierId']),
      supplierName: FirestoreParsing.parseString(map['supplierName']),
      supplierType: FirestoreParsing.parseString(map['supplierType']),
      deliveryTime: FirestoreParsing.parseString(map['deliveryTime']),
      notes: FirestoreParsing.parseNullableString(map['notes']),
      totalPrice: FirestoreParsing.parseDouble(map['totalPrice']),
      status: status,
      createdAt:
          FirestoreParsing.parseDate(map['createdAt']) ?? DateTime.now(),
      items: items,
      seenByCustomer: FirestoreParsing.parseBool(map['seenByCustomer']),
      seenOrderBySupplier:
          FirestoreParsing.parseBool(map['seenOrderBySupplier']),
      isTenderBid: FirestoreParsing.parseBool(map['isTenderBid']),
      bidVersion: FirestoreParsing.parseInt(map['bidVersion'], defaultValue: 1),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'requestId': quoteRequestId,
      'quoteRequestId': quoteRequestId,
      'supplierId': supplierId,
      'supplierName': supplierName,
      'supplierType': supplierType,
      'deliveryTime': deliveryTime,
      'notes': notes,
      'totalPrice': totalPrice,
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
