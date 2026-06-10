import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../config/app_mode.dart';
import '../models/app_user.dart';
import '../models/cart_item.dart';
import '../models/quote_request.dart';
import '../models/quote_request_item.dart';
import '../models/quote_status.dart';
import '../models/request_type.dart';
import '../services/mock_store.dart';
import '../services/quote_persistence_support.dart';
import '../utils/constants.dart';
import '../utils/quote_request_item_resolver.dart';
import '../utils/supplier_quote_status.dart';
import '../utils/supplier_targeting_helpers.dart';

class RequestRepository {
  RequestRepository({FirebaseFirestore? firestore}) : _firestore = firestore;

  final FirebaseFirestore? _firestore;

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
    String supplierId,
  ) {
    if (AppMode.isDemoMode) {
      return MockStore.instance.watchIncomingRequestsForSupplier(supplierId);
    }
    return _db
        .collection(AppConstants.quoteRequestsCollection)
        .where(
          'status',
          whereIn: QuoteRequestStatusExtension.openForSupplierFirestoreValues(),
        )
        .snapshots()
        .map((snapshot) {
      final list = mapQuoteRequests(snapshot)
          .where(
            (r) =>
                SupplierTargetingHelpers.shouldShowToSupplier(
                  request: r,
                  supplierId: supplierId,
                ) &&
                (r.isTenderActive || !r.hasSupplierResponded(supplierId)),
          )
          .toList();
      return list;
    }).handleError(handleQuoteStreamError);
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
  }) async {
    if (AppMode.isDemoMode) {
      return MockStore.instance.submitQuoteRequest(
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
      );
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
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) debugPrint('[Quote] request created: $requestId');
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

  Future<void> sendPendingApprovalToSuppliers({
    required String requestId,
    required String customerId,
  }) async {
    if (AppMode.isDemoMode) {
      return MockStore.instance.sendPendingApprovalToSuppliers(
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
      if (request.customerId != customerId) throw Exception('אין הרשאה');
      if (request.status != QuoteRequestStatus.pendingApproval) {
        throw Exception('הבקשה אינה ממתינה לאישור רכש');
      }

      await ref.update({
        'status': QuoteRequestStatus.sent.firestoreValue,
        'submittedByUid': customerId,
        'customerLastSeenStatus': QuoteRequestStatus.sent.firestoreValue,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      return handleQuoteFutureErrorVoid(
        e,
        fallback: () => MockStore.instance.sendPendingApprovalToSuppliers(
          requestId: requestId,
          customerId: customerId,
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
}
