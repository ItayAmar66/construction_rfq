import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../config/app_mode.dart';
import '../models/quote_request.dart';

void handleQuoteStreamError(Object error, StackTrace stackTrace) {
  if (kDebugMode) debugPrint('[Quote] stream error: $error');
  if (AppMode.isDemoMode) {
    AppMode.tryFallbackToDemo(error);
  }
  throw Exception(FirebaseErrorHelper.toHebrewMessage(error));
}

T handleQuoteFutureError<T>(
  Object error, {
  required T Function() fallback,
}) {
  if (kDebugMode) debugPrint('[Quote] future error: $error');
  if (AppMode.isDemoMode) {
    AppMode.tryFallbackToDemo(error);
    return fallback();
  }
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
  throw Exception(FirebaseErrorHelper.toHebrewMessage(error));
}

List<QuoteRequest> mapQuoteRequests(
  QuerySnapshot<Map<String, dynamic>> snapshot,
) {
  final list =
      snapshot.docs.map((d) => QuoteRequest.fromMap(d.id, d.data())).toList();
  list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return list;
}
