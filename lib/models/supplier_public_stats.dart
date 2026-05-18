import '../utils/firestore_parsing.dart';

/// Denormalized supplier trust metrics (users.stats in Firestore).
class SupplierPublicStats {
  const SupplierPublicStats({
    required this.completedDeals,
    required this.avgResponseHours,
    required this.winRatePercent,
  });

  final int completedDeals;
  final int avgResponseHours;
  final int winRatePercent;

  static const SupplierPublicStats defaults = SupplierPublicStats(
    completedDeals: 0,
    avgResponseHours: 24,
    winRatePercent: 0,
  );

  factory SupplierPublicStats.fromMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return defaults;
    return SupplierPublicStats(
      completedDeals:
          FirestoreParsing.parseInt(map['completedDeals'], defaultValue: 0),
      avgResponseHours: FirestoreParsing.parseInt(
        map['avgResponseHours'],
        defaultValue: 24,
      ),
      winRatePercent:
          FirestoreParsing.parseInt(map['winRatePercent'], defaultValue: 0),
    );
  }

  Map<String, dynamic> toMap() => {
        'completedDeals': completedDeals,
        'avgResponseHours': avgResponseHours,
        'winRatePercent': winRatePercent,
      };
}
