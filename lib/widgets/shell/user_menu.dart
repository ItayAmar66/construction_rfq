import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../utils/app_theme.dart';
import '../../utils/auth_logout_flow.dart';
import '../../utils/hebrew_strings.dart';

/// Initials for an avatar, e.g. "Yossi Cohen" -> "YC", "בונים" -> "ב".
String initialsFor(String fullName) {
  final parts = fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
}

/// Small circular avatar showing the user's initials.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.size = 36,
    this.background = AppTheme.teal,
    this.foreground = Colors.white,
  });

  final String name;
  final double size;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Text(
        initialsFor(name),
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.42,
        ),
      ),
    );
  }
}

/// Avatar button that opens a menu with profile / sign-out actions.
class UserMenu extends ConsumerWidget {
  const UserMenu({super.key, required this.name, this.size = 36});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<_UserMenuAction>(
      tooltip: name,
      offset: const Offset(0, 44),
      onSelected: (action) {
        switch (action) {
          case _UserMenuAction.profile:
            context.go('/profile');
          case _UserMenuAction.logout:
            signOutAndGoLogin(context, ref);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: _UserMenuAction.profile,
          child: Row(
            children: [
              Icon(Icons.person_outline, size: 18, color: AppTheme.textSecondary),
              SizedBox(width: 10),
              Text(HebrewStrings.profile),
            ],
          ),
        ),
        const PopupMenuItem(
          value: _UserMenuAction.logout,
          child: Row(
            children: [
              Icon(Icons.logout, size: 18, color: AppTheme.danger),
              SizedBox(width: 10),
              Text(HebrewStrings.logout, style: TextStyle(color: AppTheme.danger)),
            ],
          ),
        ),
      ],
      child: UserAvatar(name: name, size: size),
    );
  }
}

enum _UserMenuAction { profile, logout }
