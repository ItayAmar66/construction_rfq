import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../config/app_mode.dart';
import '../models/enterprise/audit_event.dart';
import '../models/app_user.dart';
import '../models/quote_request.dart';
import '../models/quote_status.dart';
import '../models/supplier_quote.dart';
import '../models/supplier_quote_item.dart';
import '../services/mock_store.dart';
import '../services/quote_persistence_support.dart';
import '../services/quote_service.dart' show SupplierQuoteLineInput;
import '../repositories/audit_repository.dart';
import '../utils/constants.dart';
import '../utils/payment_terms.dart';
import '../utils/quote_financials.dart';
import '../utils/supplier_quote_doc_id.dart';
import '../utils/supplier_quote_status.dart';
import '../utils/user_org_id_resolver.dart';

class SupplierQuoteRepository {
  SupplierQuoteRepository({
    FirebaseFirestore? firestore,
    AuditRepository? auditRepository,
  })  : _firestore = firestore,
        _auditRepository = auditRepository ?? AuditRepository(firestore: firestore);

  final FirebaseFirestore? _firestore;
  final AuditRepository _auditRepository;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

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
        .handleError(handleQuoteStreamError);
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
        .handleError(handleQuoteStreamError);
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
    }).handleError(handleQuoteStreamError);
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
    }).handleError(handleQuoteStreamError);
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
        .handleError(handleQuoteStreamError);
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
        .handleError(handleQuoteStreamError);
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
      return handleQuoteFutureError(
        e,
        fallback: () => MockStore.instance.getSupplierQuoteItems(quoteId),
      );
    }
  }

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
    String? supplierOrgId,
  }) async {
    if (AppMode.isDemoMode) {
      final quoteId = await MockStore.instance.submitSupplierQuote(
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
      await _auditQuoteSubmitted(
        actorUid: supplier.id,
        quoteId: quoteId,
        requestId: quoteRequestId,
        supplierName: supplier.fullName,
      );
      return quoteId;
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

      final resolvedOrgId = await _resolveSupplierOrgId(
        supplierId: supplier.id,
        supplierOrgId: supplierOrgId,
      );
      if (await _hasActiveOrgQuote(
        quoteRequestId: quoteRequestId,
        supplierOrgId: resolvedOrgId,
        supplierId: supplier.id,
      )) {
        throw Exception('כבר נשלחה הצעה מטעם הספק הזה לבקשה זו');
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
      final quoteId = SupplierQuoteDocId.forRequest(
        quoteRequestId: quoteRequestId,
        supplierId: supplier.id,
        supplierOrgId: resolvedOrgId,
      );
      final quoteRef =
          _db.collection(AppConstants.supplierQuotesCollection).doc(quoteId);

      await _db.runTransaction((tx) async {
        final existingQuote = await tx.get(quoteRef);
        if (existingQuote.exists) {
          final existing = SupplierQuote.fromMap(
            existingQuote.id,
            existingQuote.data()!,
          );
          if (existing.status == SupplierQuoteStatus.sent ||
              existing.status == SupplierQuoteStatus.approved) {
            throw Exception('כבר נשלחה הצעה מטעם הספק הזה לבקשה זו');
          }
        }

        tx.set(quoteRef, {
          'requestId': quoteRequestId,
          'quoteRequestId': quoteRequestId,
          'customerId': request.customerId,
          'supplierId': supplier.id,
          if (resolvedOrgId != null && resolvedOrgId.isNotEmpty)
            'supplierOrgId': resolvedOrgId,
          'supplierName': supplier.fullName,
          'supplierType': supplier.userType.value,
          'deliveryTime': deliveryTime,
          'notes': notes,
          'status': SupplierQuoteStatus.sent,
          'seenByCustomer': false,
          'seenOrderBySupplier': false,
          ...financials.toFirestoreMap(
            validUntil: validity,
            paymentTerms: paymentTerms,
          ),
          'items': pricedLines.map((line) => line.toEmbeddedMap()).toList(),
          'createdAt': FieldValue.serverTimestamp(),
        });
        tx.update(requestRef, {
          'status': QuoteRequestStatus.quotesReceived.firestoreValue,
          'supplierIdsResponded': FieldValue.arrayUnion([supplier.id]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      if (kDebugMode) {
        debugPrint(
            '[Quote] supplier quote $quoteId for request $quoteRequestId');
      }
      await _auditQuoteSubmitted(
        actorUid: supplier.id,
        quoteId: quoteId,
        requestId: quoteRequestId,
        supplierName: supplier.fullName,
        projectId: request.projectId,
      );
      return quoteId;
    } catch (e) {
      return handleQuoteFutureError(
        e,
        fallback: () => MockStore.instance.submitSupplierQuote(
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

  List<SupplierQuote> _mapSupplierQuotesByDate(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final list = snapshot.docs
        .map((d) => SupplierQuote.fromMap(d.id, d.data()))
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<String?> _resolveSupplierOrgId({
    required String supplierId,
    String? supplierOrgId,
  }) async {
    final trimmed = supplierOrgId?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    try {
      final profile =
          await _db.collection(AppConstants.usersCollection).doc(supplierId).get();
      final profileOrgIds = UserOrgIdResolver.candidateOrgIds(
        uid: supplierId,
        profile: profile.data(),
      ).where((id) => id != supplierId);
      if (profileOrgIds.isNotEmpty) {
        return profileOrgIds.first;
      }
    } catch (_) {
      // Fall through to optional collectionGroup lookup.
    }
    try {
      final snap = await _db
          .collectionGroup(AppConstants.membershipsSubcollection)
          .where('uid', isEqualTo: supplierId)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      final orgId = snap.docs.first.data()['orgId'];
      return orgId is String && orgId.isNotEmpty ? orgId : null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> _hasActiveOrgQuote({
    required String quoteRequestId,
    required String? supplierOrgId,
    required String supplierId,
  }) async {
    final activeStatuses = {
      SupplierQuoteStatus.sent,
      SupplierQuoteStatus.approved,
    };

    if (supplierOrgId != null && supplierOrgId.isNotEmpty) {
      final orgDocId = SupplierQuoteDocId.forRequest(
        quoteRequestId: quoteRequestId,
        supplierId: supplierId,
        supplierOrgId: supplierOrgId,
      );
      final orgDoc =
          await _db.collection(AppConstants.supplierQuotesCollection).doc(orgDocId).get();
      if (orgDoc.exists) {
        final quote = SupplierQuote.fromMap(orgDoc.id, orgDoc.data()!);
        if (activeStatuses.contains(quote.status)) return true;
      }

      final orgQuotes = await _db
          .collection(AppConstants.supplierQuotesCollection)
          .where('requestId', isEqualTo: quoteRequestId)
          .where('supplierOrgId', isEqualTo: supplierOrgId)
          .get();
      if (orgQuotes.docs
          .map((d) => SupplierQuote.fromMap(d.id, d.data()))
          .any((q) => activeStatuses.contains(q.status))) {
        return true;
      }
    }

    final legacyQuotes = await _db
        .collection(AppConstants.supplierQuotesCollection)
        .where('requestId', isEqualTo: quoteRequestId)
        .where('supplierId', isEqualTo: supplierId)
        .get();
    return legacyQuotes.docs
        .map((d) => SupplierQuote.fromMap(d.id, d.data()))
        .any((q) => activeStatuses.contains(q.status));
  }

  Future<void> _auditQuoteSubmitted({
    required String actorUid,
    required String quoteId,
    required String requestId,
    required String supplierName,
    String? projectId,
  }) async {
    await AuditLogger.record(
      repository: _auditRepository,
      actorUid: actorUid,
      projectId: projectId,
      entityType: AuditEntityType.quote,
      entityId: quoteId,
      action: AuditAction.quoteSubmitted,
      summaryHebrew: 'הוגשה הצעת מחיר — $supplierName',
      metadata: {'requestId': requestId},
    );
  }
}
