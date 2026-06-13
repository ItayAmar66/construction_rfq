import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../config/app_mode.dart';
import '../models/enterprise/audit_event.dart';
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
import '../utils/payment_terms.dart';
import '../repositories/audit_repository.dart';
import '../repositories/request_repository.dart';
import '../repositories/supplier_quote_repository.dart';
import '../utils/quote_financials.dart';
import '../utils/supplier_quote_status.dart';
import 'approval_service.dart';
import 'mock_store.dart';
import 'quote_persistence_support.dart';

class QuoteService {
  QuoteService({
    FirebaseFirestore? firestore,
    RequestRepository? requestRepository,
    SupplierQuoteRepository? supplierQuoteRepository,
    AuditRepository? auditRepository,
  })  : _firestore = firestore,
        _requestRepository = requestRepository ??
            RequestRepository(firestore: firestore),
        _supplierQuoteRepository = supplierQuoteRepository ??
            SupplierQuoteRepository(firestore: firestore),
        _auditRepository = auditRepository ?? AuditRepository(firestore: firestore);

  final FirebaseFirestore? _firestore;
  final RequestRepository _requestRepository;
  final SupplierQuoteRepository _supplierQuoteRepository;
  final AuditRepository _auditRepository;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;
  final _uuid = const Uuid();

  Stream<List<QuoteRequest>> watchCustomerRequests(String customerId) =>
      _requestRepository.watchCustomerRequests(customerId);

  Stream<QuoteRequest?> watchQuoteRequest(String requestId) =>
      _requestRepository.watchQuoteRequest(requestId);

  /// Open requests this supplier has not yet quoted on.
  Stream<List<QuoteRequest>> watchIncomingRequestsForSupplier(
    String supplierId,
  ) =>
      _requestRepository.watchIncomingRequestsForSupplier(supplierId);

  Future<List<QuoteRequestItem>> getRequestItems(String requestId) =>
      _requestRepository.getRequestItems(requestId);

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
  }) =>
      _requestRepository.submitQuoteRequest(
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

  Future<void> sendPendingApprovalToSuppliers({
    required String requestId,
    required String customerId,
  }) =>
      _requestRepository.sendPendingApprovalToSuppliers(
        requestId: requestId,
        customerId: customerId,
      );

  Future<void> updateQuoteRequest({
    required String requestId,
    required String customerId,
    required List<QuoteRequestItem> items,
    String? notes,
  }) =>
      _requestRepository.updateQuoteRequest(
        requestId: requestId,
        customerId: customerId,
        items: items,
        notes: notes,
      );

  Future<void> deleteOrCancelQuoteRequest({
    required String requestId,
    required String customerId,
  }) =>
      _requestRepository.deleteOrCancelQuoteRequest(
        requestId: requestId,
        customerId: customerId,
      );

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
      return handleQuoteFutureErrorVoid(
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
    double deliveryCost = 0,
    double vatRate = QuoteFinancialBreakdown.defaultVatRate,
    DateTime? validUntil,
    String paymentTerms = PaymentTerms.defaultValue,
  }) async {
    if (AppMode.isDemoMode) {
      return MockStore.instance.submitTenderCounterBid(
        supplier: supplier,
        quoteRequestId: quoteRequestId,
        deliveryTime: deliveryTime,
        notes: notes,
        lines: lines,
        deliveryCost: deliveryCost,
        vatRate: vatRate,
        validUntil: validUntil,
        paymentTerms: paymentTerms,
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

      final lineSubtotal = pricedLines.fold<double>(
        0,
        (runningTotal, l) => runningTotal + l.totalItemPrice,
      );
      final financials = QuoteFinancialBreakdown.compute(
        subtotal: lineSubtotal,
        deliveryCost: deliveryCost,
        vatRate: vatRate,
      );
      final validity = validUntil ?? DateTime.now().add(const Duration(days: 14));
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
        'status': SupplierQuoteStatus.sent,
        'seenByCustomer': false,
        'seenOrderBySupplier': false,
        'isTenderBid': true,
        'bidVersion': bidVersion,
        ...financials.toFirestoreMap(
          validUntil: validity,
          paymentTerms: paymentTerms,
        ),
        'items': pricedLines.map((line) => line.toEmbeddedMap()).toList(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      final updateRequest = <String, dynamic>{
        'status': QuoteRequestStatus.quotesReceived.firestoreValue,
        'supplierIdsResponded': FieldValue.arrayUnion([supplier.id]),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      final activeTotals = <double>[financials.totalInclVat];
      for (final doc in requestQuotes.docs) {
        final quote = SupplierQuote.fromMap(doc.id, doc.data());
        if (quote.supplierId == supplier.id) continue;
        if (quote.status == SupplierQuoteStatus.sent) {
          activeTotals.add(quote.displayTotal);
        }
      }
      activeTotals.sort();
      updateRequest['lowestBid'] = activeTotals.first;
      batch.update(requestRef, updateRequest);

      await batch.commit();
      return quoteId;
    } catch (e) {
      return handleQuoteFutureError(
        e,
        fallback: () => MockStore.instance.submitTenderCounterBid(
          supplier: supplier,
          quoteRequestId: quoteRequestId,
          deliveryTime: deliveryTime,
          notes: notes,
          lines: lines,
          deliveryCost: deliveryCost,
          vatRate: vatRate,
          validUntil: validUntil,
          paymentTerms: paymentTerms,
        ),
      );
    }
  }

  Stream<List<SupplierQuote>> watchQuotesForRequest(String requestId) =>
      _supplierQuoteRepository.watchQuotesForRequest(requestId);

  /// Real-time quotes for a customer — listens to both collections without
  /// cancelling the quotes listener when requests change.
  Stream<List<SupplierQuote>> watchCustomerReceivedQuotes(String customerId) =>
      _supplierQuoteRepository.watchCustomerReceivedQuotes(customerId);

  Stream<SupplierQuote?> watchSupplierQuote(String quoteId) =>
      _supplierQuoteRepository.watchSupplierQuote(quoteId);

  /// Quotes the supplier sent, excluding orders that moved to fulfillment.
  Stream<List<SupplierQuote>> watchSupplierSentQuotes(String supplierId) =>
      _supplierQuoteRepository.watchSupplierSentQuotes(supplierId);

  Stream<List<SupplierQuote>> watchSupplierOrdersToFulfill(String supplierId) =>
      _supplierQuoteRepository.watchSupplierOrdersToFulfill(supplierId);

  Stream<List<SupplierQuote>> watchSupplierOrderHistory(String supplierId) =>
      _supplierQuoteRepository.watchSupplierOrderHistory(supplierId);

  Future<void> approveCustomerQuote({
    required String quoteId,
    required String requestId,
    required String customerId,
  }) async {
    if (AppMode.isDemoMode) {
      final request = MockStore.instance.getRequest(requestId);
      SupplierQuote? quote;
      for (final q in MockStore.instance.supplierQuotes) {
        if (q.id == quoteId) {
          quote = q;
          break;
        }
      }
      if (request != null && quote != null) {
        ApprovalService.validateApproval(
          request: request,
          quote: quote,
          customerId: customerId,
        );
      }
      await MockStore.instance.approveCustomerQuote(
        quoteId: quoteId,
        requestId: requestId,
        customerId: customerId,
      );
      final req = MockStore.instance.getRequest(requestId);
      await _auditQuoteAction(
        actorUid: customerId,
        quoteId: quoteId,
        requestId: requestId,
        action: AuditAction.quoteApproved,
        summary: 'אושרה הצעת מחיר',
        projectId: req?.projectId,
      );
      return;
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

        final quoteSnap = await transaction.get(quoteRef);
        if (!quoteSnap.exists) {
          throw Exception('ההצעה לא נמצאה');
        }
        final quote = SupplierQuote.fromMap(quoteSnap.id, quoteSnap.data()!);

        ApprovalService.validateApproval(
          request: request,
          quote: quote,
          customerId: customerId,
        );

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
      final requestSnap = await requestRef.get();
      final projectId = requestSnap.data()?['projectId']?.toString();
      await _auditQuoteAction(
        actorUid: customerId,
        quoteId: quoteId,
        requestId: requestId,
        action: AuditAction.quoteApproved,
        summary: 'אושרה הצעת מחיר',
        projectId: projectId,
      );
    } catch (e) {
      return handleQuoteFutureErrorVoid(
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
      await MockStore.instance.rejectCustomerQuote(
        quoteId: quoteId,
        customerId: customerId,
        requestId: requestId,
      );
      await _auditQuoteAction(
        actorUid: customerId,
        quoteId: quoteId,
        requestId: requestId,
        action: AuditAction.quoteRejected,
        summary: 'נדחתה הצעת מחיר',
      );
      return;
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
      await _auditQuoteAction(
        actorUid: customerId,
        quoteId: quoteId,
        requestId: requestId,
        action: AuditAction.quoteRejected,
        summary: 'נדחתה הצעת מחיר',
        projectId: request.projectId,
      );
    } catch (e) {
      return handleQuoteFutureErrorVoid(
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
      await MockStore.instance.markSupplierOrderShipped(
        quoteId: quoteId,
        requestId: requestId,
        supplierId: supplierId,
      );
      await _auditQuoteAction(
        actorUid: supplierId,
        quoteId: quoteId,
        requestId: requestId,
        action: AuditAction.orderMarkedShipped,
        summary: 'הזמנה סומנה כנשלחה',
        entityType: AuditEntityType.order,
      );
      return;
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
        'shippedBySupplierId': supplierId,
        'shippedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      await _auditQuoteAction(
        actorUid: supplierId,
        quoteId: quoteId,
        requestId: requestId,
        action: AuditAction.orderMarkedShipped,
        summary: 'הזמנה סומנה כנשלחה',
        entityType: AuditEntityType.order,
      );
    } catch (e) {
      return handleQuoteFutureErrorVoid(
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

  Future<List<SupplierQuoteItem>> getSupplierQuoteItems(String quoteId) =>
      _supplierQuoteRepository.getSupplierQuoteItems(quoteId);

  Future<String> submitSupplierQuote({
    required AppUser supplier,
    required String quoteRequestId,
    required String deliveryTime,
    String? notes,
    required List<SupplierQuoteLineInput> lines,
    double deliveryCost = 0,
    double vatRate = QuoteFinancialBreakdown.defaultVatRate,
    DateTime? validUntil,
    String paymentTerms = PaymentTerms.defaultValue,
  }) =>
      _supplierQuoteRepository.submitSupplierQuote(
        supplier: supplier,
        quoteRequestId: quoteRequestId,
        deliveryTime: deliveryTime,
        notes: notes,
        lines: lines,
        deliveryCost: deliveryCost,
        vatRate: vatRate,
        validUntil: validUntil,
        paymentTerms: paymentTerms,
      );

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
      return handleQuoteFutureErrorVoid(
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
      return handleQuoteFutureErrorVoid(
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
      return handleQuoteFutureErrorVoid(
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
      return handleQuoteFutureErrorVoid(
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
      return handleQuoteFutureErrorVoid(
        e,
        fallback: () =>
            MockStore.instance.markSupplierOrdersToFulfillSeen(supplierId),
      );
    }
  }

  Future<QuoteRequest?> getRequest(String id) => _requestRepository.getRequest(id);

  List<List<T>> _chunks<T>(List<T> values, int size) {
    final chunks = <List<T>>[];
    for (var i = 0; i < values.length; i += size) {
      chunks.add(values.skip(i).take(size).toList());
    }
    return chunks;
  }

  Future<void> _auditQuoteAction({
    required String actorUid,
    required String quoteId,
    required String requestId,
    required String action,
    required String summary,
    String? projectId,
    String entityType = AuditEntityType.quote,
  }) async {
    await AuditLogger.record(
      repository: _auditRepository,
      actorUid: actorUid,
      projectId: projectId,
      entityType: entityType,
      entityId: quoteId,
      action: action,
      summaryHebrew: summary,
      metadata: {'requestId': requestId},
    );
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
    this.requestItemId,
    this.variantId,
    this.quotedName,
    this.quotedSku,
    this.isExactMatch = false,
    this.isAlternative = false,
    this.supplierNotes,
  });

  final String productId;
  final String productName;
  final int requestedQuantity;
  final double unitPrice;
  final double totalItemPrice;
  final String? notes;
  final bool includeInQuote;
  final String? requestItemId;
  final String? variantId;
  final String? quotedName;
  final String? quotedSku;
  final bool isExactMatch;
  final bool isAlternative;
  final String? supplierNotes;

  Map<String, dynamic> toEmbeddedMap() {
    return {
      'productId': productId,
      'productName': productName,
      'requestedQuantity': requestedQuantity,
      'unitPrice': unitPrice,
      'totalItemPrice': totalItemPrice,
      if (notes != null) 'notes': notes,
      if (requestItemId != null && requestItemId!.isNotEmpty)
        'requestItemId': requestItemId,
      if (variantId != null && variantId!.isNotEmpty) 'variantId': variantId,
      if (quotedName != null && quotedName!.isNotEmpty) 'quotedName': quotedName,
      if (quotedSku != null && quotedSku!.isNotEmpty) 'quotedSku': quotedSku,
      'isExactMatch': isExactMatch,
      'isAlternative': isAlternative,
      if (supplierNotes != null) 'supplierNotes': supplierNotes,
    };
  }
}
