import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../config/app_mode.dart';
import '../models/quote_request.dart';
import '../utils/safe_doc_parsing.dart';

void absorbQuoteStreamError(Object error, StackTrace stackTrace) {
  if (kDebugMode) debugPrint('[Quote] stream error (absorbed): $error');
  if (AppMode.isDemoMode) {
    AppMode.tryFallbackToDemo(error);
  }
}

void handleQuoteStreamError(Object error, StackTrace stackTrace) {
  if (kDebugMode) debugPrint('[Quote] stream error: $error');
  if (AppMode.isDemoMode) {
    AppMode.tryFallbackToDemo(error);
  }
  throw Exception(FirebaseErrorHelper.toHebrewMessage(error));
}

bool isFirestorePermissionDenied(Object error) =>
    error is FirebaseException && error.code == 'permission-denied';

/// Hebrew [Exception]s raised intentionally inside quote submit flows must not
/// be passed through [handleQuoteFutureError] (that maps them to a generic
/// data-loading message).
bool isIntentionalQuoteBusinessException(Object error) {
  if (error is FirebaseException) return false;
  if (error is Exception) {
    final text = error.toString();
    return text.startsWith('Exception: ') &&
        !text.contains('[cloud_firestore/') &&
        !text.contains('FirebaseException');
  }
  return false;
}

T handleQuoteFutureError<T>(
  Object error, {
  required T Function() fallback,
}) {
  if (kDebugMode) {
    if (error is FirebaseException) {
      debugPrint(
        '[Quote] future error: ${error.code} ${error.message ?? error}',
      );
    } else {
      debugPrint('[Quote] future error: $error');
    }
  }
  if (AppMode.isDemoMode) {
    AppMode.tryFallbackToDemo(error);
    return fallback();
  }
  // Preserve intentional Hebrew business-rule messages (permission denied,
  // already approved, not open, etc.) instead of collapsing them into the
  // generic data-loading message.
  if (isIntentionalQuoteBusinessException(error)) throw error;
  throw Exception(FirebaseErrorHelper.toHebrewMessage(error));
}

Future<void> handleQuoteFutureErrorVoid(
  Object error, {
  required Future<void> Function() fallback,
}) async {
  if (kDebugMode) debugPrint('[Quote] future error: $error');
  if (AppMode.isDemoMode) {
    AppMode.tryFallbackToDemo(error);
    return fallback();
  }
  // Preserve intentional Hebrew business-rule messages instead of collapsing
  // them into the generic data-loading message.
  if (isIntentionalQuoteBusinessException(error)) throw error;
  throw Exception(FirebaseErrorHelper.toHebrewMessage(error));
}

List<QuoteRequest> mapQuoteRequests(
  QuerySnapshot<Map<String, dynamic>> snapshot,
) {
  final list = parseDocsSafely(
    snapshot.docs,
    (d) => QuoteRequest.fromMap(d.id, d.data()),
    label: 'quoteRequest',
  );
  list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return list;
}
