import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Closed-beta funnel event names — the only events this app sends.
/// Deliberately narrow: expand only alongside a matching product decision,
/// not ad-hoc from a screen.
abstract final class AppAnalyticsEvents {
  static const registrationStarted = 'registration_started';
  static const registrationCompleted = 'registration_completed';
  static const emailVerificationCompleted = 'email_verification_completed';
  static const invitationOpened = 'invitation_opened';
  static const invitationAccepted = 'invitation_accepted';
  static const invitationFailed = 'invitation_failed';
  static const projectCreated = 'project_created';
  static const rfqDraftStarted = 'rfq_draft_started';
  static const rfqSent = 'rfq_sent';
  static const supplierViewedRfq = 'supplier_viewed_rfq';
  static const quoteSubmitted = 'quote_submitted';
  static const quoteApproved = 'quote_approved';
  static const quoteRejected = 'quote_rejected';
  static const orderShipped = 'order_shipped';
  static const deliveryConfirmed = 'delivery_confirmed';
  static const supportOpened = 'support_opened';
}

/// App-wide (non-catalog) analytics hook. Same shape as
/// [CatalogRfqAnalytics] deliberately — one simple `track(name, params)`
/// contract app-wide, swappable per sink.
///
/// Callers MUST NOT pass names, emails, phone numbers, free text, or full
/// document ids in [params] — only short categorical values (status, role,
/// counts, booleans).
abstract class AppAnalytics {
  void track(String name, [Map<String, Object?>? params]);
}

class NoOpAppAnalytics implements AppAnalytics {
  const NoOpAppAnalytics();

  @override
  void track(String name, [Map<String, Object?>? params]) {}
}

class DebugAppAnalytics implements AppAnalytics {
  const DebugAppAnalytics();

  @override
  void track(String name, [Map<String, Object?>? params]) {
    if (kDebugMode) {
      debugPrint('[analytics] $name ${params ?? {}}');
    }
  }
}

/// Forwards to Firebase Analytics. Firebase param values must be
/// String/num/bool — non-conforming values are stringified defensively so a
/// bad call site can't throw at runtime.
class FirebaseAppAnalytics implements AppAnalytics {
  FirebaseAppAnalytics(this._analytics);

  final FirebaseAnalytics _analytics;

  @override
  void track(String name, [Map<String, Object?>? params]) {
    final sanitized = <String, Object>{};
    params?.forEach((key, value) {
      if (value == null) return;
      sanitized[key] =
          value is String || value is num || value is bool ? value : value.toString();
    });
    unawaited(_analytics.logEvent(
      name: name,
      parameters: sanitized.isEmpty ? null : sanitized,
    ));
  }
}

/// Selection rule mirroring [resolveCrashReporter]'s shape — pure/testable,
/// no Firebase calls. Unlike Crashlytics, Firebase Analytics supports web,
/// so no platform exclusion is needed here.
bool shouldEnableFirebaseAnalytics({
  required bool analyticsEnabled,
  required bool useFirebase,
}) =>
    analyticsEnabled && useFirebase;

Future<AppAnalytics> resolveAppAnalytics({
  required bool analyticsEnabled,
  required bool useFirebase,
}) async {
  if (!shouldEnableFirebaseAnalytics(
    analyticsEnabled: analyticsEnabled,
    useFirebase: useFirebase,
  )) {
    return kDebugMode ? const DebugAppAnalytics() : const NoOpAppAnalytics();
  }
  try {
    return FirebaseAppAnalytics(FirebaseAnalytics.instance);
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[analytics] Firebase Analytics init failed, staying on NoOp: $e');
    }
    return const NoOpAppAnalytics();
  }
}

/// App-wide analytics provider. Overridden in `main.dart` after resolving
/// the real sink; defaults to [NoOpAppAnalytics] so tests/widget previews
/// never need to override it explicitly.
final appAnalyticsProvider = Provider<AppAnalytics>(
  (ref) => const NoOpAppAnalytics(),
);
