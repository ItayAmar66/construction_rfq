import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../config/app_mode.dart';
import '../models/app_user.dart';
import '../models/quote_request.dart';
import '../models/quote_status.dart';
import '../models/supplier_quote.dart';
import '../models/supplier_quote_item.dart';
import '../services/mock_store.dart';
import '../services/quote_persistence_support.dart';
import '../services/quote_service.dart' show SupplierQuoteLineInput;
import '../utils/constants.dart';
import '../utils/payment_terms.dart';
import '../utils/quote_financials.dart';
import '../utils/supplier_quote_status.dart';

class SupplierQuoteRepository {
  SupplierQuoteRepository({FirebaseFirestore? firestore}) : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;
  final _uuid = const Uuid();

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
  }) async {
    if (AppMode.isDemoMode) {
      return MockStore.instance.submitSupplierQuote(
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
        ...financials.toFirestoreMap(
          validUntil: validity,
          paymentTerms: paymentTerms,
        ),
        'items': pricedLines.map((line) => line.toEmbeddedMap()).toList(),
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
}
