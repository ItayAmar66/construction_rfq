import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../utils/count_badge.dart';
import '../utils/dashboard_navigation.dart';
import '../utils/hebrew_strings.dart';

import 'status_chip.dart';
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

    void onPressed() => AppNavigation.backOrHome(
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
/// One link in a [SecondaryAppBar] breadcrumb trail.
class BreadcrumbItem {
  const BreadcrumbItem(this.label, {this.onTap});

  final String label;
  final VoidCallback? onTap;
}

class SecondaryAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SecondaryAppBar({
    super.key,
    required this.title,
    this.homeRoute = '/home',
    this.actions,
    this.showBackLabel = true,
    this.count,
    this.preferHomeOnBack = false,
    this.breadcrumbs,
  });

  final String title;
  final String homeRoute;
  final List<Widget>? actions;
  final bool showBackLabel;

  /// Optional live count badge beside the title.
  final int? count;

  /// When true, back always navigates to [homeRoute] (dashboard).
  final bool preferHomeOnBack;

  /// Optional trail shown above the title, e.g. contractor › project.
  final List<BreadcrumbItem>? breadcrumbs;

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (breadcrumbs != null && breadcrumbs!.isNotEmpty ? 18 : 0),
      );

  @override
  Widget build(BuildContext context) {
    final badgeLabel = count != null ? countBadgeLabel(count!) : null;
    final fromDashboard = isOpenedFromDashboard(context);
    final preferHome = preferHomeOnBack || fromDashboard;
    final shouldShowBack = preferHome || context.canPop();
    final trail = breadcrumbs;

    return AppBar(
      toolbarHeight: preferredSize.height,
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (trail != null && trail.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (var i = 0; i < trail.length; i++) ...[
                    if (i > 0)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(Icons.chevron_left, size: 14, color: Colors.white70),
                      ),
                    GestureDetector(
                      onTap: trail[i].onTap,
                      child: Text(
                        trail[i].label,
                        style: const TextStyle(fontSize: 11.5, color: Colors.white70),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          Row(
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
                StatusChip.count(count!, dense: true),
              ],
            ],
          ),
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
