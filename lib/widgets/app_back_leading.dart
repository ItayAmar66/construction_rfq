import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../utils/count_badge.dart';
import '../utils/dashboard_navigation.dart';
import '../utils/hebrew_strings.dart';
import 'count_badge.dart';

/// Navigation helpers for secondary screens.
class AppNavigation {
  const AppNavigation._();

  /// Pops the route stack, or [homeRoute] when there is nothing to pop.
  /// When [preferHome] is true (e.g. opened from dashboard), always returns home.
  static void backOrHome(
    BuildContext context, {
    String homeRoute = '/home',
    bool preferHome = false,
  }) {
    if (preferHome) {
      context.go(homeRoute);
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(homeRoute);
    }
  }
}

/// RTL back control for app bars (Hebrew layout).
class AppBackLeading extends StatelessWidget {
  const AppBackLeading({
    super.key,
    this.homeRoute = '/home',
    this.showLabel = true,
    this.preferHomeOnBack = false,
  });

  final String homeRoute;
  final bool showLabel;
  final bool preferHomeOnBack;

  @override
  Widget build(BuildContext context) {
    final fromDashboard = isOpenedFromDashboard(context);
    final preferHome = preferHomeOnBack || fromDashboard;
    final shouldShow = preferHome || context.canPop();

    if (!shouldShow) {
      return const SizedBox.shrink();
    }

    final onPressed = () => AppNavigation.backOrHome(
          context,
          homeRoute: homeRoute,
          preferHome: preferHome,
        );

    if (!showLabel) {
      return IconButton(
        icon: const Icon(Icons.arrow_forward),
        tooltip: HebrewStrings.back,
        onPressed: onPressed,
      );
    }

    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.arrow_forward, color: Colors.white),
      label: const Text(
        HebrewStrings.back,
        style: TextStyle(color: Colors.white),
      ),
    );
  }
}

/// App bar for secondary screens with a standard back button.
class SecondaryAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SecondaryAppBar({
    super.key,
    required this.title,
    this.homeRoute = '/home',
    this.actions,
    this.showBackLabel = true,
    this.count,
    this.preferHomeOnBack = false,
  });

  final String title;
  final String homeRoute;
  final List<Widget>? actions;
  final bool showBackLabel;

  /// Optional live count badge beside the title.
  final int? count;

  /// When true, back always navigates to [homeRoute] (dashboard).
  final bool preferHomeOnBack;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final badgeLabel = count != null ? countBadgeLabel(count!) : null;
    final fromDashboard = isOpenedFromDashboard(context);
    final preferHome = preferHomeOnBack || fromDashboard;
    final shouldShowBack = preferHome || context.canPop();

    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (badgeLabel != null) ...[
            const SizedBox(width: 8),
            CountBadge(count: count!, compact: true),
          ],
        ],
      ),
      automaticallyImplyLeading: false,
      leading: shouldShowBack
          ? AppBackLeading(
              homeRoute: homeRoute,
              showLabel: showBackLabel,
              preferHomeOnBack: preferHomeOnBack,
            )
          : null,
      leadingWidth: shouldShowBack ? (showBackLabel ? 88 : 56) : 0,
      actions: actions,
    );
  }
}
