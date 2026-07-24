import 'package:construction_rfq/utils/firestore_parsing.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stand-in for a Firestore `Timestamp` (which exposes `toDate()`), so we can
/// exercise [FirestoreParsing.parseDate]'s duck-typed Timestamp branch without
/// pulling in cloud_firestore.
class _FakeTimestamp {
  _FakeTimestamp(this._value);
  final DateTime _value;
  DateTime toDate() => _value;
}

/// A value whose `toDate()` throws — mirrors a malformed/legacy field.
class _ThrowingTimestamp {
  DateTime toDate() => throw StateError('boom');
}

void main() {
  group('FirestoreParsing.parseBool', () {
    test('returns the literal bool value', () {
      expect(FirestoreParsing.parseBool(true), isTrue);
      expect(FirestoreParsing.parseBool(false), isFalse);
    });

    test('does NOT coerce truthy strings/numbers — only literal true counts',
        () {
      // Guards against data-integrity bugs where "true"/1 silently read as true.
      expect(FirestoreParsing.parseBool('true'), isFalse);
      expect(FirestoreParsing.parseBool(1), isFalse);
      expect(FirestoreParsing.parseBool('false'), isFalse);
    });

    test('falls back to defaultValue for null / non-bool', () {
      expect(FirestoreParsing.parseBool(null), isFalse);
      expect(FirestoreParsing.parseBool(null, defaultValue: true), isTrue);
      expect(FirestoreParsing.parseBool('x', defaultValue: true), isTrue);
    });
  });

  group('FirestoreParsing.parseString', () {
    test('passes through strings and stringifies other types', () {
      expect(FirestoreParsing.parseString('hi'), 'hi');
      expect(FirestoreParsing.parseString(42), '42');
      expect(FirestoreParsing.parseString(true), 'true');
    });

    test('returns defaultValue for null', () {
      expect(FirestoreParsing.parseString(null), '');
      expect(FirestoreParsing.parseString(null, defaultValue: 'n/a'), 'n/a');
    });
  });

  group('FirestoreParsing.parseNullableString', () {
    test('maps null and empty string to null', () {
      expect(FirestoreParsing.parseNullableString(null), isNull);
      expect(FirestoreParsing.parseNullableString(''), isNull);
    });

    test('returns non-empty strings unchanged', () {
      expect(FirestoreParsing.parseNullableString('abc'), 'abc');
    });

    test('stringifies non-string, non-null values', () {
      expect(FirestoreParsing.parseNullableString(7), '7');
    });
  });

  group('FirestoreParsing.parseDouble', () {
    test('converts ints and doubles', () {
      expect(FirestoreParsing.parseDouble(3), 3.0);
      expect(FirestoreParsing.parseDouble(2.5), 2.5);
    });

    test('parses numeric strings', () {
      expect(FirestoreParsing.parseDouble('2.5'), 2.5);
      expect(FirestoreParsing.parseDouble('10'), 10.0);
    });

    test('returns defaultValue for non-numeric strings and null', () {
      expect(FirestoreParsing.parseDouble('abc'), 0.0);
      expect(FirestoreParsing.parseDouble(null), 0.0);
      expect(FirestoreParsing.parseDouble('abc', defaultValue: 9.5), 9.5);
    });
  });

  group('FirestoreParsing.parseInt', () {
    test('returns ints as-is', () {
      expect(FirestoreParsing.parseInt(3), 3);
    });

    test('truncates doubles (does not round)', () {
      expect(FirestoreParsing.parseInt(3.9), 3);
      expect(FirestoreParsing.parseInt(-1.9), -1);
    });

    test('parses integer strings but not decimal strings', () {
      expect(FirestoreParsing.parseInt('42'), 42);
      // int.tryParse('4.2') == null → falls back to default.
      expect(FirestoreParsing.parseInt('4.2'), 0);
      expect(FirestoreParsing.parseInt('4.2', defaultValue: -1), -1);
    });

    test('returns defaultValue for null / non-numeric', () {
      expect(FirestoreParsing.parseInt(null), 0);
      expect(FirestoreParsing.parseInt('abc', defaultValue: 5), 5);
    });
  });

  group('FirestoreParsing.parseStringList', () {
    test('returns empty list for null and non-list, non-string values', () {
      expect(FirestoreParsing.parseStringList(null), isEmpty);
      expect(FirestoreParsing.parseStringList(42), isEmpty);
    });

    test('stringifies list entries and drops empties/nulls', () {
      expect(
        FirestoreParsing.parseStringList(['a', 1, null, '', 'b']),
        ['a', '1', 'b'],
      );
    });

    test('wraps a single non-empty string, empty string yields empty list', () {
      expect(FirestoreParsing.parseStringList('solo'), ['solo']);
      expect(FirestoreParsing.parseStringList(''), isEmpty);
    });
  });

  group('FirestoreParsing.parseSeenBySupplierIds', () {
    test('merges legacy and current fields and de-duplicates', () {
      final result = FirestoreParsing.parseSeenBySupplierIds({
        'seenBySupplierIds': ['a', 'b'],
        'seenBySuppliers': ['b', 'c'],
      });
      expect(result, unorderedEquals(['a', 'b', 'c']));
    });

    test('handles missing fields gracefully', () {
      expect(FirestoreParsing.parseSeenBySupplierIds({}), isEmpty);
    });
  });

  group('FirestoreParsing.parseEmbeddedItemMaps', () {
    test('returns empty list when value is not a list', () {
      expect(FirestoreParsing.parseEmbeddedItemMaps(null), isEmpty);
      expect(FirestoreParsing.parseEmbeddedItemMaps('x'), isEmpty);
    });

    test('keeps map entries and skips non-map entries', () {
      final result = FirestoreParsing.parseEmbeddedItemMaps([
        {'a': 1},
        'not-a-map',
        42,
        {'b': 2},
      ]);
      expect(result, hasLength(2));
      expect(result[0]['a'], 1);
      expect(result[1]['b'], 2);
    });

    test('normalises a plain Map into Map<String, dynamic>', () {
      final raw = <dynamic, dynamic>{'k': 'v'};
      final result = FirestoreParsing.parseEmbeddedItemMaps([raw]);
      expect(result, hasLength(1));
      expect(result.first, isA<Map<String, dynamic>>());
      expect(result.first['k'], 'v');
    });
  });

  group('FirestoreParsing.parseDate', () {
    test('returns null for null', () {
      expect(FirestoreParsing.parseDate(null), isNull);
    });

    test('passes through DateTime values', () {
      final now = DateTime(2026, 1, 15);
      expect(FirestoreParsing.parseDate(now), now);
    });

    test('unwraps a Timestamp-like object via toDate()', () {
      final date = DateTime(2026, 7, 24, 10, 30);
      expect(FirestoreParsing.parseDate(_FakeTimestamp(date)), date);
    });

    test('parses ISO-8601 strings', () {
      expect(
        FirestoreParsing.parseDate('2026-01-15T00:00:00.000'),
        DateTime.parse('2026-01-15T00:00:00.000'),
      );
    });

    test('returns null for unparseable strings', () {
      expect(FirestoreParsing.parseDate('not-a-date'), isNull);
    });

    test('swallows a throwing toDate() and falls back safely', () {
      // toDate() throws → caught → not a String → tryParse(toString()) → null.
      expect(FirestoreParsing.parseDate(_ThrowingTimestamp()), isNull);
    });
  });
}
