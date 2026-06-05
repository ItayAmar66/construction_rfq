import '../models/app_user.dart';
import '../models/quote_request.dart';
import '../models/quote_status.dart';
import '../utils/supplier_targeting_helpers.dart';

/// Read model for supplier capability profile (foundation).
class SupplierCapabilityProfile {
  const SupplierCapabilityProfile({
    required this.supplierId,
    required this.displayName,
    required this.categoryIds,
    required this.serviceAreas,
    required this.city,
  });

  final String supplierId;
  final String displayName;
  final List<String> categoryIds;
  final List<String> serviceAreas;
  final String city;

  factory SupplierCapabilityProfile.fromUser(AppUser user) {
    return SupplierCapabilityProfile(
      supplierId: user.id,
      displayName: user.fullName,
      categoryIds: List.of(user.supplierCategoryIds),
      serviceAreas: List.of(user.serviceAreas),
      city: user.city,
    );
  }

  bool get hasCategories => categoryIds.isNotEmpty;

  bool get hasServiceAreas => serviceAreas.isNotEmpty;

  String get categoriesLabel =>
      categoryIds.isEmpty ? 'כל הקטגוריות' : categoryIds.join(', ');

  String get areasLabel =>
      serviceAreas.isEmpty ? 'כל האזורים' : serviceAreas.join(' · ');
}

abstract final class SupplierCapabilityHelpers {
  static SupplierCapabilityProfile profileFor(AppUser user) {
    return SupplierCapabilityProfile.fromUser(user);
  }

  static bool servesCity({
    required AppUser supplier,
    required String city,
  }) {
    return SupplierTargetingHelpers.matchesServiceArea(
      supplier: supplier,
      request: QuoteRequest(
        id: 'probe',
        customerId: 'probe',
        customerName: 'probe',
        customerPhone: '',
        customerCity: city,
        customerType: 'commercial',
        status: QuoteRequestStatus.sent,
        createdAt: DateTime(2024),
      ),
    );
  }
}
