/// Encodes/decodes Dart maps for Firestore Emulator REST API field values.
abstract final class FirestoreRestValueEncoder {
  static Map<String, dynamic> encodeFields(Map<String, dynamic> dartMap) {
    final fields = <String, dynamic>{};
    for (final entry in dartMap.entries) {
      final encoded = encodeValue(entry.value);
      if (encoded != null) {
        fields[entry.key] = encoded;
      }
    }
    return fields;
  }

  static Map<String, dynamic>? encodeValue(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      return {'stringValue': value};
    }
    if (value is bool) {
      return {'booleanValue': value};
    }
    if (value is int) {
      return {'integerValue': value.toString()};
    }
    if (value is double) {
      return {'doubleValue': value};
    }
    if (value is DateTime) {
      return {'timestampValue': value.toUtc().toIso8601String()};
    }
    if (value is List) {
      final values = <Map<String, dynamic>>[];
      for (final item in value) {
        final enc = encodeValue(item);
        if (enc != null) values.add(enc);
      }
      return {
        'arrayValue': {'values': values},
      };
    }
    if (value is Map) {
      final inner = <String, dynamic>{};
      value.forEach((k, v) {
        final enc = encodeValue(v);
        if (enc != null) inner[k.toString()] = enc;
      });
      return {'mapValue': {'fields': inner}};
    }
    final typeName = value.runtimeType.toString();
    if (typeName.contains('FieldValue') || typeName.contains('Timestamp')) {
      return null;
    }
    return {'stringValue': value.toString()};
  }

  static Map<String, dynamic> decodeFields(Map<String, dynamic>? fields) {
    if (fields == null) return {};
    final out = <String, dynamic>{};
    fields.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        out[key] = decodeValue(value);
      }
    });
    return out;
  }

  static dynamic decodeValue(Map<String, dynamic> encoded) {
    if (encoded.containsKey('nullValue')) return null;
    if (encoded.containsKey('stringValue')) return encoded['stringValue'];
    if (encoded.containsKey('booleanValue')) return encoded['booleanValue'];
    if (encoded.containsKey('integerValue')) {
      return int.tryParse(encoded['integerValue'].toString()) ??
          encoded['integerValue'];
    }
    if (encoded.containsKey('doubleValue')) {
      final d = encoded['doubleValue'];
      return d is num ? d.toDouble() : double.tryParse(d.toString());
    }
    if (encoded.containsKey('timestampValue')) {
      return encoded['timestampValue'];
    }
    if (encoded.containsKey('arrayValue')) {
      final values = encoded['arrayValue'] as Map<String, dynamic>?;
      final list = values?['values'] as List? ?? [];
      return list
          .map((e) => decodeValue(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    if (encoded.containsKey('mapValue')) {
      final mapVal = encoded['mapValue'] as Map<String, dynamic>?;
      return decodeFields(
        mapVal?['fields'] as Map<String, dynamic>?,
      );
    }
    return null;
  }
}
