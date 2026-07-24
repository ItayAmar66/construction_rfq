import 'package:construction_rfq/services/crash_reporter.dart';
import 'package:construction_rfq/utils/safe_doc_parsing.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Captures errors forwarded through AppLogger.error so we can assert that a
/// dropped corrupted document is reported for production observability.
class _CapturingCrashReporter implements CrashReporter {
  final List<Object> errors = [];

  @override
  void recordError(Object error, StackTrace? stack,
      {String? reason, bool fatal = false}) {
    errors.add(error);
  }

  @override
  void recordFlutterError(FlutterErrorDetails details) {}

  @override
  void setUser(String? id) {}

  @override
  void log(String message) {}
}

void main() {
  group('parseDocsSafely', () {
    test('parses every valid document, preserving order', () {
      final docs = ['1', '2', '3'];
      final result = parseDocsSafely(
        docs,
        (d) => int.parse(d),
        label: 'number',
      );
      expect(result, [1, 2, 3]);
    });

    test('skips a single corrupted document and keeps the good ones', () {
      final previous = CrashReporter.instance;
      final capturing = _CapturingCrashReporter();
      CrashReporter.instance = capturing;
      addTearDown(() => CrashReporter.instance = previous);

      final docs = ['1', 'CORRUPT', '3'];
      final result = parseDocsSafely(
        docs,
        (d) {
          if (d == 'CORRUPT') throw const FormatException('bad doc');
          return int.parse(d);
        },
        label: 'number',
      );

      // The whole list is NOT lost — only the bad row is dropped.
      expect(result, [1, 3]);
      // And the drop is reported so it is observable in production.
      expect(capturing.errors, hasLength(1));
    });

    test('returns an empty list when every document is corrupted', () {
      final docs = ['a', 'b'];
      final result = parseDocsSafely<String, int>(
        docs,
        (_) => throw const FormatException('bad'),
        label: 'number',
      );
      expect(result, isEmpty);
    });

    test('returns a growable list (safe to sort/add afterwards)', () {
      final result = parseDocsSafely(
        ['2', '1'],
        (d) => int.parse(d),
        label: 'number',
      )..sort();
      expect(result, [1, 2]);
      expect(() => result.add(3), returnsNormally);
    });

    test('handles an empty input', () {
      expect(
        parseDocsSafely<String, int>(const [], int.parse, label: 'number'),
        isEmpty,
      );
    });
  });
}
