import 'dart:async';

import 'package:uuid/uuid.dart';

import '../data/seed_products.dart';
import '../models/app_user.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../models/quote_request.dart';
import '../models/quote_request_item.dart';
import '../models/quote_status.dart';
import '../models/request_type.dart';
import '../models/supplier_quote.dart';
import '../models/supplier_quote_item.dart';
import '../models/user_type.dart';
import '../utils/payment_terms.dart';
import '../utils/quote_financials.dart';
import '../utils/supplier_quote_status.dart';
import 'quote_service.dart';

/// In-memory backend for demo / offline MVP testing.
class MockStore {
  MockStore._();

  static final MockStore instance = MockStore._();
  static const _uuid = Uuid();

  final _authController = StreamController<String?>.broadcast();
  final _changeController = StreamController<void>.broadcast();

  AppUser? currentUser;
  late List<Product> products;
  final List<QuoteRequest> quoteRequests = [];
  final List<SupplierQuote> supplierQuotes = [];

  void init() {
    products = getSeedProducts();
  }

  Stream<String?> get authStateChanges async* {
    yield currentUser?.id;
    yield* _authController.stream;
  }

  void _notify() => _changeController.add(null);

  Stream<T> _watch<T>(T Function() read) async* {
    yield read();
    await for (final _ in _changeController.stream) {
      yield read();
    }
  }

  static final demoCustomer = AppUser(
    id: 'demo-customer',
    fullName: 'קבלן לדוגמה',
    email: 'customer@demo.local',
    phone: '050-0000001',
    userType: UserType.privateCustomer,
    city: 'תל אביב',
    notes: 'חשבון הדגמה',
    createdAt: DateTime(2024, 1, 1),
  );

  static final demoSupplier = AppUser(
    id: 'demo-supplier',
    fullName: 'ספק לדוגמה',
    email: 'supplier@demo.local',
    phone: '050-0000002',
    userType: UserType.privateSupplier,
    city: 'חיפה',
    notes: 'חשבון הדגמה',
    createdAt: DateTime(2024, 1, 1),
  );

  void loginAsDemo(UserType type) {
    currentUser = type.isSupplier ? demoSupplier : demoCustomer;
    _authController.add(currentUser!.id);
    _notify();
  }

  void logout() {
    currentUser = null;
    _authController.add(null);
    _notify();
  }

  void registerUser({
    required String fullName,
    required String phone,
    required String email,
    required UserType userType,
    required String city,
    String? notes,
  }) {
    final user = AppUser(
      id: _uuid.v4(),
      fullName: fullName,
      email: email,
      phone: phone,
      userType: userType,
      city: city,
      notes: notes,
      createdAt: DateTime.now(),
    );
    currentUser = user;
    _authController.add(user.id);
    _notify();
  }

  void updateProfile({
    required String fullName,
    required String phone,
    required String city,
    String? notes,
  }) {
    final user = currentUser;
    if (user == null) return;
    currentUser = AppUser(
      id: user.id,
      fullName: fullName,
      email: user.email,
      phone: phone,
      userType: user.userType,
      city: city,
      notes: notes,
      createdAt: user.createdAt,
    );
    _notify();
  }

  Stream<List<Product>> watchProducts() => _watch(() =>
      List<Product>.from(products)..sort((a, b) => a.name.compareTo(b.name)));

  Product? getProduct(String id) {
    try {
      return products.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  List<String> getCategories() {
    final categories = products.map((p) => p.category).toSet().toList();
    categories.sort();
    return categories;
  }

  Stream<List<QuoteRequest>> watchCustomerRequests(String customerId) =>
      _watch(() {
        final list =
            quoteRequests.where((r) => r.customerId == customerId).toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });

  Stream<List<QuoteRequest>> watchIncomingRequestsForSupplier(
          String supplierId) =>
      _watch(() {
        final list = quoteRequests
            .where(
              (r) =>
                  (r.status == QuoteRequestStatus.sent ||
                      r.status == QuoteRequestStatus.quotesReceived) &&
                  (r.isTenderActive || !r.hasSupplierResponded(supplierId)),
            )
            .toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });

  List<QuoteRequestItem> getRequestItems(String requestId) {
    try {
      return quoteRequests.firstWhere((r) => r.id == requestId).items;
    } catch (_) {
      return [];
    }
  }

  String submitQuoteRequest({
    required AppUser customer,
    required List<CartItem> items,
    String? notes,
    RequestType requestType = RequestType.regular,
    Duration tenderDuration = const Duration(hours: 24),
  }) {
    if (items.isEmpty) throw Exception('אין מוצרים בבקשה');

    final requestId = _uuid.v4();
    final now = DateTime.now();
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

    quoteRequests.add(
      QuoteRequest(
        id: requestId,
        customerId: customer.id,
        customerName: customer.fullName,
        customerPhone: customer.phone,
        customerCity: customer.city,
        customerType: customer.userType.value,
        status: QuoteRequestStatus.sent,
        notes: notes,
        createdAt: now,
        updatedAt: now,
        items: requestItems,
        supplierIdsResponded: const [],
        customerLastSeenStatus: QuoteRequestStatus.sent.firestoreValue,
        seenBySupplierIds: const [],
        requestType: requestType,
        tenderEndTime:
            requestType == RequestType.tender ? now.add(tenderDuration) : null,
        tenderClosed: false,
      ),
    );

    _notify();
    return requestId;
  }

  Future<void> updateQuoteRequest({
    required String requestId,
    required String customerId,
    required List<QuoteRequestItem> items,
    String? notes,
  }) async {
    final index = quoteRequests.indexWhere((r) => r.id == requestId);
    if (index < 0) throw Exception('הבקשה לא נמצאה');
    final r = quoteRequests[index];
    if (r.customerId != customerId) throw Exception('אין הרשאה');
    if (!r.isEditable) throw Exception('לא ניתן לערוך');

    quoteRequests[index] = _copyRequest(
      r,
      items: items,
      notes: notes,
      updatedAt: DateTime.now(),
      supplierIdsResponded: const [],
      seenBySupplierIds: const [],
    );

    for (var i = 0; i < supplierQuotes.length; i++) {
      final q = supplierQuotes[i];
      if (q.quoteRequestId == requestId &&
          (q.status == SupplierQuoteStatus.sent ||
              q.status == SupplierQuoteStatus.approved)) {
        supplierQuotes[i] = _copyQuote(q, status: SupplierQuoteStatus.outdated);
      }
    }
    _notify();
  }

  Future<void> deleteOrCancelQuoteRequest({
    required String requestId,
    required String customerId,
  }) async {
    final index = quoteRequests.indexWhere((r) => r.id == requestId);
    if (index < 0) throw Exception('הבקשה לא נמצאה');
    if (quoteRequests[index].customerId != customerId) {
      throw Exception('אין הרשאה');
    }

    final hasQuotes = supplierQuotes.any((q) => q.quoteRequestId == requestId);
    if (hasQuotes) {
      quoteRequests[index] = _copyRequest(
        quoteRequests[index],
        status: QuoteRequestStatus.cancelled,
        updatedAt: DateTime.now(),
      );
    } else {
      quoteRequests.removeAt(index);
    }
    _notify();
  }

  Future<void> closeTender({
    required String requestId,
    required String customerId,
  }) async {
    final index = quoteRequests.indexWhere((r) => r.id == requestId);
    if (index < 0) throw Exception('הבקשה לא נמצאה');
    quoteRequests[index] = _copyRequest(
      quoteRequests[index],
      tenderClosed: true,
      updatedAt: DateTime.now(),
    );
    _notify();
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
    return submitSupplierQuote(
      supplier: supplier,
      quoteRequestId: quoteRequestId,
      deliveryTime: deliveryTime,
      notes: notes,
      lines: lines,
      isTenderBid: true,
      deliveryCost: deliveryCost,
      vatRate: vatRate,
      validUntil: validUntil,
      paymentTerms: paymentTerms,
    );
  }

  Stream<QuoteRequest?> watchQuoteRequest(String requestId) => _watch(() {
        try {
          return quoteRequests.firstWhere((r) => r.id == requestId);
        } catch (_) {
          return null;
        }
      });

  Stream<SupplierQuote?> watchSupplierQuote(String quoteId) => _watch(() {
        try {
          return supplierQuotes.firstWhere((q) => q.id == quoteId);
        } catch (_) {
          return null;
        }
      });

  Stream<List<SupplierQuote>> watchQuotesForRequest(String requestId) =>
      _watch(() {
        final list = supplierQuotes
            .where(
              (q) =>
                  q.quoteRequestId == requestId &&
                  SupplierQuoteStatus.isVisibleToCustomer(q.status),
            )
            .toList();
        list.sort((a, b) => a.totalPrice.compareTo(b.totalPrice));
        return list;
      });

  Stream<List<SupplierQuote>> watchCustomerReceivedQuotes(String customerId) =>
      _watch(() {
        final requestIds = quoteRequests
            .where((r) => r.customerId == customerId)
            .map((r) => r.id)
            .toSet();
        final list = supplierQuotes
            .where(
              (q) =>
                  requestIds.contains(q.quoteRequestId) &&
                  SupplierQuoteStatus.isVisibleToCustomer(q.status),
            )
            .toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });

  Stream<List<SupplierQuote>> watchSupplierSentQuotes(String supplierId) =>
      _watch(() {
        final list = supplierQuotes
            .where(
              (q) =>
                  q.supplierId == supplierId &&
                  (q.status == SupplierQuoteStatus.sent ||
                      q.status == SupplierQuoteStatus.rejected ||
                      q.status == SupplierQuoteStatus.notSelected ||
                      q.status == SupplierQuoteStatus.outdated),
            )
            .toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });

  Stream<List<SupplierQuote>> watchSupplierOrdersToFulfill(String supplierId) =>
      _watch(() {
        final list = supplierQuotes
            .where(
              (q) =>
                  q.supplierId == supplierId &&
                  q.status == SupplierQuoteStatus.approved,
            )
            .toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });

  Stream<List<SupplierQuote>> watchSupplierOrderHistory(String supplierId) =>
      _watch(() {
        final list = supplierQuotes
            .where(
              (q) =>
                  q.supplierId == supplierId &&
                  q.status == SupplierQuoteStatus.shipped,
            )
            .toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });

  List<SupplierQuoteItem> getSupplierQuoteItems(String quoteId) {
    try {
      return supplierQuotes.firstWhere((q) => q.id == quoteId).items;
    } catch (_) {
      return [];
    }
  }

  String submitSupplierQuote({
    required AppUser supplier,
    required String quoteRequestId,
    required String deliveryTime,
    String? notes,
    required List<SupplierQuoteLineInput> lines,
    bool isTenderBid = false,
    double deliveryCost = 0,
    double vatRate = QuoteFinancialBreakdown.defaultVatRate,
    DateTime? validUntil,
    String paymentTerms = PaymentTerms.defaultValue,
  }) {
    final pricedLines = lines.where((l) => l.includeInQuote).toList();
    if (pricedLines.isEmpty) {
      throw Exception('יש לבחור לפחות מוצר אחד עם מחיר');
    }

    final lineSubtotal =
        pricedLines.fold<double>(0, (s, l) => s + l.totalItemPrice);
    final financials = QuoteFinancialBreakdown.compute(
      subtotal: lineSubtotal,
      deliveryCost: deliveryCost,
      vatRate: vatRate,
    );
    final quoteId = _uuid.v4();
    final now = DateTime.now();
    final validity = validUntil ?? now.add(const Duration(days: 14));
    final requestIndex =
        quoteRequests.indexWhere((r) => r.id == quoteRequestId);
    if (requestIndex < 0) throw Exception('הבקשה לא נמצאה');
    final request = quoteRequests[requestIndex];
    if (isTenderBid) {
      if (!request.isTenderActive) throw Exception('המכרז אינו פעיל');
    } else {
      if (request.isTender) {
        throw Exception('יש להגיש הצעות למכרז דרך מסך המכרז');
      }
      if (request.hasApprovedQuote ||
          (request.status != QuoteRequestStatus.sent &&
              request.status != QuoteRequestStatus.quotesReceived)) {
        throw Exception('הבקשה אינה פתוחה להצעות');
      }
      final hasActiveQuote = supplierQuotes.any(
        (q) =>
            q.quoteRequestId == quoteRequestId &&
            q.supplierId == supplier.id &&
            (q.status == SupplierQuoteStatus.sent ||
                q.status == SupplierQuoteStatus.approved),
      );
      if (hasActiveQuote) {
        throw Exception('כבר נשלחה הצעה פעילה לבקשה זו');
      }
    }

    if (isTenderBid) {
      for (var i = 0; i < supplierQuotes.length; i++) {
        final q = supplierQuotes[i];
        if (q.quoteRequestId == quoteRequestId &&
            q.supplierId == supplier.id &&
            q.status == SupplierQuoteStatus.sent) {
          supplierQuotes[i] = _copyQuote(
            q,
            status: SupplierQuoteStatus.outdated,
          );
        }
      }
    }

    final priorBids = supplierQuotes
        .where(
          (q) =>
              q.quoteRequestId == quoteRequestId &&
              q.supplierId == supplier.id &&
              q.isTenderBid,
        )
        .length;
    final bidVersion = isTenderBid ? priorBids + 1 : 1;

    final quoteItems = pricedLines
        .map(
          (line) => SupplierQuoteItem(
            id: _uuid.v4(),
            supplierQuoteId: quoteId,
            productId: line.productId,
            productName: line.productName,
            requestedQuantity: line.requestedQuantity,
            unitPrice: line.unitPrice,
            totalItemPrice: line.totalItemPrice,
            notes: line.notes,
          ),
        )
        .toList();

    supplierQuotes.add(
      SupplierQuote(
        id: quoteId,
        quoteRequestId: quoteRequestId,
        supplierId: supplier.id,
        supplierName: supplier.fullName,
        supplierType: supplier.userType.value,
        deliveryTime: deliveryTime,
        notes: notes,
        totalPrice: financials.totalInclVat,
        status: SupplierQuoteStatus.sent,
        createdAt: now,
        items: quoteItems,
        seenByCustomer: false,
        seenOrderBySupplier: false,
        isTenderBid: isTenderBid,
        bidVersion: bidVersion,
        subtotal: financials.subtotal,
        deliveryCost: financials.deliveryCost,
        vatRate: financials.vatRate,
        vatAmount: financials.vatAmount,
        totalInclVat: financials.totalInclVat,
        validUntil: validity,
        paymentTerms: paymentTerms,
      ),
    );

    if (requestIndex >= 0) {
      final r = quoteRequests[requestIndex];
      final responded = r.supplierIdsResponded.contains(supplier.id)
          ? r.supplierIdsResponded
          : [...r.supplierIdsResponded, supplier.id];

      double? lowestBid = r.lowestBid;
      if (r.requestType == RequestType.tender) {
        final activeBids = supplierQuotes
            .where(
              (q) =>
                  q.quoteRequestId == quoteRequestId &&
                  q.status == SupplierQuoteStatus.sent &&
                  !q.isOutdated,
            )
            .map((q) => q.displayTotal);
        if (activeBids.isNotEmpty) {
          lowestBid = activeBids.reduce((a, b) => a < b ? a : b);
        }
      }

      quoteRequests[requestIndex] = _copyRequest(
        r,
        status: QuoteRequestStatus.quotesReceived,
        updatedAt: now,
        supplierIdsResponded: responded,
        lowestBid: lowestBid,
      );
    }

    _notify();
    return quoteId;
  }

  QuoteRequest? getRequest(String id) {
    try {
      return quoteRequests.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> approveCustomerQuote({
    required String quoteId,
    required String requestId,
    required String customerId,
  }) async {
    final requestIndex = quoteRequests.indexWhere((r) => r.id == requestId);
    if (requestIndex < 0) throw Exception('הבקשה לא נמצאה');
    final request = quoteRequests[requestIndex];
    if (request.customerId != customerId) {
      throw Exception('אין הרשאה לאשר הצעה זו');
    }
    if (request.hasApprovedQuote && request.approvedQuoteId != quoteId) {
      throw Exception('כבר אושרה הצעה אחרת לבקשה זו');
    }

    final quoteIndex = supplierQuotes.indexWhere((q) => q.id == quoteId);
    if (quoteIndex < 0) throw Exception('ההצעה לא נמצאה');
    final quote = supplierQuotes[quoteIndex];
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

    final now = DateTime.now();
    supplierQuotes[quoteIndex] = _copyQuote(
      quote,
      status: SupplierQuoteStatus.approved,
      seenOrderBySupplier: false,
    );

    for (var i = 0; i < supplierQuotes.length; i++) {
      final q = supplierQuotes[i];
      if (q.quoteRequestId == requestId &&
          q.id != quoteId &&
          q.status == SupplierQuoteStatus.sent) {
        supplierQuotes[i] =
            _copyQuote(q, status: SupplierQuoteStatus.notSelected);
      }
    }

    quoteRequests[requestIndex] = _copyRequest(
      request,
      status: QuoteRequestStatus.ordered,
      updatedAt: now,
      approvedQuoteId: quoteId,
    );
    _notify();
  }

  Future<void> rejectCustomerQuote({
    required String quoteId,
    required String customerId,
    required String requestId,
  }) async {
    final request = getRequest(requestId);
    if (request == null) throw Exception('הבקשה לא נמצאה');
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

    final quoteIndex = supplierQuotes.indexWhere((q) => q.id == quoteId);
    if (quoteIndex < 0) throw Exception('ההצעה לא נמצאה');
    final quote = supplierQuotes[quoteIndex];
    if (quote.quoteRequestId != request.id) {
      throw Exception('ההצעה אינה שייכת לבקשה זו');
    }
    if (quote.status != SupplierQuoteStatus.sent) {
      throw Exception('לא ניתן לדחות הצעה בסטטוס זה');
    }
    supplierQuotes[quoteIndex] = _copyQuote(
      quote,
      status: SupplierQuoteStatus.rejected,
    );
    _notify();
  }

  Future<void> markSupplierOrderShipped({
    required String quoteId,
    required String requestId,
    required String supplierId,
  }) async {
    final quoteIndex = supplierQuotes.indexWhere((q) => q.id == quoteId);
    if (quoteIndex < 0) throw Exception('ההזמנה לא נמצאה');
    final quote = supplierQuotes[quoteIndex];
    if (quote.supplierId != supplierId) {
      throw Exception('אין הרשאה לעדכן הזמנה זו');
    }
    if (quote.status != SupplierQuoteStatus.approved) {
      throw Exception('ניתן לסמן כנשלח רק הזמנה שאושרה');
    }

    final now = DateTime.now();
    supplierQuotes[quoteIndex] =
        _copyQuote(quote, status: SupplierQuoteStatus.shipped);

    final requestIndex = quoteRequests.indexWhere((r) => r.id == requestId);
    if (requestIndex >= 0) {
      final r = quoteRequests[requestIndex];
      quoteRequests[requestIndex] = _copyRequest(
        r,
        status: QuoteRequestStatus.shipped,
        updatedAt: now,
      );
    }
    _notify();
  }

  Future<void> markCustomerReceivedQuotesSeen(String customerId) async {
    final requestIds = quoteRequests
        .where((r) => r.customerId == customerId)
        .map((r) => r.id)
        .toSet();
    for (var i = 0; i < supplierQuotes.length; i++) {
      final q = supplierQuotes[i];
      if (!requestIds.contains(q.quoteRequestId)) continue;
      if (q.seenByCustomer) continue;
      supplierQuotes[i] = _copyQuote(q, seenByCustomer: true);
    }
    _notify();
  }

  Future<void> markCustomerRequestsStatusSeen(
    String customerId, {
    Set<String>? requestIds,
  }) async {
    for (var i = 0; i < quoteRequests.length; i++) {
      final r = quoteRequests[i];
      if (r.customerId != customerId) continue;
      if (requestIds != null && !requestIds.contains(r.id)) continue;
      quoteRequests[i] = _copyRequest(
        r,
        customerLastSeenStatus: r.status.firestoreValue,
        updatedAt: DateTime.now(),
      );
    }
    _notify();
  }

  Future<void> markIncomingRequestsSeenBySupplier(String supplierId) async {
    for (var i = 0; i < quoteRequests.length; i++) {
      final r = quoteRequests[i];
      if (r.hasSupplierResponded(supplierId)) continue;
      if (!QuoteRequestStatusExtension.openForSupplierFirestoreValues()
          .contains(r.status.firestoreValue)) {
        continue;
      }
      if (r.seenBySupplierIds.contains(supplierId)) continue;
      quoteRequests[i] = _copyRequest(
        r,
        seenBySupplierIds: [...r.seenBySupplierIds, supplierId],
      );
    }
    _notify();
  }

  Future<void> markSupplierOrderSeen({
    required String supplierId,
    required String quoteId,
  }) async {
    final index = supplierQuotes.indexWhere((q) => q.id == quoteId);
    if (index < 0) return;
    final q = supplierQuotes[index];
    if (q.supplierId != supplierId) return;
    if (q.status != SupplierQuoteStatus.approved) return;
    supplierQuotes[index] = _copyQuote(q, seenOrderBySupplier: true);
    _notify();
  }

  Future<void> markSupplierOrdersToFulfillSeen(String supplierId) async {
    for (var i = 0; i < supplierQuotes.length; i++) {
      final q = supplierQuotes[i];
      if (q.supplierId != supplierId) continue;
      if (q.status != SupplierQuoteStatus.approved) continue;
      if (q.seenOrderBySupplier) continue;
      supplierQuotes[i] = _copyQuote(q, seenOrderBySupplier: true);
    }
    _notify();
  }

  SupplierQuote _copyQuote(
    SupplierQuote quote, {
    String? status,
    bool? seenByCustomer,
    bool? seenOrderBySupplier,
  }) {
    return SupplierQuote(
      id: quote.id,
      quoteRequestId: quote.quoteRequestId,
      supplierId: quote.supplierId,
      supplierName: quote.supplierName,
      supplierType: quote.supplierType,
      deliveryTime: quote.deliveryTime,
      notes: quote.notes,
      totalPrice: quote.totalPrice,
      status: status ?? quote.status,
      createdAt: quote.createdAt,
      items: quote.items,
      seenByCustomer: seenByCustomer ?? quote.seenByCustomer,
      seenOrderBySupplier: seenOrderBySupplier ?? quote.seenOrderBySupplier,
      isTenderBid: quote.isTenderBid,
      bidVersion: quote.bidVersion,
      subtotal: quote.subtotal,
      deliveryCost: quote.deliveryCost,
      vatRate: quote.vatRate,
      vatAmount: quote.vatAmount,
      totalInclVat: quote.totalInclVat,
      validUntil: quote.validUntil,
      paymentTerms: quote.paymentTerms,
    );
  }

  QuoteRequest _copyRequest(
    QuoteRequest request, {
    QuoteRequestStatus? status,
    DateTime? updatedAt,
    List<String>? supplierIdsResponded,
    String? approvedQuoteId,
    String? customerLastSeenStatus,
    List<String>? seenBySupplierIds,
    List<QuoteRequestItem>? items,
    String? notes,
    RequestType? requestType,
    DateTime? tenderEndTime,
    double? lowestBid,
    bool? tenderClosed,
  }) {
    return QuoteRequest(
      id: request.id,
      customerId: request.customerId,
      customerName: request.customerName,
      customerPhone: request.customerPhone,
      customerCity: request.customerCity,
      customerType: request.customerType,
      status: status ?? request.status,
      notes: notes ?? request.notes,
      createdAt: request.createdAt,
      updatedAt: updatedAt ?? request.updatedAt,
      items: items ?? request.items,
      supplierIdsResponded:
          supplierIdsResponded ?? request.supplierIdsResponded,
      approvedQuoteId: approvedQuoteId ?? request.approvedQuoteId,
      customerLastSeenStatus:
          customerLastSeenStatus ?? request.customerLastSeenStatus,
      seenBySupplierIds: seenBySupplierIds ?? request.seenBySupplierIds,
      requestType: requestType ?? request.requestType,
      tenderEndTime: tenderEndTime ?? request.tenderEndTime,
      lowestBid: lowestBid ?? request.lowestBid,
      tenderClosed: tenderClosed ?? request.tenderClosed,
    );
  }

  void dispose() {
    _authController.close();
    _changeController.close();
  }
}
