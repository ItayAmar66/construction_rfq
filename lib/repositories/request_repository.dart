import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../config/app_mode.dart';
import '../models/enterprise/audit_event.dart';
import '../models/app_user.dart';
import '../models/cart_item.dart';
import '../models/quote_request.dart';
import '../models/quote_request_item.dart';
import '../models/quote_status.dart';
import '../models/request_type.dart';
import '../services/mock_store.dart';
import '../services/quote_persistence_support.dart';
import '../repositories/audit_repository.dart';
import '../models/enterprise/membership.dart';
import '../utils/constants.dart';
import '../utils/procurement_rfq_access.dart';
import '../utils/quote_request_item_resolver.dart';
import '../utils/supplier_quote_status.dart';
import '../utils/supplier_targeting_helpers.dart';

class RequestRepository {
  RequestRepository({
    FirebaseFirestore? firestore,
    AuditRepository? auditRepository,
  })  : _firestore = firestore,
        _auditRepository = auditRepository ?? AuditRepository(firestore: firestore);

  final FirebaseFirestore? _firestore;
  final AuditRepository _auditRepository;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;
  final _uuid = const Uuid();

  Stream<List<QuoteRequest>> watchCustomerRequests(String customerId) {
    if (AppMode.isDemoMode) {
      return MockStore.instance.watchCustomerRequests(customerId);
    }
    return _db
        .collection(AppConstants.quoteRequestsCollection)
        .where('customerId', isEqualTo: customerId)
        .snapshots()
        .map(mapQuoteRequests)
        .handleError(handleQuoteStreamError);
  }

  Stream<QuoteRequest?> watchQuoteRequest(String requestId) {
    if (AppMode.isDemoMode) {
      return MockStore.instance.watchQuoteRequest(requestId);
    }
    return _db
        .collection(AppConstants.quoteRequestsCollection)
        .doc(requestId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return QuoteRequest.fromMap(doc.id, doc.data()!);
    }).handleError(handleQuoteStreamError);
  }

  /// Open requests this supplier has not yet quoted on.
  Stream<List<QuoteRequest>> watchIncomingRequestsForSupplier(
    String supplierId, {
    String? supplierOrgId,
  }) {
    if (AppMode.isDemoMode) {
      return MockStore.instance.watchIncomingRequestsForSupplier(
        supplierId,
        supplierOrgId: supplierOrgId,
      );
    }

    final openStatuses =
        QuoteRequestStatusExtension.openForSupplierFirestoreValues();
    final collection = _db.collection(AppConstants.quoteRequestsCollection);

    QuerySnapshot<Map<String, dynamic>>? openToAllSnap;
    QuerySnapshot<Map<String, dynamic>>? targetedSnap;
    QuerySnapshot<Map<String, dynamic>>? orgTargetedSnap;
    QuerySnapshot<Map<String, dynamic>>? respondedSnap;

    late StreamController<List<QuoteRequest>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? openSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? targetedSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? orgTargetedSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? respondedSub;
    String? activeSupplierOrgId = supplierOrgId;

    void publish() {
      if (controller.isClosed) return;
      final byId = <String, QuoteRequest>{};
      for (final snap in [openToAllSnap, targetedSnap, orgTargetedSnap, respondedSnap]) {
        if (snap == null) continue;
        for (final doc in snap.docs) {
          byId[doc.id] = QuoteRequest.fromMap(doc.id, doc.data());
        }
      }
      final list = byId.values
          .where(
            (r) =>
                SupplierTargetingHelpers.shouldShowToSupplier(
                  request: r,
                  supplierId: supplierId,
                  supplierOrgId: activeSupplierOrgId,
                ) &&
                (r.isTenderActive || !r.hasSupplierResponded(supplierId)),
          )
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      controller.add(list);
    }

    void onQueryError(Object error, StackTrace stackTrace) {
      if (isFirestorePermissionDenied(error)) {
        if (kDebugMode) {
          debugPrint('[Quote] incoming query permission-denied — partial data');
        }
        publish();
        return;
      }
      handleQuoteStreamError(error, stackTrace);
    }

    controller = StreamController<List<QuoteRequest>>(
      onListen: () async {
        activeSupplierOrgId =
            supplierOrgId ?? await _resolveSupplierOrgId(supplierId);

        openSub = collection
            .where('status', whereIn: openStatuses)
            .where('openToAllSuppliers', isEqualTo: true)
            .snapshots()
            .listen(
              (snap) {
                openToAllSnap = snap;
                publish();
              },
              onError: onQueryError,
            );
        targetedSub = collection
            .where('status', whereIn: openStatuses)
            .where('invitedSupplierIds', arrayContains: supplierId)
            .snapshots()
            .listen(
              (snap) {
                targetedSnap = snap;
                publish();
              },
              onError: onQueryError,
            );
        if (activeSupplierOrgId != null && activeSupplierOrgId!.isNotEmpty) {
          orgTargetedSub = collection
              .where('status', whereIn: openStatuses)
              .where('invitedSupplierOrgIds', arrayContains: activeSupplierOrgId)
              .snapshots()
              .listen(
                (snap) {
                  orgTargetedSnap = snap;
                  publish();
                },
                onError: onQueryError,
              );
        }
        respondedSub = collection
            .where('supplierIdsResponded', arrayContains: supplierId)
            .snapshots()
            .listen(
              (snap) {
                respondedSnap = snap;
                publish();
              },
              onError: onQueryError,
            );
      },
      onCancel: () async {
        await openSub?.cancel();
        await targetedSub?.cancel();
        await orgTargetedSub?.cancel();
        await respondedSub?.cancel();
      },
    );

    return controller.stream;
  }

  Future<String?> _resolveSupplierOrgId(String supplierId) async {
    if (supplierId.isEmpty) return null;
    try {
      final snap = await _db
          .collectionGroup(AppConstants.membershipsSubcollection)
          .where('uid', isEqualTo: supplierId)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      final orgId = snap.docs.first.data()['orgId'];
      return orgId is String && orgId.isNotEmpty ? orgId : null;
    } catch (e) {
      if (kDebugMode) debugPrint('[Quote] resolve supplier org: $e');
      return null;
    }
  }

  Future<List<QuoteRequestItem>> getRequestItems(String requestId) async {
    if (AppMode.isDemoMode) {
      return MockStore.instance.getRequestItems(requestId);
    }

    try {
      final doc = await _db
          .collection(AppConstants.quoteRequestsCollection)
          .doc(requestId)
          .get();
      if (!doc.exists) return [];

      final request = QuoteRequest.fromMap(doc.id, doc.data()!);
      if (request.items.isNotEmpty) return request.items;

      return _loadLegacyRequestItems(requestId);
    } catch (e) {
      return handleQuoteFutureError(
        e,
        fallback: () => MockStore.instance.getRequestItems(requestId),
      );
    }
  }

  Future<String> submitQuoteRequest({
    required AppUser customer,
    List<CartItem>? items,
    List<QuoteRequestItem>? requestItems,
    String? notes,
    RequestType requestType = RequestType.regular,
    Duration tenderDuration = const Duration(hours: 24),
    List<String> invitedSupplierIds = const [],
    List<String> invitedSupplierNames = const [],
    List<String> invitedSupplierOrgIds = const [],
    QuoteRequestStatus submitStatus = QuoteRequestStatus.sent,
    String? projectId,
    String? projectName,
    String? projectLocation,
    String? siteName,
    String? contractorOrgId,
  }) async {
    if (AppMode.isDemoMode) {
      final requestId = await MockStore.instance.submitQuoteRequest(
        customer: customer,
        items: items,
        requestItems: requestItems,
        notes: notes,
        requestType: requestType,
        tenderDuration: tenderDuration,
        invitedSupplierIds: invitedSupplierIds,
        invitedSupplierNames: invitedSupplierNames,
        invitedSupplierOrgIds: invitedSupplierOrgIds,
        submitStatus: submitStatus,
        projectId: projectId,
        projectName: projectName,
        projectLocation: projectLocation,
        siteName: siteName,
        contractorOrgId: contractorOrgId,
      );
      if (submitStatus == QuoteRequestStatus.sent) {
        await _auditRfqSent(
          actorUid: customer.id,
          requestId: requestId,
          projectId: projectId,
          projectName: projectName,
        );
      }
      return requestId;
    }

    final resolvedItems = resolveQuoteRequestItems(
      requestItems: requestItems,
      cartItems: items,
      uuid: _uuid,
    );
    if (resolvedItems.isEmpty) throw Exception('אין מוצרים בבקשה');

    try {
      final requestId = _uuid.v4();
      final persistedItems = resolvedItems
          .map(
            (item) => cloneQuoteRequestItemForPersist(
              item,
              requestId: requestId,
              lineId: item.id.isNotEmpty ? item.id : _uuid.v4(),
            ),
          )
          .toList();

      final isTender = requestType == RequestType.tender;
      await _db
          .collection(AppConstants.quoteRequestsCollection)
          .doc(requestId)
          .set({
        'customerId': customer.id,
        'customerName': customer.fullName,
        'customerPhone': customer.phone,
        'customerCity': customer.city,
        'customerType': customer.userType.value,
        'status': submitStatus.firestoreValue,
        'notes': notes,
        'createdByUid': customer.id,
        'preparedByUid': customer.id,
        if (submitStatus == QuoteRequestStatus.sent)
          'submittedByUid': customer.id,
        'items': persistedItems.map((i) => i.toEmbeddedMap()).toList(),
        'supplierIdsResponded': <String>[],
        'seenBySupplierIds': <String>[],
        'customerLastSeenStatus': submitStatus.firestoreValue,
        'requestType': requestType.firestoreValue,
        if (isTender)
          'tenderEndTime': Timestamp.fromDate(
            DateTime.now().add(tenderDuration),
          ),
        'tenderClosed': false,
        'openToAllSuppliers': invitedSupplierIds.isEmpty &&
            invitedSupplierNames.isEmpty &&
            invitedSupplierOrgIds.isEmpty,
        if (invitedSupplierIds.isNotEmpty)
          'invitedSupplierIds': invitedSupplierIds,
        if (invitedSupplierNames.isNotEmpty)
          'invitedSupplierNames': invitedSupplierNames,
        if (invitedSupplierOrgIds.isNotEmpty)
          'invitedSupplierOrgIds': invitedSupplierOrgIds,
        if (projectId != null && projectId.isNotEmpty) 'projectId': projectId,
        if (projectName != null && projectName.isNotEmpty)
          'projectName': projectName,
        if (projectLocation != null && projectLocation.isNotEmpty)
          'projectLocation': projectLocation,
        if (siteName != null && siteName.isNotEmpty) 'siteName': siteName,
        if (contractorOrgId != null && contractorOrgId.isNotEmpty)
          'contractorOrgId': contractorOrgId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) debugPrint('[Quote] request created: $requestId');
      if (submitStatus == QuoteRequestStatus.sent) {
        await _auditRfqSent(
          actorUid: customer.id,
          requestId: requestId,
          projectId: projectId,
          projectName: projectName,
        );
      }
      return requestId;
    } catch (e) {
      return handleQuoteFutureError(
        e,
        fallback: () => MockStore.instance.submitQuoteRequest(
          customer: customer,
          items: items,
          requestItems: requestItems,
          notes: notes,
          requestType: requestType,
          tenderDuration: tenderDuration,
          invitedSupplierIds: invitedSupplierIds,
          invitedSupplierNames: invitedSupplierNames,
          invitedSupplierOrgIds: invitedSupplierOrgIds,
          submitStatus: submitStatus,
          projectId: projectId,
          projectName: projectName,
          projectLocation: projectLocation,
          siteName: siteName,
        ),
      );
    }
  }

  Stream<List<QuoteRequest>> watchOrgPendingProcurement(String orgId) {
    if (orgId.isEmpty) return Stream.value(const []);
    if (AppMode.isDemoMode) {
      return MockStore.instance.watchOrgPendingProcurement(orgId);
    }
    return _db
        .collection(AppConstants.quoteRequestsCollection)
        .where('contractorOrgId', isEqualTo: orgId)
        .where(
          'status',
          whereIn: [
            QuoteRequestStatus.pendingApproval.firestoreValue,
            QuoteRequestStatus.procurementApproved.firestoreValue,
          ],
        )
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => QuoteRequest.fromMap(d.id, d.data()))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)))
        .handleError((_) => <QuoteRequest>[]);
  }

  Future<void> approveProcurementRequest({
    required String requestId,
    required String actorUid,
    String? orgId,
  }) async {
    if (AppMode.isDemoMode) {
      return MockStore.instance.approveProcurementRequest(
        requestId: requestId,
        actorUid: actorUid,
      );
    }
    try {
      final ref =
          _db.collection(AppConstants.quoteRequestsCollection).doc(requestId);
      final snap = await ref.get();
      if (!snap.exists) throw Exception('הבקשה לא נמצאה');
      final request = QuoteRequest.fromMap(snap.id, snap.data()!);
      if (request.status != QuoteRequestStatus.pendingApproval) {
        throw Exception('הבקשה אינה ממתינה לאישור רכש');
      }
      if (orgId != null &&
          request.contractorOrgId != null &&
          request.contractorOrgId != orgId) {
        throw Exception('אין הרשאה לאשר בקשה זו');
      }
      await ref.update({
        'status': QuoteRequestStatus.procurementApproved.firestoreValue,
        'procurementApprovedByUid': actorUid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _auditProcurementAction(
        actorUid: actorUid,
        requestId: requestId,
        action: AuditAction.procurementApprovedRfq,
        summary: 'רכש אישר בקשת חומרים',
        orgId: request.contractorOrgId,
        projectId: request.projectId,
      );
    } catch (e) {
      return handleQuoteFutureErrorVoid(
        e,
        fallback: () => MockStore.instance.approveProcurementRequest(
          requestId: requestId,
          actorUid: actorUid,
        ),
      );
    }
  }

  Future<void> rejectProcurementRequest({
    required String requestId,
    required String actorUid,
    String? note,
    String? orgId,
  }) async {
    if (AppMode.isDemoMode) {
      return MockStore.instance.rejectProcurementRequest(
        requestId: requestId,
        actorUid: actorUid,
        note: note,
      );
    }
    try {
      final ref =
          _db.collection(AppConstants.quoteRequestsCollection).doc(requestId);
      final snap = await ref.get();
      if (!snap.exists) throw Exception('הבקשה לא נמצאה');
      final request = QuoteRequest.fromMap(snap.id, snap.data()!);
      if (request.status != QuoteRequestStatus.pendingApproval) {
        throw Exception('הבקשה אינה ממתינה לאישור רכש');
      }
      if (orgId != null &&
          request.contractorOrgId != null &&
          request.contractorOrgId != orgId) {
        throw Exception('אין הרשאה לדחות בקשה זו');
      }
      await ref.update({
        'status': QuoteRequestStatus.procurementRejected.firestoreValue,
        if (note != null && note.isNotEmpty) 'procurementRejectionNote': note,
        'procurementRejectedByUid': actorUid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _auditProcurementAction(
        actorUid: actorUid,
        requestId: requestId,
        action: AuditAction.procurementRejectedRfq,
        summary: 'רכש דחה בקשת חומרים',
        orgId: request.contractorOrgId,
        projectId: request.projectId,
      );
    } catch (e) {
      return handleQuoteFutureErrorVoid(
        e,
        fallback: () => MockStore.instance.rejectProcurementRequest(
          requestId: requestId,
          actorUid: actorUid,
          note: note,
        ),
      );
    }
  }

  Future<void> sendPendingApprovalToSuppliers({
    required String requestId,
    required String actorUid,
    List<Membership> memberships = const [],
    String? orgId,
    List<String> invitedSupplierIds = const [],
    List<String> invitedSupplierNames = const [],
    List<String> invitedSupplierOrgIds = const [],
  }) async {
    if (AppMode.isDemoMode) {
      return MockStore.instance.sendPendingApprovalToSuppliers(
        requestId: requestId,
        actorUid: actorUid,
        memberships: memberships,
        orgId: orgId,
        invitedSupplierIds: invitedSupplierIds,
        invitedSupplierNames: invitedSupplierNames,
        invitedSupplierOrgIds: invitedSupplierOrgIds,
      );
    }

    try {
      final ref =
          _db.collection(AppConstants.quoteRequestsCollection).doc(requestId);
      final snap = await ref.get();
      if (!snap.exists) throw Exception('הבקשה לא נמצאה');
      final request = QuoteRequest.fromMap(snap.id, snap.data()!);
      if (!ProcurementRfqAccess.canSendApprovedToSuppliers(
        actorUid: actorUid,
        request: request,
        memberships: memberships,
        orgId: orgId,
      )) {
        throw Exception('אין הרשאה');
      }
      if (request.status != QuoteRequestStatus.procurementApproved) {
        throw Exception('יש לאשר את הבקשה ברכש לפני שליחה לספקים');
      }

      final update = <String, dynamic>{
        'status': QuoteRequestStatus.sent.firestoreValue,
        'submittedByUid': actorUid,
        'customerLastSeenStatus': QuoteRequestStatus.sent.firestoreValue,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (invitedSupplierIds.isNotEmpty) {
        update['invitedSupplierIds'] = invitedSupplierIds;
      }
      if (invitedSupplierNames.isNotEmpty) {
        update['invitedSupplierNames'] = invitedSupplierNames;
      }
      if (invitedSupplierOrgIds.isNotEmpty) {
        update['invitedSupplierOrgIds'] = invitedSupplierOrgIds;
      }
      if (invitedSupplierIds.isEmpty &&
          invitedSupplierNames.isEmpty &&
          invitedSupplierOrgIds.isEmpty) {
        update['openToAllSuppliers'] = true;
      }

      await ref.update(update);
      await _auditRfqSent(
        actorUid: actorUid,
        requestId: requestId,
        projectId: request.projectId,
        projectName: request.projectName,
      );
    } catch (e) {
      return handleQuoteFutureErrorVoid(
        e,
        fallback: () => MockStore.instance.sendPendingApprovalToSuppliers(
          requestId: requestId,
          actorUid: actorUid,
          memberships: memberships,
          orgId: orgId,
          invitedSupplierIds: invitedSupplierIds,
          invitedSupplierNames: invitedSupplierNames,
          invitedSupplierOrgIds: invitedSupplierOrgIds,
        ),
      );
    }
  }

  Future<void> updateQuoteRequest({
    required String requestId,
    required String customerId,
    required List<QuoteRequestItem> items,
    String? notes,
  }) async {
    if (AppMode.isDemoMode) {
      return MockStore.instance.updateQuoteRequest(
        requestId: requestId,
        customerId: customerId,
        items: items,
        notes: notes,
      );
    }

    try {
      final ref =
          _db.collection(AppConstants.quoteRequestsCollection).doc(requestId);
      final snap = await ref.get();
      if (!snap.exists) throw Exception('הבקשה לא נמצאה');
      final request = QuoteRequest.fromMap(snap.id, snap.data()!);
      if (request.customerId != customerId) {
        throw Exception('אין הרשאה לערוך בקשה זו');
      }
      if (!request.isEditable) {
        throw Exception('לא ניתן לערוך בקשה בסטטוס זה');
      }
      if (items.isEmpty) {
        throw Exception('יש להשאיר לפחות מוצר אחד בבקשה');
      }

      await ref.update({
        'items': items.map((i) => i.toEmbeddedMap()).toList(),
        'notes': notes,
        'supplierIdsResponded': <String>[],
        'seenBySupplierIds': <String>[],
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _markSupplierQuotesOutdated(requestId);
    } catch (e) {
      return handleQuoteFutureErrorVoid(
        e,
        fallback: () => MockStore.instance.updateQuoteRequest(
          requestId: requestId,
          customerId: customerId,
          items: items,
          notes: notes,
        ),
      );
    }
  }

  Future<void> deleteOrCancelQuoteRequest({
    required String requestId,
    required String customerId,
  }) async {
    if (AppMode.isDemoMode) {
      return MockStore.instance.deleteOrCancelQuoteRequest(
        requestId: requestId,
        customerId: customerId,
      );
    }

    try {
      final ref =
          _db.collection(AppConstants.quoteRequestsCollection).doc(requestId);
      final snap = await ref.get();
      if (!snap.exists) throw Exception('הבקשה לא נמצאה');
      final request = QuoteRequest.fromMap(snap.id, snap.data()!);
      if (request.customerId != customerId) {
        throw Exception('אין הרשאה למחוק בקשה זו');
      }

      final quotesSnap = await _db
          .collection(AppConstants.supplierQuotesCollection)
          .where('requestId', isEqualTo: requestId)
          .get();

      if (quotesSnap.docs.isEmpty) {
        await ref.delete();
        return;
      }

      await ref.update({
        'status': QuoteRequestStatus.cancelled.firestoreValue,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      return handleQuoteFutureErrorVoid(
        e,
        fallback: () => MockStore.instance.deleteOrCancelQuoteRequest(
          requestId: requestId,
          customerId: customerId,
        ),
      );
    }
  }

  Future<QuoteRequest?> getRequest(String id) async {
    if (AppMode.isDemoMode) return MockStore.instance.getRequest(id);

    try {
      final doc = await _db
          .collection(AppConstants.quoteRequestsCollection)
          .doc(id)
          .get();
      if (!doc.exists) return null;
      return QuoteRequest.fromMap(doc.id, doc.data()!);
    } catch (e) {
      return handleQuoteFutureError(
        e,
        fallback: () => MockStore.instance.getRequest(id),
      );
    }
  }

  Future<List<QuoteRequestItem>> _loadLegacyRequestItems(
    String requestId,
  ) async {
    final snapshot = await _db
        .collection(AppConstants.quoteRequestItemsCollection)
        .where('quoteRequestId', isEqualTo: requestId)
        .get();
    return snapshot.docs
        .map((d) => QuoteRequestItem.fromMap(d.id, d.data()))
        .toList();
  }

  Future<void> _markSupplierQuotesOutdated(String requestId) async {
    final snapshot = await _db
        .collection(AppConstants.supplierQuotesCollection)
        .where('requestId', isEqualTo: requestId)
        .get();
    final batch = _db.batch();
    var writes = 0;
    for (final doc in snapshot.docs) {
      final status = doc.data()['status'] as String? ?? '';
      if (status == SupplierQuoteStatus.sent ||
          status == SupplierQuoteStatus.approved) {
        batch.update(doc.reference, {'status': SupplierQuoteStatus.outdated});
        writes++;
      }
    }
    if (writes > 0) await batch.commit();
  }

  Future<void> _auditProcurementAction({
    required String actorUid,
    required String requestId,
    required String action,
    required String summary,
    String? orgId,
    String? projectId,
  }) async {
    try {
      await AuditLogger.record(
        repository: _auditRepository,
        actorUid: actorUid,
        orgId: orgId,
        projectId: projectId,
        entityType: AuditEntityType.rfq,
        entityId: requestId,
        action: action,
        summaryHebrew: summary,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[RequestRepo] audit failed: $e');
    }
  }

  Future<void> _auditRfqSent({
    required String actorUid,
    required String requestId,
    String? projectId,
    String? projectName,
  }) async {
    await AuditLogger.record(
      repository: _auditRepository,
      actorUid: actorUid,
      projectId: projectId,
      entityType: AuditEntityType.rfq,
      entityId: requestId,
      action: AuditAction.rfqSent,
      summaryHebrew: projectName?.isNotEmpty == true
          ? 'נשלחה בקשה לספקים — $projectName'
          : 'נשלחה בקשה לספקים',
    );
  }
}
