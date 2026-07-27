import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../analytics/app_analytics.dart';
import '../config/app_config.dart';
import '../utils/constants.dart';
import 'app_snackbar.dart';
import 'platform_label.dart';

/// Single entry point for every "contact support" action in the app.
///
/// If [AppConfig.supportEmail] is configured, opens a prefilled mailto with
/// safe diagnostic context (app version, platform, current route) — no
/// user/document data. Otherwise (no support inbox configured yet, closed
/// beta default) copies the same diagnostic text to the clipboard so the
/// user can hand it to whoever invited them, instead of a dead-end link.
Future<void> openSupportContact(
  BuildContext context,
  WidgetRef ref, {
  String? route,
}) async {
  ref.read(appAnalyticsProvider).track(AppAnalyticsEvents.supportOpened);

  final diagnostics = _diagnosticsText(route: route);

  if (AppConfig.hasSupportEmail) {
    final uri = Uri(
      scheme: 'mailto',
      path: AppConfig.supportEmail,
      query: 'subject=${Uri.encodeComponent('${AppConstants.appName} — פנייה מהאפליקציה')}'
          '&body=${Uri.encodeComponent(diagnostics)}',
    );
    final launched = await launchUrl(uri);
    if (launched) return;
    if (!context.mounted) return;
  }

  await Clipboard.setData(ClipboardData(text: diagnostics));
  if (!context.mounted) return;
  showAppSnackBar(
    context,
    message: AppConfig.hasSupportEmail
        ? 'לא ניתן היה לפתוח את תוכנת המייל. פרטי הפנייה הועתקו — ניתן לשלוח ידנית.'
        : 'כתובת תמיכה עדיין לא הוגדרה. פרטי הפנייה הועתקו — שתף אותם עם מי שהזמין אותך.',
  );
}

String _diagnosticsText({String? route}) {
  final buffer = StringBuffer()
    ..writeln('אפליקציה: ${AppConstants.appName}')
    ..writeln('גרסה: ${AppConfig.appVersion} (${AppConfig.environmentLabel})')
    ..writeln('פלטפורמה: ${PlatformLabel.current}');
  if (route != null && route.isNotEmpty) {
    buffer.writeln('מסך: $route');
  }
  buffer
    ..writeln()
    ..write('תיאור הבעיה: ');
  return buffer.toString();
}
