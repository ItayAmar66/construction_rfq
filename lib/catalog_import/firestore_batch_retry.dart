import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

/// Retry policy for Firestore REST batch writes (production quota safety).
class FirestoreBatchRetryPolicy {
  FirestoreBatchRetryPolicy({
    required this.maxAttempts,
    required this.baseDelayMs,
    required this.maxDelayMs,
    this.retryableStatusCodes = const {429, 500, 502, 503, 504},
    this.sleep = _defaultSleep,
    Random? random,
    this.log,
  }) : random = random ?? Random();

  final int maxAttempts;
  final int baseDelayMs;
  final int maxDelayMs;
  final Set<int> retryableStatusCodes;
  final Future<void> Function(Duration duration) sleep;
  final Random random;
  final void Function(String message)? log;

  static const retryableStatuses = {429, 500, 502, 503, 504};

  /// No retries — emulator default (fast fail).
  factory FirestoreBatchRetryPolicy.none() {
    return FirestoreBatchRetryPolicy(
      maxAttempts: 1,
      baseDelayMs: 0,
      maxDelayMs: 0,
    );
  }

  /// Production defaults with configurable overrides.
  factory FirestoreBatchRetryPolicy.production({
    int maxAttempts = CatalogImportRetryDefaults.maxAttempts,
    int baseDelayMs = CatalogImportRetryDefaults.baseDelayMs,
    int maxDelayMs = CatalogImportRetryDefaults.maxDelayMs,
    void Function(String message)? log,
    Random? random,
    Future<void> Function(Duration duration)? sleep,
  }) {
    return FirestoreBatchRetryPolicy(
      maxAttempts: maxAttempts,
      baseDelayMs: baseDelayMs,
      maxDelayMs: maxDelayMs,
      log: log,
      random: random,
      sleep: sleep ?? _defaultSleep,
    );
  }

  static Future<void> _defaultSleep(Duration duration) =>
      Future<void>.delayed(duration);

  bool isRetryableStatus(int statusCode) =>
      retryableStatusCodes.contains(statusCode);

  Duration delayBeforeRetry({
    required int attempt,
    http.Response? response,
  }) {
    final retryAfter = _parseRetryAfter(response);
    if (retryAfter != null) {
      return retryAfter;
    }

    final exp = baseDelayMs * pow(2, attempt - 1);
    final capped = exp.clamp(0, maxDelayMs.toDouble()).toInt();
    final jitter = capped > 0 ? random.nextInt(capped ~/ 4 + 1) : 0;
    return Duration(milliseconds: capped + jitter);
  }

  Duration? _parseRetryAfter(http.Response? response) {
    if (response == null) return null;
    final header = response.headers['retry-after'];
    if (header == null || header.trim().isEmpty) return null;

    final asSeconds = int.tryParse(header.trim());
    if (asSeconds != null) {
      return Duration(seconds: asSeconds);
    }

    final asDate = HttpDate.parse(header);
    final delta = asDate.difference(DateTime.now().toUtc());
    if (delta.isNegative) return Duration.zero;
    return delta;
  }

  Future<http.Response> postWithRetry({
    required http.Client client,
    required Uri uri,
    required Map<String, String> headers,
    required String body,
    required String operation,
  }) async {
    http.Response? lastResponse;
    Object? lastError;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await client.post(uri, headers: headers, body: body);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return response;
        }

        lastResponse = response;
        if (!isRetryableStatus(response.statusCode) ||
            attempt >= maxAttempts) {
          throw HttpException(
            '$operation failed (${response.statusCode}): ${response.body}',
            uri: uri,
          );
        }

        final wait = delayBeforeRetry(attempt: attempt, response: response);
        log?.call(
          'RETRY $operation attempt $attempt/$maxAttempts '
          '(HTTP ${response.statusCode}); waiting ${wait.inMilliseconds}ms',
        );
        await sleep(wait);
      } catch (e) {
        if (e is HttpException) rethrow;
        lastError = e;
        if (attempt >= maxAttempts) {
          throw HttpException(
            '$operation failed after $maxAttempts attempts: $e',
            uri: uri,
          );
        }
        final wait = delayBeforeRetry(attempt: attempt, response: lastResponse);
        log?.call(
          'RETRY $operation attempt $attempt/$maxAttempts (error: $e); '
          'waiting ${wait.inMilliseconds}ms',
        );
        await sleep(wait);
      }
    }

    if (lastResponse != null) {
      throw HttpException(
        '$operation failed (${lastResponse.statusCode}): ${lastResponse.body}',
        uri: uri,
      );
    }
    throw HttpException(
      '$operation failed after $maxAttempts attempts: $lastError',
      uri: uri,
    );
  }
}

abstract final class CatalogImportRetryDefaults {
  static const int maxAttempts = 10;
  static const int baseDelayMs = 1000;
  static const int maxDelayMs = 120000;
  static const int productionBatchDelayMs = 500;
  static const int productionBatchSize = 150;
}
