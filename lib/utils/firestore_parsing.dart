/// Safe parsers for Firestore document fields (handles legacy / malformed data).
class FirestoreParsing {
  FirestoreParsing._();

  /// True only when [value] is the bool literal `true`.
  static bool parseBool(dynamic value, {bool defaultValue = false}) {
    if (value is bool) return value;
    return defaultValue;
  }

  static String parseString(dynamic value, {String defaultValue = ''}) {
    if (value == null) return defaultValue;
    if (value is String) return value;
    return value.toString();
  }

  static String? parseNullableString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value.isEmpty ? null : value;
    final text = value.toString();
    return text.isEmpty ? null : text;
  }

  static double parseDouble(dynamic value, {double defaultValue = 0}) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  static int parseInt(dynamic value, {int defaultValue = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  static List<String> parseStringList(dynamic value) {
    if (value == null) return const [];
    if (value is List) {
      return value
          .map((e) => e?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (value is String && value.isNotEmpty) return [value];
    return const [];
  }

  /// Merges legacy [seenBySuppliers] with [seenBySupplierIds].
  static List<String> parseSeenBySupplierIds(Map<String, dynamic> map) {
    final ids = <String>{
      ...parseStringList(map['seenBySupplierIds']),
      ...parseStringList(map['seenBySuppliers']),
    };
    return ids.toList();
  }

  static List<Map<String, dynamic>> parseEmbeddedItemMaps(dynamic value) {
    if (value is! List) return const [];
    final items = <Map<String, dynamic>>[];
    for (final entry in value) {
      if (entry is Map<String, dynamic>) {
        items.add(entry);
      } else if (entry is Map) {
        items.add(Map<String, dynamic>.from(entry));
      }
    }
    return items;
  }

  static DateTime? parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try {
      final asTimestamp = (value as dynamic).toDate();
      if (asTimestamp is DateTime) return asTimestamp;
    } catch (_) {
      // Not a Timestamp — try string parse below.
    }
    if (value is String) return DateTime.tryParse(value);
    return DateTime.tryParse(value.toString());
  }
}
