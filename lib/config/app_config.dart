import 'package:flutter/foundation.dart';

/// Deployment environment tiers.
enum AppEnvironment { dev, staging, prod }

/// Central, build-time application configuration.
///
/// Values are supplied at compile time via `--dart-define`, so a single
/// codebase can target dev / staging / prod without code edits. Defaults keep
/// local developer builds working with zero flags.
///
/// Example:
/// ```sh
/// flutter build web --release \
///   --dart-define=APP_ENV=prod \
///   --dart-define=APP_VERSION=1.2.0
/// ```
abstract final class AppConfig {
  const AppConfig._();

  /// Marketing version string. Keep in sync with `pubspec.yaml` `version:`.
  /// Overridable at build time so CI can stamp the real release version.
  static const String appVersion =
      String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');

  static const String _rawEnv =
      String.fromEnvironment('APP_ENV', defaultValue: 'dev');

  /// Resolved environment tier (defaults to [AppEnvironment.dev]).
  static AppEnvironment get environment {
    switch (_rawEnv.toLowerCase()) {
      case 'prod':
      case 'production':
        return AppEnvironment.prod;
      case 'staging':
      case 'stage':
        return AppEnvironment.staging;
      default:
        return AppEnvironment.dev;
    }
  }

  static bool get isProd => environment == AppEnvironment.prod;
  static bool get isStaging => environment == AppEnvironment.staging;
  static bool get isDev => environment == AppEnvironment.dev;

  /// Short label for diagnostics / debug banners.
  static String get environmentLabel {
    switch (environment) {
      case AppEnvironment.prod:
        return 'prod';
      case AppEnvironment.staging:
        return 'staging';
      case AppEnvironment.dev:
        return 'dev';
    }
  }

  /// Whether verbose diagnostics should be surfaced. Never in a prod release.
  static bool get verboseDiagnostics => kDebugMode || !isProd;

  /// Operating entity's legal name for in-app legal copy. Overridable at
  /// build time once the entity is finalized
  /// (`--dart-define=COMPANY_LEGAL_NAME=...`) — the default is an honest
  /// beta-stage label, not a fabricated legal name.
  static const String companyLegalName = String.fromEnvironment(
    'COMPANY_LEGAL_NAME',
    defaultValue: 'צוות בקשות הצעת מחיר (גרסת בטא)',
  );

  /// Support contact address surfaced in legal copy and the in-app "contact
  /// support" action. Overridable at build time
  /// (`--dart-define=SUPPORT_EMAIL=...`) once a real support inbox exists.
  ///
  /// Deliberately empty by default rather than a fabricated domain — an
  /// invented address could silently misdirect a user's report to a mailbox
  /// nobody owns. [hasSupportEmail] callers should fall back to a
  /// copy-diagnostics flow when this is empty.
  static const String supportEmail =
      String.fromEnvironment('SUPPORT_EMAIL', defaultValue: '');

  static bool get hasSupportEmail => supportEmail.isNotEmpty;

  /// One-line summary for startup logs (no PII).
  static String get summary =>
      'env=$environmentLabel version=$appVersion release=$kReleaseMode';
}
