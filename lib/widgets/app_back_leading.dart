import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../utils/count_badge.dart';
import '../utils/hebrew_strings.dart';
import 'count_badge.dart';

/// Navigation helpers for secondary screens.
class AppNavigation {
  const AppNavigation._();

  /// Pops the route stack, or [homeRoute] when there is nothing to pop.
  static void backOrHome(
    BuildContext context, {
    String homeRoute = '/home',
  }) {
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
  });

  final String homeRoute;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final onPressed = () => AppNavigation.backOrHome(context, homeRoute: homeRoute);

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
  });

  final String title;
  final String homeRoute;
  final List<Widget>? actions;
  final bool showBackLabel;

  /// Optional live count badge beside the title.
  final int? count;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final badgeLabel = count != null ? countBadgeLabel(count!) : null;

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
      leading: AppBackLeading(
        homeRoute: homeRoute,
        showLabel: showBackLabel,
      ),
      leadingWidth: showBackLabel ? 88 : 56,
      actions: actions,
    );
  }
}
