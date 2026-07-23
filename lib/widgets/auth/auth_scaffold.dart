import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../utils/app_theme.dart';
import '../../utils/constants.dart';

/// Shared visual language for the authentication surfaces (login, register,
/// forgot-password, pending-approval, splash). A deep navy backdrop with an
/// elevated white card — matches the Bonim design source of truth.
///
/// Presentation layer only: these widgets carry no auth or Firebase logic.

/// Deep navy backdrop shared by every auth surface.
const BoxDecoration authBackdropDecoration = BoxDecoration(
  gradient: RadialGradient(
    center: Alignment(0.55, -1),
    radius: 1.35,
    colors: [AppTheme.navy, AppTheme.navyDark],
  ),
);

/// Full-screen navy gradient with a centered, scrollable elevated white card.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.child,
    this.maxWidth = 448,
    this.cardPadding = const EdgeInsets.fromLTRB(28, 32, 28, 30),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry cardPadding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: authBackdropDecoration,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 28,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        child: Container(
                          width: double.infinity,
                          padding: cardPadding,
                          decoration: BoxDecoration(
                            color: AppTheme.cardColor,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    AppTheme.navyDark.withValues(alpha: 0.42),
                                blurRadius: 48,
                                offset: const Offset(0, 22),
                              ),
                            ],
                          ),
                          child: child,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Brand lockup — amber "ב" monogram + wordmark. [onDark] flips the treatment
/// for use directly on the navy backdrop (splash).
class AuthBrandmark extends StatelessWidget {
  const AuthBrandmark({super.key, this.onDark = false, this.size = 44});

  final bool onDark;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: onDark ? AppTheme.amber : AppTheme.navy,
            borderRadius: BorderRadius.circular(size * 0.26),
          ),
          alignment: Alignment.center,
          child: Text(
            'ב',
            style: GoogleFonts.heebo(
              fontSize: size * 0.5,
              fontWeight: FontWeight.w800,
              height: 1,
              color: onDark ? AppTheme.navy : AppTheme.amber,
            ),
          ),
        ),
        SizedBox(width: size * 0.28),
        Flexible(
          child: Text(
            AppConstants.appName,
            style: GoogleFonts.heebo(
              fontSize: size * 0.43,
              fontWeight: FontWeight.w800,
              color: onDark ? Colors.white : AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Label rendered above an auth input field.
class AuthFieldLabel extends StatelessWidget {
  const AuthFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary.withValues(alpha: 0.82),
            ),
      ),
    );
  }
}

/// Inline error banner used across the auth forms.
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: AppTheme.dangerSurface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppTheme.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.danger,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Primary navy submit button with an inline loading spinner.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      child: loading
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: Colors.white,
              ),
            )
          : (icon == null
              ? Text(label)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 18),
                    const SizedBox(width: 8),
                    Text(label),
                  ],
                )),
    );
  }
}
