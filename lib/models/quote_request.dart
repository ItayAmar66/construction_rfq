import '../utils/firestore_parsing.dart';
import 'quote_request_item.dart';
import 'quote_status.dart';
import 'receipt_checklist_item.dart';
import 'receipt_status.dart';
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
    this.invitedSupplierIds = const [],
    this.invitedSupplierNames = const [],
    this.invitedSupplierOrgIds = const [],
    this.projectId,
    this.projectName,
    this.projectLocation,
    this.siteName,
    this.contractorOrgId,
    this.createdByUid,
    this.preparedByUid,
    this.submittedByUid,
    this.shippedAt,
    this.shippedByUid,
    this.shippedBySupplierOrgId,
    this.receiptStatus,
    this.receivedAt,
    this.receivedByUid,
    this.receivedByRole,
    this.receiptNotes,
    this.receiptChecklist = const [],
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
  final List<String> invitedSupplierIds;
  final List<String> invitedSupplierNames;
  final List<String> invitedSupplierOrgIds;
  final String? projectId;
  final String? projectName;
  final String? projectLocation;
  final String? siteName;
  final String? contractorOrgId;
  final String? createdByUid;
  final String? preparedByUid;
  final String? submittedByUid;
  final DateTime? shippedAt;
  final String? shippedByUid;
  final String? shippedBySupplierOrgId;
  final ReceiptStatus? receiptStatus;
  final DateTime? receivedAt;
  final String? receivedByUid;
  final String? receivedByRole;
  final String? receiptNotes;
  final List<ReceiptChecklistItem> receiptChecklist;

  bool get statusAllowsReceiptConfirmation =>
      status == QuoteRequestStatus.pendingReceipt ||
      (status == QuoteRequestStatus.shipped &&
          receiptStatus != ReceiptStatus.receivedFull &&
          receiptStatus != ReceiptStatus.receivedWithIssues);

  bool get receiptConfirmationComplete =>
      receiptStatus == ReceiptStatus.receivedFull ||
      receiptStatus == ReceiptStatus.receivedWithIssues;

  String? get projectDisplayLabel {
    final name = projectName?.trim();
    final loc = (projectLocation ?? siteName)?.trim();
    if (name != null && name.isNotEmpty && loc != null && loc.isNotEmpty) {
      return '$name · $loc';
    }
    if (name != null && name.isNotEmpty) return name;
    if (loc != null && loc.isNotEmpty) return loc;
    return null;
  }

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

  bool get isEditable =>
      status.isEditable && status != QuoteRequestStatus.cancelled;

  bool hasSupplierResponded(String supplierId) =>
      supplierIdsResponded.contains(supplierId);

  bool hasSupplierOrOrgResponded(String supplierId, String? supplierOrgId) {
    final orgId = supplierOrgId?.trim();
    return supplierIdsResponded.contains(supplierId) ||
        (orgId != null &&
            orgId.isNotEmpty &&
            supplierIdsResponded.contains(orgId));
  }

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
      createdAt: FirestoreParsing.parseDate(map['createdAt']) ?? DateTime.now(),
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
      invitedSupplierIds:
          FirestoreParsing.parseStringList(map['invitedSupplierIds']),
      invitedSupplierNames:
          FirestoreParsing.parseStringList(map['invitedSupplierNames']),
      invitedSupplierOrgIds:
          FirestoreParsing.parseStringList(map['invitedSupplierOrgIds']),
      projectId: FirestoreParsing.parseNullableString(map['projectId']),
      projectName: FirestoreParsing.parseNullableString(map['projectName']),
      projectLocation:
          FirestoreParsing.parseNullableString(map['projectLocation']) ??
              FirestoreParsing.parseNullableString(map['siteName']),
      siteName: FirestoreParsing.parseNullableString(map['siteName']),
      contractorOrgId:
          FirestoreParsing.parseNullableString(map['contractorOrgId']),
      createdByUid: FirestoreParsing.parseNullableString(map['createdByUid']),
      preparedByUid: FirestoreParsing.parseNullableString(map['preparedByUid']),
      submittedByUid:
          FirestoreParsing.parseNullableString(map['submittedByUid']),
      shippedAt: FirestoreParsing.parseDate(map['shippedAt']),
      shippedByUid: FirestoreParsing.parseNullableString(map['shippedByUid']) ??
          FirestoreParsing.parseNullableString(map['shippedBySupplierId']),
      shippedBySupplierOrgId:
          FirestoreParsing.parseNullableString(map['shippedBySupplierOrgId']),
      receiptStatus: ReceiptStatusExtension.fromFirestore(
        FirestoreParsing.parseNullableString(map['receiptStatus']),
      ),
      receivedAt: FirestoreParsing.parseDate(map['receivedAt']),
      receivedByUid:
          FirestoreParsing.parseNullableString(map['receivedByUid']),
      receivedByRole:
          FirestoreParsing.parseNullableString(map['receivedByRole']),
      receiptNotes:
          FirestoreParsing.parseNullableString(map['receiptNotes']),
      receiptChecklist: FirestoreParsing.parseEmbeddedItemMaps(
            map['receiptChecklist'],
          )
          .map(ReceiptChecklistItem.fromMap)
          .toList(),
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
      if (invitedSupplierIds.isNotEmpty)
        'invitedSupplierIds': invitedSupplierIds,
      if (invitedSupplierNames.isNotEmpty)
        'invitedSupplierNames': invitedSupplierNames,
      if (invitedSupplierOrgIds.isNotEmpty)
        'invitedSupplierOrgIds': invitedSupplierOrgIds,
      if (projectId != null) 'projectId': projectId,
      if (projectName != null) 'projectName': projectName,
      if (projectLocation != null) 'projectLocation': projectLocation,
      if (siteName != null) 'siteName': siteName,
      if (contractorOrgId != null) 'contractorOrgId': contractorOrgId,
      if (createdByUid != null) 'createdByUid': createdByUid,
      if (preparedByUid != null) 'preparedByUid': preparedByUid,
      if (submittedByUid != null) 'submittedByUid': submittedByUid,
      if (shippedAt != null) 'shippedAt': shippedAt,
      if (shippedByUid != null) 'shippedByUid': shippedByUid,
      if (shippedBySupplierOrgId != null)
        'shippedBySupplierOrgId': shippedBySupplierOrgId,
      if (receiptStatus != null) 'receiptStatus': receiptStatus!.firestoreValue,
      if (receivedAt != null) 'receivedAt': receivedAt,
      if (receivedByUid != null) 'receivedByUid': receivedByUid,
      if (receivedByRole != null) 'receivedByRole': receivedByRole,
      if (receiptNotes != null) 'receiptNotes': receiptNotes,
      if (receiptChecklist.isNotEmpty)
        'receiptChecklist':
            receiptChecklist.map((item) => item.toMap()).toList(),
    };
  }
}
