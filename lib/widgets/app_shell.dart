import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';
import '../utils/app_theme.dart';
import 'content_max_width.dart';

/// Shell routes that should not highlight any nav item.
const _orphanShellRoutes = <String>{
  '/active-orders',
};

const _desktopBreakpoint = 900.0;

/// Adaptive shell: bottom nav (mobile) / side rail (desktop), RTL.
class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.child,
    this.currentPath,
  });

  final Widget child;
  final String? currentPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final isSupplier = user?.userType.isSupplier ?? false;
    final location = currentPath ?? GoRouterState.of(context).matchedLocation;

    final destinations = isSupplier
        ? _supplierDestinations(location)
        : _customerDestinations(location);

    final isOrphan = _orphanShellRoutes.any(
      (r) => location == r || location.startsWith('$r/'),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= _desktopBreakpoint;
        final content = ContentMaxWidth(child: child);

        if (useRail) {
          return Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: Row(
                children: [
                  Expanded(child: content),
                  _SideNavigationRail(
                    destinations: destinations,
                    location: location,
                    isOrphan: isOrphan,
                  ),
                ],
              ),
            ),
          );
        }

        final navTheme = isOrphan
            ? NavigationBarThemeData(
                indicatorColor: Colors.transparent,
                iconTheme: WidgetStateProperty.resolveWith((_) {
                  return const IconThemeData(
                    color: AppTheme.textSecondary,
                    size: 22,
                  );
                }),
                labelTextStyle: WidgetStateProperty.resolveWith((_) {
                  return const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  );
                }),
              )
            : null;

        return Scaffold(
          body: content,
          bottomNavigationBar: Material(
            elevation: 12,
            shadowColor:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
            child: Theme(
              data: navTheme != null
                  ? Theme.of(context).copyWith(navigationBarTheme: navTheme)
                  : Theme.of(context),
              child: NavigationBar(
                selectedIndex: destinations.selectedIndex,
                onDestinationSelected: (i) {
                  final path = destinations.paths[i];
                  if (path != location) context.go(path);
                },
                destinations: [
                  for (final d in destinations.items)
                    NavigationDestination(
                      icon: Icon(d.icon),
                      label: d.label,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  _NavConfig _customerDestinations(String location) {
    const paths = [
      '/home',
      '/my-requests',
      '/received-quotes',
      '/catalog',
      '/profile',
    ];
    const items = [
      _NavItem('בית', Icons.space_dashboard_outlined),
      _NavItem('בקשות', Icons.assignment_outlined),
      _NavItem('הצעות', Icons.compare_arrows),
      _NavItem('קטלוג', Icons.inventory_2_outlined),
      _NavItem('פרופיל', Icons.person_outline),
    ];
    return _NavConfig(
      paths: paths,
      items: items,
      selectedIndex: _indexFor(location, paths),
    );
  }

  _NavConfig _supplierDestinations(String location) {
    const paths = [
      '/home',
      '/incoming',
      '/supplier/orders',
      '/sent-quotes',
      '/profile',
    ];
    const items = [
      _NavItem('בית', Icons.space_dashboard_outlined),
      _NavItem('נכנסות', Icons.inbox_outlined),
      _NavItem('הזמנות', Icons.local_shipping_outlined),
      _NavItem('הצעות', Icons.send_outlined),
      _NavItem('פרופיל', Icons.person_outline),
    ];
    return _NavConfig(
      paths: paths,
      items: items,
      selectedIndex: _indexFor(location, paths),
    );
  }

  int _indexFor(String location, List<String> paths) {
    if (_orphanShellRoutes.any(
      (r) => location == r || location.startsWith('$r/'),
    )) {
      return 0;
    }
    for (var i = 0; i < paths.length; i++) {
      if (location == paths[i] || location.startsWith('${paths[i]}/')) {
        return i;
      }
    }
    return 0;
  }
}

class _SideNavigationRail extends StatelessWidget {
  const _SideNavigationRail({
    required this.destinations,
    required this.location,
    required this.isOrphan,
  });

  final _NavConfig destinations;
  final String location;
  final bool isOrphan;

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      extended: true,
      minExtendedWidth: 168,
      selectedIndex: isOrphan ? 0 : destinations.selectedIndex,
      onDestinationSelected: (i) {
        final path = destinations.paths[i];
        if (path != location) context.go(path);
      },
      labelType: NavigationRailLabelType.none,
      backgroundColor: AppTheme.cardColor,
      indicatorColor: AppTheme.teal.withValues(alpha: 0.12),
      selectedIconTheme: const IconThemeData(color: AppTheme.navy, size: 22),
      unselectedIconTheme: IconThemeData(
        color: AppTheme.textSecondary.withValues(alpha: 0.85),
        size: 22,
      ),
      destinations: [
        for (final d in destinations.items)
          NavigationRailDestination(
            icon: Icon(d.icon),
            label: Text(
              d.label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
      ],
    );
  }
}

class _NavConfig {
  const _NavConfig({
    required this.paths,
    required this.items,
    required this.selectedIndex,
  });
  final List<String> paths;
  final List<_NavItem> items;
  final int selectedIndex;
}

class _NavItem {
  const _NavItem(this.label, this.icon);
  final String label;
  final IconData icon;
}
