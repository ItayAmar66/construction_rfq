import '../utils/firestore_parsing.dart';
import 'quote_request_item.dart';
import 'quote_status.dart';

class QuoteRequest {
  const QuoteRequest({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.customerCity,
    required this.customerType,
    required this.status,
    this.notes,
    required this.createdAt,
    this.updatedAt,
    this.items = const [],
    this.supplierIdsResponded = const [],
    this.approvedQuoteId,
    this.customerLastSeenStatus,
    this.seenBySupplierIds = const [],
  });

  final String id;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String customerCity;
  final String customerType;
  final QuoteRequestStatus status;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<QuoteRequestItem> items;
  final List<String> supplierIdsResponded;
  final String? approvedQuoteId;
  final String? customerLastSeenStatus;
  final List<String> seenBySupplierIds;

  bool get hasApprovedQuote =>
      approvedQuoteId != null && approvedQuoteId!.isNotEmpty;

  bool hasSupplierResponded(String supplierId) =>
      supplierIdsResponded.contains(supplierId);

  bool isUnseenBySupplier(String supplierId) =>
      !seenBySupplierIds.contains(supplierId);

  bool hasUnreadStatusForCustomer() {
    final seen = customerLastSeenStatus;
    if (seen == null || seen.isEmpty) {
      return status != QuoteRequestStatus.sent &&
          status != QuoteRequestStatus.draft;
    }
    return status.firestoreValue != seen;
  }

  DateTime get sortDate => updatedAt ?? createdAt;

  factory QuoteRequest.fromMap(String id, Map<String, dynamic> map) {
    final itemMaps = FirestoreParsing.parseEmbeddedItemMaps(map['items']);
    final items = itemMaps
        .asMap()
        .entries
        .map(
          (e) => QuoteRequestItem.fromEmbedded(
            requestId: id,
            map: e.value,
            index: e.key,
          ),
        )
        .toList();

    return QuoteRequest(
      id: id,
      customerId: FirestoreParsing.parseString(map['customerId']),
      customerName: FirestoreParsing.parseString(map['customerName']),
      customerPhone: FirestoreParsing.parseString(map['customerPhone']),
      customerCity: FirestoreParsing.parseString(map['customerCity']),
      customerType: FirestoreParsing.parseString(map['customerType']),
      status: QuoteRequestStatusExtension.fromFirestore(
        FirestoreParsing.parseNullableString(map['status']),
      ),
      approvedQuoteId:
          FirestoreParsing.parseNullableString(map['approvedQuoteId']),
      notes: FirestoreParsing.parseNullableString(map['notes']),
      createdAt:
          FirestoreParsing.parseDate(map['createdAt']) ?? DateTime.now(),
      updatedAt: FirestoreParsing.parseDate(map['updatedAt']),
      items: items,
      supplierIdsResponded:
          FirestoreParsing.parseStringList(map['supplierIdsResponded']),
      customerLastSeenStatus:
          FirestoreParsing.parseNullableString(map['customerLastSeenStatus']),
      seenBySupplierIds: FirestoreParsing.parseSeenBySupplierIds(map),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerCity': customerCity,
      'customerType': customerType,
      'status': status.value,
      'notes': notes,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'items': items.map((i) => i.toEmbeddedMap()).toList(),
      'supplierIdsResponded': supplierIdsResponded,
      if (approvedQuoteId != null) 'approvedQuoteId': approvedQuoteId,
      if (customerLastSeenStatus != null)
        'customerLastSeenStatus': customerLastSeenStatus,
      'seenBySupplierIds': seenBySupplierIds,
    };
  }
}
