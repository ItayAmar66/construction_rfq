import 'package:construction_rfq/services/crash_reporter.dart';
import 'package:construction_rfq/utils/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingCrashReporter implements CrashReporter {
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

class _RecordingSink implements LogSink {
  final List<LogLevel> levels = [];

  @override
  void write(LogLevel level, String message,
      {Object? error, StackTrace? stackTrace, String? tag}) {
    levels.add(level);
  }
}

void main() {
  group('AppLogger', () {
    late CrashReporter previous;

    setUp(() {
      previous = CrashReporter.instance;
      AppLogger.sink = null;
    });

    tearDown(() {
      CrashReporter.instance = previous;
      AppLogger.sink = null;
    });

    test('error() forwards to the crash reporter', () {
      final reporter = _RecordingCrashReporter();
      CrashReporter.instance = reporter;

      AppLogger.error('boom', tag: 'Test', error: StateError('x'));

      expect(reporter.errors, hasLength(1));
      expect(reporter.errors.first, isA<StateError>());
    });

    test('info() does not reach the crash reporter', () {
      final reporter = _RecordingCrashReporter();
      CrashReporter.instance = reporter;

      AppLogger.info('all good', tag: 'Test');

      expect(reporter.errors, isEmpty);
    });

    test('all levels are forwarded to a configured sink', () {
      final sink = _RecordingSink();
      AppLogger.sink = sink;

      AppLogger.debug('d');
      AppLogger.info('i');
      AppLogger.warn('w');

      expect(sink.levels,
          containsAll(<LogLevel>[LogLevel.debug, LogLevel.info, LogLevel.warning]));
    });

    test('NoOpCrashReporter accepts calls without throwing', () {
      const reporter = NoOpCrashReporter();
      expect(
        () => reporter.recordError(Exception('e'), StackTrace.current),
        returnsNormally,
      );
    });
  });
}
