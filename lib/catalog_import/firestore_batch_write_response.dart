import 'dart:convert';
import 'dart:io';

/// Validates Firestore REST `:batchWrite` responses for per-write failures.
abstract final class FirestoreBatchWriteResponse {
  /// Throws [HttpException] when any entry in `status[]` reports a non-OK code.
  static void ensureAllWritesSucceeded({
    required String responseBody,
    required String operation,
    Uri? uri,
  }) {
    final trimmed = responseBody.trim();
    if (trimmed.isEmpty) return;

    final decoded = jsonDecode(trimmed);
    if (decoded is! Map<String, dynamic>) return;

    final statuses = decoded['status'];
    if (statuses is! List || statuses.isEmpty) return;

    for (var i = 0; i < statuses.length; i++) {
      final entry = statuses[i];
      if (entry is! Map) continue;
      final code = entry['code'];
      if (code == null || code == 0) continue;
      final message = entry['message']?.toString() ?? responseBody;
      throw HttpException(
        '$operation partial failure at write $i (code $code): $message',
        uri: uri,
      );
    }
  }
}
