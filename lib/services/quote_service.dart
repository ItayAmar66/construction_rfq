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
import '../models/supplier_quote.dart';
import '../models/supplier_quote_item.dart';
import '../utils/constants.dart';
import '../utils/firestore_parsing.dart';
import '../utils/supplier_quote_status.dart';
import 'mock_store.dart';

class QuoteService {
  QuoteService({FirebaseFirestore? firestore}) : _firestore = firestore;

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
        .map(_mapQuoteRequests)
        .handleError(_handleStreamError);
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
    }).handleError(_handleStreamError);
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
      final list = _mapQuoteRequests(snapshot)
          .where(
            (r) => r.isTenderActive || !r.hasSupplierResponded(supplierId),
          )
          .toList();
      return list;
    }).handleError(_handleStreamError);
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
      return _handleFutureError(
        e,
        fallback: () => MockStore.instance.getRequestItems(requestId),
      );
    }
  }

  Future<List<QuoteRequestItem>> _loadLegacyRequestItems(
      String requestId) async {
    final snapshot = await _db
        .collection(AppConstants.quoteRequestItemsCollection)
        .where('quoteRequestId', isEqualTo: requestId)
        .get();
    return snapshot.docs
        .map((d) => QuoteRequestItem.fromMap(d.id, d.data()))
        .toList();
  }

  Future<String> submitQuoteRequest({
    required AppUser customer,
    required List<CartItem> items,
    String? notes,
    RequestType requestType = RequestType.regular,
    Duration tenderDuration = const Duration(hours: 24),
  }) async {
    if (AppMode.isDemoMode) {
      return MockStore.instance.submitQuoteRequest(
        customer: customer,
        items: items,
        notes: notes,
        requestType: requestType,
        tenderDuration: tenderDuration,
      );
    }

    if (items.isEmpty) throw Exception('אין מוצרים בבקשה');

    try {
      final requestId = _uuid.v4();
      final requestItems = items
          .map(
            (item) => QuoteRequestItem(
              id: _uuid.v4(),
              quoteRequestId: requestId,
              productId: item.product.id,
              productName: item.product.name,
              category: item.product.category,
              unitType: item.product.unitType,
              quantity: item.quantity,
              notes: item.notes,
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
        'status': QuoteRequestStatus.sent.firestoreValue,
        'notes': notes,
        'items': requestItems.map((i) => i.toEmbeddedMap()).toList(),
        'supplierIdsResponded': <String>[],
        'seenBySupplierIds': <String>[],
        'customerLastSeenStatus': QuoteRequestStatus.sent.firestoreValue,
        'requestType': requestType.firestoreValue,
        if (isTender)
          'tenderEndTime': Timestamp.fromDate(
            DateTime.now().add(tenderDuration),
          ),
        'tenderClosed': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) debugPrint('[Quote] request created: $requestId');
      return requestId;
    } catch (e) {
      return _handleFutureError(
        e,
        fallback: () => MockStore.instance.submitQuoteRequest(
          customer: customer,
          items: items,
          notes: notes,
          requestType: requestType,
          tenderDuration: tenderDuration,
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
      return _handleFutureErrorVoid(
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
      return _handleFutureErrorVoid(
        e,
        fallback: () => MockStore.instance.deleteOrCancelQuoteRequest(
          requestId: requestId,
          customerId: customerId,
        ),
      );
    }
  }

  Future<void> closeTender({
    required String requestId,
    required String customerId,
  }) async {
    if (AppMode.isDemoMode) {
      return MockStore.instance.closeTender(
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
      if (!request.isTender) throw Exception('בקשה זו אינה מכרז');

      await ref.update({
        'tenderClosed': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      return _handleFutureErrorVoid(
        e,
        fallback: () => MockStore.instance.closeTender(
          requestId: requestId,
          customerId: customerId,
        ),
      );
    }
  }

  Future<String> submitTenderCounterBid({
    required AppUser supplier,
    required String quoteRequestId,
    required String deliveryTime,
    String? notes,
    required List<SupplierQuoteLineInput> lines,
  }) async {
    if (AppMode.isDemoMode) {
      return MockStore.instance.submitTenderCounterBid(
        supplier: supplier,
        quoteRequestId: quoteRequestId,
        deliveryTime: deliveryTime,
        notes: notes,
        lines: lines,
      );
    }

    final pricedLines = lines.where((l) => l.includeInQuote).toList();
    if (pricedLines.isEmpty) {
      throw Exception('יש לבחור לפחות מוצר אחד עם מחיר');
    }

    try {
      final requestRef = _db
          .collection(AppConstants.quoteRequestsCollection)
          .doc(quoteRequestId);
      final requestSnap = await requestRef.get();
      if (!requestSnap.exists) throw Exception('הבקשה לא נמצאה');
      final request = QuoteRequest.fromMap(requestSnap.id, requestSnap.data()!);
      if (!request.isTender || !request.isTenderActive) {
        throw Exception('המכרז אינו פעיל');
      }

      final total = pricedLines.fold<double>(
        0,
        (runningTotal, l) => runningTotal + l.totalItemPrice,
      );
      final quoteId = _uuid.v4();

      final prevBids = await _db
          .collection(AppConstants.supplierQuotesCollection)
          .where('requestId', isEqualTo: quoteRequestId)
          .where('supplierId', isEqualTo: supplier.id)
          .get();
      final requestQuotes = await _db
          .collection(AppConstants.supplierQuotesCollection)
          .where('requestId', isEqualTo: quoteRequestId)
          .get();

      var bidVersion = 1;
      for (final doc in prevBids.docs) {
        final v = FirestoreParsing.parseInt(doc.data()['bidVersion'],
            defaultValue: 1);
        if (v >= bidVersion) bidVersion = v + 1;
        if (doc.data()['status'] == SupplierQuoteStatus.sent) {
          await doc.reference.update({'status': SupplierQuoteStatus.outdated});
        }
      }

      final batch = _db.batch();
      final quoteRef =
          _db.collection(AppConstants.supplierQuotesCollection).doc(quoteId);

      batch.set(quoteRef, {
        'requestId': quoteRequestId,
        'quoteRequestId': quoteRequestId,
        'customerId': request.customerId,
        'supplierId': supplier.id,
        'supplierName': supplier.fullName,
        'supplierType': supplier.userType.value,
        'deliveryTime': deliveryTime,
        'notes': notes,
        'totalPrice': total,
        'status': SupplierQuoteStatus.sent,
        'seenByCustomer': false,
        'seenOrderBySupplier': false,
        'isTenderBid': true,
        'bidVersion': bidVersion,
        'items': pricedLines
            .map((line) => {
                  'productId': line.productId,
                  'productName': line.productName,
                  'requestedQuantity': line.requestedQuantity,
                  'unitPrice': line.unitPrice,
                  'totalItemPrice': line.totalItemPrice,
                  if (line.notes != null) 'notes': line.notes,
                })
            .toList(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      final updateRequest = <String, dynamic>{
        'status': QuoteRequestStatus.quotesReceived.firestoreValue,
        'supplierIdsResponded': FieldValue.arrayUnion([supplier.id]),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      final activeTotals = <double>[total];
      for (final doc in requestQuotes.docs) {
        final quote = SupplierQuote.fromMap(doc.id, doc.data());
        if (quote.supplierId == supplier.id) continue;
        if (quote.status == SupplierQuoteStatus.sent) {
          activeTotals.add(quote.totalPrice);
        }
      }
      activeTotals.sort();
      updateRequest['lowestBid'] = activeTotals.first;
      batch.update(requestRef, updateRequest);

      await batch.commit();
      return quoteId;
    } catch (e) {
      return _handleFutureError(
        e,
        fallback: () => MockStore.instance.submitTenderCounterBid(
          supplier: supplier,
          quoteRequestId: quoteRequestId,
          deliveryTime: deliveryTime,
          notes: notes,
          lines: lines,
        ),
      );
    }
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

  Stream<List<SupplierQuote>> watchQuotesForRequest(String requestId) {
    if (AppMode.isDemoMode) {
      return MockStore.instance.watchQuotesForRequest(requestId);
    }
    return _db
        .collection(AppConstants.supplierQuotesCollection)
        .where('requestId', isEqualTo: requestId)
        .snapshots()
        .map(
          (snapshot) => _mapSupplierQuotesByDate(snapshot)
              .where((q) => SupplierQuoteStatus.isVisibleToCustomer(q.status))
              .toList(),
        )
        .handleError(_handleStreamError);
  }

  /// Real-time quotes for a customer — listens to both collections without
  /// cancelling the quotes listener when requests change.
  Stream<List<SupplierQuote>> watchCustomerReceivedQuotes(String customerId) {
    if (AppMode.isDemoMode) {
      return MockStore.instance.watchCustomerReceivedQuotes(customerId);
    }

    return _db
        .collection(AppConstants.supplierQuotesCollection)
        .where('customerId', isEqualTo: customerId)
        .snapshots()
        .map(
          (snapshot) => _mapSupplierQuotesByDate(snapshot)
              .where((q) => SupplierQuoteStatus.isVisibleToCustomer(q.status))
              .toList(),
        )
        .handleError(_handleStreamError);
  }

  Stream<SupplierQuote?> watchSupplierQuote(String quoteId) {
    if (AppMode.isDemoMode) {
      return MockStore.instance.watchSupplierQuote(quoteId);
    }
    return _db
        .collection(AppConstants.supplierQuotesCollection)
        .doc(quoteId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return SupplierQuote.fromMap(doc.id, doc.data()!);
    }).handleError(_handleStreamError);
  }

  /// Quotes the supplier sent, excluding orders that moved to fulfillment.
  Stream<List<SupplierQuote>> watchSupplierSentQuotes(String supplierId) {
    if (AppMode.isDemoMode) {
      return MockStore.instance.watchSupplierSentQuotes(supplierId);
    }
    return _db
        .collection(AppConstants.supplierQuotesCollection)
        .where('supplierId', isEqualTo: supplierId)
        .snapshots()
        .map((snapshot) {
      final list = _mapSupplierQuotesByDate(snapshot)
          .where(_isSentQuoteHistoryStatus)
          .toList();
      return list;
    }).handleError(_handleStreamError);
  }

  Stream<List<SupplierQuote>> watchSupplierOrdersToFulfill(String supplierId) {
    if (AppMode.isDemoMode) {
      return MockStore.instance.watchSupplierOrdersToFulfill(supplierId);
    }
    return _db
        .collection(AppConstants.supplierQuotesCollection)
        .where('supplierId', isEqualTo: supplierId)
        .where('status', isEqualTo: SupplierQuoteStatus.approved)
        .snapshots()
        .map(_mapSupplierQuotesByDate)
        .handleError(_handleStreamError);
  }

  Stream<List<SupplierQuote>> watchSupplierOrderHistory(String supplierId) {
    if (AppMode.isDemoMode) {
      return MockStore.instance.watchSupplierOrderHistory(supplierId);
    }
    return _db
        .collection(AppConstants.supplierQuotesCollection)
        .where('supplierId', isEqualTo: supplierId)
        .where(
          'status',
          whereIn: [SupplierQuoteStatus.shipped],
        )
        .snapshots()
        .map(_mapSupplierQuotesByDate)
        .handleError(_handleStreamError);
  }

  Future<void> approveCustomerQuote({
    required String quoteId,
    required String requestId,
    required String customerId,
  }) async {
    if (AppMode.isDemoMode) {
      return MockStore.instance.approveCustomerQuote(
        quoteId: quoteId,
        requestId: requestId,
        customerId: customerId,
      );
    }

    try {
      final requestRef =
          _db.collection(AppConstants.quoteRequestsCollection).doc(requestId);
      final quoteRef =
          _db.collection(AppConstants.supplierQuotesCollection).doc(quoteId);

      await _db.runTransaction((transaction) async {
        final requestSnap = await transaction.get(requestRef);
        if (!requestSnap.exists) {
          throw Exception('הבקשה לא נמצאה');
        }
        final request =
            QuoteRequest.fromMap(requestSnap.id, requestSnap.data()!);
        if (request.customerId != customerId) {
          throw Exception('אין הרשאה לאשר הצעה זו');
        }
        if (request.hasApprovedQuote && request.approvedQuoteId != quoteId) {
          throw Exception('כבר אושרה הצעה אחרת לבקשה זו');
        }

        final quoteSnap = await transaction.get(quoteRef);
        if (!quoteSnap.exists) {
          throw Exception('ההצעה לא נמצאה');
        }
        final quote = SupplierQuote.fromMap(quoteSnap.id, quoteSnap.data()!);
        if (quote.quoteRequestId != request.id) {
          throw Exception('ההצעה אינה שייכת לבקשה זו');
        }
        if (request.status.isLocked &&
            !(request.status == QuoteRequestStatus.ordered &&
                request.approvedQuoteId == quoteId)) {
          throw Exception('לא ניתן לאשר הצעה לבקשה בסטטוס זה');
        }
        if (quote.status != SupplierQuoteStatus.sent &&
            quote.status != SupplierQuoteStatus.approved) {
          throw Exception('לא ניתן לאשר הצעה בסטטוס זה');
        }

        transaction.update(quoteRef, {
          'status': SupplierQuoteStatus.approved,
          'seenOrderBySupplier': false,
        });
        transaction.update(requestRef, {
          'status': QuoteRequestStatus.ordered.firestoreValue,
          'approvedQuoteId': quoteId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      await _markOtherQuotesNotSelected(requestId, quoteId);
    } catch (e) {
      return _handleFutureErrorVoid(
        e,
        fallback: () => MockStore.instance.approveCustomerQuote(
          quoteId: quoteId,
          requestId: requestId,
          customerId: customerId,
        ),
      );
    }
  }

  Future<void> rejectCustomerQuote({
    required String quoteId,
    required String customerId,
    required String requestId,
  }) async {
    if (AppMode.isDemoMode) {
      return MockStore.instance.rejectCustomerQuote(
        quoteId: quoteId,
        customerId: customerId,
        requestId: requestId,
      );
    }

    try {
      final requestRef =
          _db.collection(AppConstants.quoteRequestsCollection).doc(requestId);
      final quoteRef =
          _db.collection(AppConstants.supplierQuotesCollection).doc(quoteId);

      final requestSnap = await requestRef.get();
      if (!requestSnap.exists) throw Exception('הבקשה לא נמצאה');
      final request = QuoteRequest.fromMap(requestSnap.id, requestSnap.data()!);
      if (request.customerId != customerId) {
        throw Exception('אין הרשאה לדחות הצעה זו');
      }
      if (request.hasApprovedQuote) {
        throw Exception('לא ניתן לדחות לאחר שאושרה הצעה');
      }
      if (request.status.isLocked ||
          request.status == QuoteRequestStatus.closed) {
        throw Exception('לא ניתן לדחות הצעה לבקשה בסטטוס זה');
      }

      final quoteSnap = await quoteRef.get();
      if (!quoteSnap.exists) throw Exception('ההצעה לא נמצאה');
      final quote = SupplierQuote.fromMap(quoteSnap.id, quoteSnap.data()!);
      if (quote.quoteRequestId != request.id) {
        throw Exception('ההצעה אינה שייכת לבקשה זו');
      }
      if (quote.status != SupplierQuoteStatus.sent) {
        throw Exception('לא ניתן לדחות הצעה בסטטוס זה');
      }

      await quoteRef.update({'status': SupplierQuoteStatus.rejected});
    } catch (e) {
      return _handleFutureErrorVoid(
        e,
        fallback: () => MockStore.instance.rejectCustomerQuote(
          quoteId: quoteId,
          customerId: customerId,
          requestId: requestId,
        ),
      );
    }
  }

  Future<void> markSupplierOrderShipped({
    required String quoteId,
    required String requestId,
    required String supplierId,
  }) async {
    if (AppMode.isDemoMode) {
      return MockStore.instance.markSupplierOrderShipped(
        quoteId: quoteId,
        requestId: requestId,
        supplierId: supplierId,
      );
    }

    try {
      final batch = _db.batch();
      final quoteRef =
          _db.collection(AppConstants.supplierQuotesCollection).doc(quoteId);
      final requestRef =
          _db.collection(AppConstants.quoteRequestsCollection).doc(requestId);

      final quoteSnap = await quoteRef.get();
      if (!quoteSnap.exists) throw Exception('ההזמנה לא נמצאה');
      final quote = SupplierQuote.fromMap(quoteSnap.id, quoteSnap.data()!);
      if (quote.supplierId != supplierId) {
        throw Exception('אין הרשאה לעדכן הזמנה זו');
      }
      if (quote.status != SupplierQuoteStatus.approved) {
        throw Exception('ניתן לסמן כנשלח רק הזמנה שאושרה');
      }

      batch.update(quoteRef, {'status': SupplierQuoteStatus.shipped});
      batch.update(requestRef, {
        'status': QuoteRequestStatus.shipped.firestoreValue,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
    } catch (e) {
      return _handleFutureErrorVoid(
        e,
        fallback: () => MockStore.instance.markSupplierOrderShipped(
          quoteId: quoteId,
          requestId: requestId,
          supplierId: supplierId,
        ),
      );
    }
  }

  Future<void> _markOtherQuotesNotSelected(
    String requestId,
    String approvedQuoteId,
  ) async {
    final snapshot = await _db
        .collection(AppConstants.supplierQuotesCollection)
        .where('requestId', isEqualTo: requestId)
        .get();

    final batch = _db.batch();
    var hasWrites = false;

    for (final doc in snapshot.docs) {
      if (doc.id == approvedQuoteId) continue;
      final status = doc.data()['status'] as String? ?? '';
      if (status == SupplierQuoteStatus.sent) {
        batch.update(doc.reference, {
          'status': SupplierQuoteStatus.notSelected,
        });
        hasWrites = true;
      }
    }

    if (hasWrites) await batch.commit();
  }

  Future<List<SupplierQuoteItem>> getSupplierQuoteItems(String quoteId) async {
    if (AppMode.isDemoMode) {
      return MockStore.instance.getSupplierQuoteItems(quoteId);
    }

    try {
      final doc = await _db
          .collection(AppConstants.supplierQuotesCollection)
          .doc(quoteId)
          .get();
      if (!doc.exists) return [];

      final quote = SupplierQuote.fromMap(doc.id, doc.data()!);
      if (quote.items.isNotEmpty) return quote.items;

      return _loadLegacySupplierQuoteItems(quoteId);
    } catch (e) {
      return _handleFutureError(
        e,
        fallback: () => MockStore.instance.getSupplierQuoteItems(quoteId),
      );
    }
  }

  Future<List<SupplierQuoteItem>> _loadLegacySupplierQuoteItems(
    String quoteId,
  ) async {
    final snapshot = await _db
        .collection(AppConstants.supplierQuoteItemsCollection)
        .where('supplierQuoteId', isEqualTo: quoteId)
        .get();
    return snapshot.docs
        .map((d) => SupplierQuoteItem.fromMap(d.id, d.data()))
        .toList();
  }

  Future<String> submitSupplierQuote({
    required AppUser supplier,
    required String quoteRequestId,
    required String deliveryTime,
    String? notes,
    required List<SupplierQuoteLineInput> lines,
  }) async {
    if (AppMode.isDemoMode) {
      return MockStore.instance.submitSupplierQuote(
        supplier: supplier,
        quoteRequestId: quoteRequestId,
        deliveryTime: deliveryTime,
        notes: notes,
        lines: lines,
      );
    }

    final pricedLines = lines.where((l) => l.includeInQuote).toList();
    if (pricedLines.isEmpty) {
      throw Exception('יש לבחור לפחות מוצר אחד עם מחיר');
    }

    try {
      final requestRef = _db
          .collection(AppConstants.quoteRequestsCollection)
          .doc(quoteRequestId);
      final requestSnap = await requestRef.get();
      if (!requestSnap.exists) throw Exception('הבקשה לא נמצאה');
      final request = QuoteRequest.fromMap(requestSnap.id, requestSnap.data()!);
      if (request.isTender) {
        throw Exception('יש להגיש הצעות למכרז דרך מסך המכרז');
      }
      if (!_isOpenForRegularSupplierQuote(request)) {
        throw Exception('הבקשה אינה פתוחה להצעות');
      }

      final previousQuotes = await _db
          .collection(AppConstants.supplierQuotesCollection)
          .where('requestId', isEqualTo: quoteRequestId)
          .where('supplierId', isEqualTo: supplier.id)
          .get();
      final hasActiveQuote = previousQuotes.docs
          .map((d) => SupplierQuote.fromMap(d.id, d.data()))
          .any((q) =>
              q.status == SupplierQuoteStatus.sent ||
              q.status == SupplierQuoteStatus.approved);
      if (hasActiveQuote) {
        throw Exception('כבר נשלחה הצעה פעילה לבקשה זו');
      }

      final total = pricedLines.fold<double>(
        0,
        (runningTotal, l) => runningTotal + l.totalItemPrice,
      );
      final quoteId = _uuid.v4();
      final batch = _db.batch();

      final quoteRef =
          _db.collection(AppConstants.supplierQuotesCollection).doc(quoteId);
      batch.set(quoteRef, {
        'requestId': quoteRequestId,
        'quoteRequestId': quoteRequestId,
        'customerId': request.customerId,
        'supplierId': supplier.id,
        'supplierName': supplier.fullName,
        'supplierType': supplier.userType.value,
        'deliveryTime': deliveryTime,
        'notes': notes,
        'totalPrice': total,
        'status': SupplierQuoteStatus.sent,
        'seenByCustomer': false,
        'seenOrderBySupplier': false,
        'items': pricedLines
            .map(
              (line) => {
                'productId': line.productId,
                'productName': line.productName,
                'requestedQuantity': line.requestedQuantity,
                'unitPrice': line.unitPrice,
                'totalItemPrice': line.totalItemPrice,
                if (line.notes != null) 'notes': line.notes,
              },
            )
            .toList(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      batch.update(requestRef, {
        'status': QuoteRequestStatus.quotesReceived.firestoreValue,
        'supplierIdsResponded': FieldValue.arrayUnion([supplier.id]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      if (kDebugMode) {
        debugPrint(
            '[Quote] supplier quote $quoteId for request $quoteRequestId');
      }
      return quoteId;
    } catch (e) {
      return _handleFutureError(
        e,
        fallback: () => MockStore.instance.submitSupplierQuote(
          supplier: supplier,
          quoteRequestId: quoteRequestId,
          deliveryTime: deliveryTime,
          notes: notes,
          lines: lines,
        ),
      );
    }
  }

  Future<void> markCustomerReceivedQuotesSeen(String customerId) async {
    if (AppMode.isDemoMode) {
      return MockStore.instance.markCustomerReceivedQuotesSeen(customerId);
    }

    try {
      final requestsSnap = await _db
          .collection(AppConstants.quoteRequestsCollection)
          .where('customerId', isEqualTo: customerId)
          .get();
      final requestIds = requestsSnap.docs.map((d) => d.id).toSet();
      if (requestIds.isEmpty) return;

      final toMark = <DocumentReference<Map<String, dynamic>>>[];

      for (final chunk in _chunks(requestIds.toList(), 10)) {
        final quotesSnap = await _db
            .collection(AppConstants.supplierQuotesCollection)
            .where('requestId', whereIn: chunk)
            .get();
        for (final doc in quotesSnap.docs) {
          final quote = SupplierQuote.fromMap(doc.id, doc.data());
          if (!SupplierQuoteStatus.isVisibleToCustomer(quote.status)) continue;
          if (quote.seenByCustomer) continue;
          toMark.add(doc.reference);
        }
      }

      for (var i = 0; i < toMark.length; i += 450) {
        final batch = _db.batch();
        for (final ref in toMark.skip(i).take(450)) {
          batch.update(ref, {'seenByCustomer': true});
        }
        await batch.commit();
      }
    } catch (e) {
      return _handleFutureErrorVoid(
        e,
        fallback: () =>
            MockStore.instance.markCustomerReceivedQuotesSeen(customerId),
      );
    }
  }

  Future<void> markCustomerRequestsStatusSeen(
    String customerId, {
    Set<String>? requestIds,
  }) async {
    if (AppMode.isDemoMode) {
      return MockStore.instance.markCustomerRequestsStatusSeen(
        customerId,
        requestIds: requestIds,
      );
    }

    try {
      final snapshot = await _db
          .collection(AppConstants.quoteRequestsCollection)
          .where('customerId', isEqualTo: customerId)
          .get();

      final batch = _db.batch();
      var writes = 0;
      for (final doc in snapshot.docs) {
        if (requestIds != null && !requestIds.contains(doc.id)) continue;
        final request = QuoteRequest.fromMap(doc.id, doc.data());
        batch.update(doc.reference, {
          'customerLastSeenStatus': request.status.firestoreValue,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        writes++;
      }
      if (writes > 0) await batch.commit();
    } catch (e) {
      return _handleFutureErrorVoid(
        e,
        fallback: () => MockStore.instance.markCustomerRequestsStatusSeen(
          customerId,
          requestIds: requestIds,
        ),
      );
    }
  }

  Future<void> markIncomingRequestsSeenBySupplier(String supplierId) async {
    if (AppMode.isDemoMode) {
      return MockStore.instance.markIncomingRequestsSeenBySupplier(supplierId);
    }

    try {
      final snapshot = await _db
          .collection(AppConstants.quoteRequestsCollection)
          .where(
            'status',
            whereIn:
                QuoteRequestStatusExtension.openForSupplierFirestoreValues(),
          )
          .get();

      final batch = _db.batch();
      var writes = 0;

      for (final doc in snapshot.docs) {
        final request = QuoteRequest.fromMap(doc.id, doc.data());
        if (request.hasSupplierResponded(supplierId)) continue;
        if (request.seenBySupplierIds.contains(supplierId)) continue;
        batch.update(doc.reference, {
          'seenBySupplierIds': FieldValue.arrayUnion([supplierId]),
        });
        writes++;
      }
      if (writes > 0) await batch.commit();
    } catch (e) {
      return _handleFutureErrorVoid(
        e,
        fallback: () =>
            MockStore.instance.markIncomingRequestsSeenBySupplier(supplierId),
      );
    }
  }

  Future<void> markSupplierOrderSeen({
    required String supplierId,
    required String quoteId,
  }) async {
    if (AppMode.isDemoMode) {
      return MockStore.instance.markSupplierOrderSeen(
        supplierId: supplierId,
        quoteId: quoteId,
      );
    }

    try {
      final ref =
          _db.collection(AppConstants.supplierQuotesCollection).doc(quoteId);
      final snap = await ref.get();
      if (!snap.exists) return;
      final quote = SupplierQuote.fromMap(snap.id, snap.data()!);
      if (quote.supplierId != supplierId) return;
      if (quote.status != SupplierQuoteStatus.approved) return;
      await ref.update({'seenOrderBySupplier': true});
    } catch (e) {
      return _handleFutureErrorVoid(
        e,
        fallback: () => MockStore.instance.markSupplierOrderSeen(
          supplierId: supplierId,
          quoteId: quoteId,
        ),
      );
    }
  }

  Future<void> markSupplierOrdersToFulfillSeen(String supplierId) async {
    if (AppMode.isDemoMode) {
      return MockStore.instance.markSupplierOrdersToFulfillSeen(supplierId);
    }

    try {
      final snapshot = await _db
          .collection(AppConstants.supplierQuotesCollection)
          .where('supplierId', isEqualTo: supplierId)
          .where('status', isEqualTo: SupplierQuoteStatus.approved)
          .get();

      final batch = _db.batch();
      for (final doc in snapshot.docs) {
        if (FirestoreParsing.parseBool(doc.data()['seenOrderBySupplier'])) {
          continue;
        }
        batch.update(doc.reference, {'seenOrderBySupplier': true});
      }
      if (snapshot.docs.isNotEmpty) await batch.commit();
    } catch (e) {
      return _handleFutureErrorVoid(
        e,
        fallback: () =>
            MockStore.instance.markSupplierOrdersToFulfillSeen(supplierId),
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
      return _handleFutureError(
        e,
        fallback: () => MockStore.instance.getRequest(id),
      );
    }
  }

  bool _isSentQuoteHistoryStatus(SupplierQuote quote) {
    return quote.status == SupplierQuoteStatus.sent ||
        quote.status == SupplierQuoteStatus.rejected ||
        quote.status == SupplierQuoteStatus.notSelected ||
        quote.status == SupplierQuoteStatus.outdated;
  }

  bool _isOpenForRegularSupplierQuote(QuoteRequest request) {
    return !request.isTender &&
        !request.hasApprovedQuote &&
        (request.status == QuoteRequestStatus.sent ||
            request.status == QuoteRequestStatus.quotesReceived);
  }

  List<List<T>> _chunks<T>(List<T> values, int size) {
    final chunks = <List<T>>[];
    for (var i = 0; i < values.length; i += size) {
      chunks.add(values.skip(i).take(size).toList());
    }
    return chunks;
  }

  List<QuoteRequest> _mapQuoteRequests(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final list =
        snapshot.docs.map((d) => QuoteRequest.fromMap(d.id, d.data())).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  List<SupplierQuote> _mapSupplierQuotesByDate(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final list = snapshot.docs
        .map((d) => SupplierQuote.fromMap(d.id, d.data()))
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  void _handleStreamError(Object error, StackTrace stackTrace) {
    if (kDebugMode) debugPrint('[Quote] stream error: $error');
    if (AppMode.isDemoMode) {
      AppMode.tryFallbackToDemo(error);
    }
    throw Exception(FirebaseErrorHelper.toHebrewMessage(error));
  }

  T _handleFutureError<T>(
    Object error, {
    required T Function() fallback,
  }) {
    if (kDebugMode) debugPrint('[Quote] future error: $error');
    if (AppMode.isDemoMode) {
      AppMode.tryFallbackToDemo(error);
      return fallback();
    }
    throw Exception(FirebaseErrorHelper.toHebrewMessage(error));
  }

  Future<void> _handleFutureErrorVoid(
    Object error, {
    required Future<void> Function() fallback,
  }) async {
    if (kDebugMode) debugPrint('[Quote] future error: $error');
    if (AppMode.isDemoMode) {
      AppMode.tryFallbackToDemo(error);
      return fallback();
    }
    throw Exception(FirebaseErrorHelper.toHebrewMessage(error));
  }
}

class SupplierQuoteLineInput {
  SupplierQuoteLineInput({
    required this.productId,
    required this.productName,
    required this.requestedQuantity,
    required this.unitPrice,
    required this.totalItemPrice,
    this.notes,
    this.includeInQuote = true,
  });

  final String productId;
  final String productName;
  final int requestedQuantity;
  final double unitPrice;
  final double totalItemPrice;
  final String? notes;
  final bool includeInQuote;
}
