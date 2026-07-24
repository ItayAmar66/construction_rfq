import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/enterprise_providers.dart';
import '../providers/providers.dart';
import '../utils/app_theme.dart';
import '../utils/breakpoints.dart';
import '../utils/hebrew_strings.dart';
import 'content_max_width.dart';
import 'shell/app_sidebar.dart';
import 'shell/app_topbar.dart';

/// Shell routes that should not highlight any nav item.
const _orphanShellRoutes = <String>{
  '/active-orders',
  '/deliveries',
  '/analytics',
  '/supplier/deliveries',
  '/supplier/analytics',
  '/admin',
};

const _desktopBreakpoint = kShellDesktopBreakpoint;

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
    final showAdmin = ref.watch(showAdminNavProvider);
    final location = currentPath ?? GoRouterState.of(context).matchedLocation;

    final destinations = isSupplier
        ? _supplierDestinations(location, includeAdmin: showAdmin)
        : _customerDestinations(location, includeAdmin: showAdmin);

    final isOrphan = _orphanShellRoutes.any(
      (r) => location == r || location.startsWith('$r/'),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= _desktopBreakpoint;
        final sectionIndex = isOrphan ? 0 : destinations.selectedIndex;
        final sectionLabel = destinations.items[sectionIndex].label;
        final content = ContentMaxWidth(child: child);

        if (useRail) {
          return Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              // Sidebar first -> under RTL it lays out on the start (right)
              // edge, matching the reference; content fills to its left.
              child: Row(
                children: [
                  AppSidebar(
                    destinations: [
                      for (final item in destinations.items)
                        SidebarDestination(item.label, item.icon),
                    ],
                    selectedIndex: isOrphan ? 0 : destinations.selectedIndex,
                    onSelect: (i) {
                      final path = destinations.paths[i];
                      if (path != location) context.go(path);
                    },
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        AppTopBar(sectionLabel: sectionLabel),
                        Expanded(child: content),
                      ],
                    ),
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
          body: Column(
            children: [
              AppTopBar(sectionLabel: sectionLabel, showUserMenu: false),
              Expanded(child: content),
            ],
          ),
          bottomNavigationBar: Material(
            elevation: 12,
            shadowColor:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
            child: Theme(
              data: navTheme != null
                  ? Theme.of(context).copyWith(navigationBarTheme: navTheme)
                  : Theme.of(context),
              child: NavigationBar(
                height: 72,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
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

  _NavConfig _customerDestinations(String location, {bool includeAdmin = false}) {
    final paths = <String>[
      '/home',
      '/my-requests',
      '/received-quotes',
      '/catalog',
      if (includeAdmin) '/admin',
      '/profile',
    ];
    final items = <_NavItem>[
      _NavItem('בית', Icons.space_dashboard_outlined),
      _NavItem('בקשות', Icons.assignment_outlined),
      _NavItem('הצעות', Icons.compare_arrows),
      _NavItem('קטלוג', Icons.inventory_2_outlined),
      if (includeAdmin)
        _NavItem(HebrewStrings.adminConsoleTitle, Icons.admin_panel_settings_outlined),
      _NavItem('פרופיל', Icons.person_outline),
    ];
    return _NavConfig(
      paths: paths,
      items: items,
      selectedIndex: _indexFor(location, paths),
    );
  }

  _NavConfig _supplierDestinations(String location, {bool includeAdmin = false}) {
    final paths = <String>[
      '/home',
      '/supplier/contractors',
      '/incoming',
      '/supplier/orders',
      '/sent-quotes',
      if (includeAdmin) '/admin',
      '/profile',
    ];
    final items = <_NavItem>[
      _NavItem('בית', Icons.space_dashboard_outlined),
      _NavItem('קבלנים', Icons.business_outlined),
      _NavItem('נכנסות', Icons.inbox_outlined),
      _NavItem('הזמנות', Icons.local_shipping_outlined),
      _NavItem('הצעות', Icons.send_outlined),
      if (includeAdmin)
        _NavItem(HebrewStrings.adminConsoleTitle, Icons.admin_panel_settings_outlined),
      _NavItem('פרופיל', Icons.person_outline),
    ];
    final effectiveLocation = location.startsWith('/supplier/projects')
        ? '/supplier/contractors'
        : location;
    return _NavConfig(
      paths: paths,
      items: items,
      selectedIndex: _indexFor(effectiveLocation, paths),
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
