import '../models/quote_request.dart';
import '../models/quote_request_item.dart';

/// User-facing labels for RFQ requests (avoid raw Firestore ids).
class RequestDisplayHelpers {
  RequestDisplayHelpers._();

  static String materialsSummary(
    List<QuoteRequestItem> items, {
    int maxNames = 2,
  }) {
    if (items.isEmpty) return 'ללא פריטים';
    final names = items
        .map((i) => i.productName.trim())
        .where((n) => n.isNotEmpty)
        .toList();
    if (names.isEmpty) return '${items.length} פריטים';
    if (names.length == 1) return names.first;
    if (names.length <= maxNames) return names.join(', ');
    return '${names.take(maxNames).join(', ')} +${names.length - maxNames}';
  }

  static String customerRequestTitle(QuoteRequest request) {
    final notes = request.notes?.trim();
    if (notes != null && notes.isNotEmpty) return notes;
    return materialsSummary(request.items);
  }

  static String customerRequestSubtitle(QuoteRequest request) {
    final parts = <String>[];
    if (request.customerCity.trim().isNotEmpty) {
      parts.add(request.customerCity.trim());
    }
    parts.add('${request.items.length} פריטים');
    return parts.join(' · ');
  }

  static String supplierRequestSubtitle(QuoteRequest request) {
    final parts = <String>[
      request.customerCity.trim(),
      materialsSummary(request.items),
    ];
    final notes = request.notes?.trim();
    if (notes != null && notes.isNotEmpty) {
      parts.add(notes);
    }
    return parts.where((p) => p.isNotEmpty).join(' · ');
  }

  static String activeOrderTitle(QuoteRequest request) =>
      customerRequestTitle(request);

  static String sentQuoteTitle({
    required String? customerName,
    required String? customerCity,
    required List<QuoteRequestItem> requestItems,
  }) {
    final who = (customerName ?? '').trim();
    if (who.isNotEmpty) return who;
    return materialsSummary(requestItems);
  }

  static String sentQuoteSubtitle({
    required String? customerCity,
    required List<QuoteRequestItem> requestItems,
    required String deliveryTime,
  }) {
    final parts = <String>[];
    final city = (customerCity ?? '').trim();
    if (city.isNotEmpty) parts.add(city);
    parts.add(materialsSummary(requestItems));
    if (deliveryTime.trim().isNotEmpty) {
      parts.add('אספקה: ${deliveryTime.trim()}');
    }
    return parts.join(' · ');
  }
}
