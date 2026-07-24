import 'package:flutter/foundation.dart';

import '../services/crash_reporter.dart';

/// Severity levels for [AppLogger].
enum LogLevel { debug, info, warning, error }

/// A destination for structured log records. Implement to forward logs to a
/// remote sink (e.g. a logging backend) in production.
abstract interface class LogSink {
  void write(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  });
}

/// Central logging facade — the single place app code should log through.
///
/// In debug builds records print via [debugPrint]. In every build,
/// [LogLevel.error] records are forwarded to [CrashReporter], and all records
/// are handed to the optional [sink], so production observability has one clean
/// wiring point instead of scattered `debugPrint` calls.
///
/// This replaces ad-hoc `if (kDebugMode) debugPrint(...)`: prefer
/// `AppLogger.info(...)` / `AppLogger.error(...)` in new code.
abstract final class AppLogger {
  const AppLogger._();

  /// Optional additional destination (remote logging). No-op when null.
  static LogSink? sink;

  static void debug(String message, {String? tag}) =>
      _log(LogLevel.debug, message, tag: tag);

  static void info(String message, {String? tag}) =>
      _log(LogLevel.info, message, tag: tag);

  static void warn(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) =>
      _log(LogLevel.warning, message,
          tag: tag, error: error, stackTrace: stackTrace);

  static void error(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) =>
      _log(LogLevel.error, message,
          tag: tag, error: error, stackTrace: stackTrace);

  static void _log(
    LogLevel level,
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (kDebugMode) {
      final prefix = tag == null ? '' : '[$tag] ';
      final suffix = error == null ? '' : ' — $error';
      debugPrint('${level.name.toUpperCase()} $prefix$message$suffix');
      if (stackTrace != null) {
        debugPrint('$stackTrace');
      }
    }
    sink?.write(level, message,
        error: error, stackTrace: stackTrace, tag: tag);
    if (level == LogLevel.error) {
      CrashReporter.instance.recordError(
        error ?? message,
        stackTrace,
        reason: message,
      );
    }
  }
}
