import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import '../../utils/app_theme.dart';
import '../../utils/auth_logout_flow.dart';
import 'user_menu.dart';

/// One destination in the shell sidebar.
class SidebarDestination {
  const SidebarDestination(this.label, this.icon, {this.badge});
  final String label;
  final IconData icon;
  final int? badge;
}

/// Fixed navy sidebar for desktop layouts: brand mark, nav list, user footer.
class AppSidebar extends ConsumerWidget {
  const AppSidebar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<SidebarDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  static const double width = 250;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;

    return SizedBox(
      width: width,
      child: Material(
        color: AppTheme.navy,
        child: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 22, 20, 16),
                child: Row(
                  children: [
                    _BrandMark(),
                    SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        'בונים · מכרזי חומרים',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                  itemCount: destinations.length,
                  itemBuilder: (context, i) {
                    final d = destinations[i];
                    final selected = i == selectedIndex;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Material(
                        color: selected ? AppTheme.teal.withValues(alpha: 0.18) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => onSelect(i),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                            child: Row(
                              children: [
                                Icon(
                                  d.icon,
                                  size: 19,
                                  color: selected ? Colors.white : Colors.white70,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    d.label,
                                    style: TextStyle(
                                      color: selected ? Colors.white : Colors.white70,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14.5,
                                    ),
                                  ),
                                ),
                                if (d.badge != null && d.badge! > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.amber,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      '${d.badge}',
                                      style: const TextStyle(
                                        color: AppTheme.navy,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (user != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        UserAvatar(name: user.fullName, size: 36, background: AppTheme.amber, foreground: AppTheme.navy),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                user.fullName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                ),
                              ),
                              Text(
                                user.email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white54, fontSize: 11.5),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'התנתקות',
                          icon: const Icon(Icons.logout, size: 18, color: Colors.white54),
                          onPressed: () => signOutAndGoLogin(context, ref),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.amber,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        'ב',
        style: TextStyle(
          color: AppTheme.navy,
          fontWeight: FontWeight.w800,
          fontSize: 19,
        ),
      ),
    );
  }
}
