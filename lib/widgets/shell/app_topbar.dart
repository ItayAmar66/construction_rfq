import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../theme/app_icons.dart';
import '../../utils/app_theme.dart';
import 'notification_bell.dart';
import 'user_menu.dart';

/// Shell top bar — a single clean bar: section title · global search ·
/// notification bell · user menu, matching the Bonim reference.
///
/// Replaces the former doubled header (white breadcrumb band stacked over a
/// navy section-title band); the section name now appears exactly once.
class AppTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const AppTopBar({
    super.key,
    required this.sectionLabel,
    this.showUserMenu = true,
  });

  final String sectionLabel;
  final bool showUserMenu;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final isSupplier = user?.userType.isSupplier ?? false;

    return Container(
      height: preferredSize.height,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: AppTheme.cardColor,
        border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
      ),
      child: Row(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Text(
              sectionLabel,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: _GlobalSearchField(
                  onSubmitted: (_) {
                    // No cross-entity global-search backend exists yet, so this
                    // routes to the role's primary searchable list (the typed
                    // query is not yet propagated — documented limitation).
                    final target = isSupplier ? '/incoming' : '/my-requests';
                    if (GoRouterState.of(context).matchedLocation != target) {
                      context.go(target);
                    }
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          const NotificationBell(),
          if (showUserMenu && user != null) ...[
            const SizedBox(width: 12),
            UserMenu(name: user.fullName, size: 34),
          ],
        ],
      ),
    );
  }
}

/// Persistent, compact global search control for the top bar.
class _GlobalSearchField extends StatelessWidget {
  const _GlobalSearchField({required this.onSubmitted});

  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          borderSide: BorderSide(color: color, width: width),
        );

    return SizedBox(
      height: 40,
      child: TextField(
        textInputAction: TextInputAction.search,
        onSubmitted: onSubmitted,
        style: const TextStyle(fontSize: 13.5),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: AppTheme.surfaceTint,
          hintText: 'חיפוש בקשות, הזמנות ומוצרים…',
          hintStyle:
              const TextStyle(color: AppTheme.textSecondary, fontSize: 13.5),
          prefixIcon: const Icon(AppIcons.search,
              size: 18, color: AppTheme.textSecondary),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 38, minHeight: 38),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: border(AppTheme.borderColor),
          enabledBorder: border(AppTheme.borderColor),
          focusedBorder: border(AppTheme.teal, 1.4),
        ),
      ),
    );
  }
}
