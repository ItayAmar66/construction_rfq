import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../analytics/app_analytics.dart';
import '../../providers/providers.dart';
import '../../utils/app_theme.dart';
import '../../utils/auth_logout_flow.dart';
import '../../utils/hebrew_strings.dart';
import '../../utils/user_facing_error.dart';
import '../../widgets/auth/auth_scaffold.dart';
import '../../widgets/design_system/design_system.dart';

/// Shown after registration (or from an invite link) when the signed-in
/// user's email address is not yet verified — firestore.rules requires
/// `emailVerified()` before an org-invitation accept write is allowed.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, this.redirect});

  /// Where to navigate once the address is confirmed verified.
  final String? redirect;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  static const _cooldown = Duration(seconds: 60);

  bool _sending = false;
  bool _checking = false;
  String? _error;
  String? _info;
  DateTime? _lastSentAt;
  Timer? _cooldownTicker;
  int _cooldownSecondsLeft = 0;

  @override
  void dispose() {
    _cooldownTicker?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _lastSentAt = DateTime.now();
    _cooldownSecondsLeft = _cooldown.inSeconds;
    _cooldownTicker?.cancel();
    _cooldownTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      final elapsed = DateTime.now().difference(_lastSentAt!);
      final left = _cooldown.inSeconds - elapsed.inSeconds;
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _cooldownSecondsLeft = left < 0 ? 0 : left);
      if (left <= 0) timer.cancel();
    });
  }

  Future<void> _resend() async {
    setState(() {
      _sending = true;
      _error = null;
      _info = null;
    });
    try {
      await ref.read(authServiceProvider).resendVerificationEmail();
      if (!mounted) return;
      setState(() => _info = 'מייל אימות חדש נשלח');
      _startCooldown();
    } catch (e) {
      if (mounted) setState(() => _error = userFacingError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _checkVerified() async {
    setState(() {
      _checking = true;
      _error = null;
      _info = null;
    });
    try {
      final verified =
          await ref.read(authServiceProvider).refreshVerificationStatus();
      ref.invalidate(authSessionProvider);
      if (!mounted) return;
      if (verified) {
        ref.read(appAnalyticsProvider).track(
          AppAnalyticsEvents.emailVerificationCompleted,
        );
        final redirect = widget.redirect;
        if (redirect != null && redirect.isNotEmpty) {
          context.go(redirect);
        } else {
          context.go('/pending-approval');
        }
      } else {
        setState(() => _info = 'המייל עדיין לא אומת. בדוק את תיבת הדואר שלך');
      }
    } catch (e) {
      if (mounted) setState(() => _error = userFacingError(e));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final email = ref.watch(authSessionProvider).valueOrNull?.profile?.email;
    final canResend = _cooldownSecondsLeft <= 0;

    return AuthScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: AuthBrandmark()),
          const SizedBox(height: 28),
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.amber.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mark_email_unread_outlined,
                  size: 36, color: AppTheme.amberDark),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'נדרש אימות כתובת מייל',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            email == null || email.isEmpty
                ? 'שלחנו קישור אימות למייל שלך. יש לאשר אותו כדי להמשיך.'
                : 'שלחנו קישור אימות ל-$email. יש לאשר אותו כדי להמשיך.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
              height: 1.45,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppTheme.danger, fontWeight: FontWeight.w600),
            ),
          ],
          if (_info != null) ...[
            const SizedBox(height: 16),
            Text(
              _info!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppTheme.teal, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 26),
          PrimaryButton.icon(
            icon: Icons.refresh,
            label: 'בדקתי, המשך',
            isLoading: _checking,
            onPressed: _checking ? null : _checkVerified,
          ),
          const SizedBox(height: 12),
          SecondaryButton(
            label: canResend
                ? 'שלח שוב מייל אימות'
                : 'שלח שוב בעוד $_cooldownSecondsLeft שנ\'',
            onPressed: (_sending || !canResend) ? null : _resend,
          ),
          const SizedBox(height: 20),
          Center(
            child: TextButton(
              onPressed: () => signOutAndGoLogin(context, ref),
              child: Text(HebrewStrings.logout),
            ),
          ),
        ],
      ),
    );
  }
}
