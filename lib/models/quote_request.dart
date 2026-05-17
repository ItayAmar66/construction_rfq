import '../utils/firestore_parsing.dart';
import 'quote_request_item.dart';
import 'quote_status.dart';
import 'request_type.dart';

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
    this.requestType = RequestType.regular,
    this.tenderEndTime,
    this.lowestBid,
    this.tenderClosed = false,
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
  final RequestType requestType;
  final DateTime? tenderEndTime;
  final double? lowestBid;
  final bool tenderClosed;

  bool get hasApprovedQuote =>
      approvedQuoteId != null && approvedQuoteId!.isNotEmpty;

  bool get isTender => requestType == RequestType.tender;

  bool get isTenderActive {
    if (!isTender || tenderClosed) return false;
    if (status.isLocked || status == QuoteRequestStatus.cancelled) return false;
    final end = tenderEndTime;
    if (end == null) return true;
    return DateTime.now().isBefore(end);
  }

  bool get isEditable => status.isEditable && status != QuoteRequestStatus.cancelled;

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

    double? parsedLowest;
    final lowestRaw = map['lowestBid'];
    if (lowestRaw != null) {
      final v = FirestoreParsing.parseDouble(lowestRaw);
      if (v > 0) parsedLowest = v;
    }

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
      requestType: RequestTypeExtension.fromFirestore(
        FirestoreParsing.parseNullableString(map['requestType']),
      ),
      tenderEndTime: FirestoreParsing.parseDate(map['tenderEndTime']),
      lowestBid: parsedLowest,
      tenderClosed: FirestoreParsing.parseBool(map['tenderClosed']),
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
      'requestType': requestType.firestoreValue,
      if (tenderEndTime != null) 'tenderEndTime': tenderEndTime,
      if (lowestBid != null) 'lowestBid': lowestBid,
      'tenderClosed': tenderClosed,
      if (approvedQuoteId != null) 'approvedQuoteId': approvedQuoteId,
      if (customerLastSeenStatus != null)
        'customerLastSeenStatus': customerLastSeenStatus,
      'seenBySupplierIds': seenBySupplierIds,
    };
  }
}
