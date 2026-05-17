import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Opens a secondary screen from the dashboard with back → home behavior.
void openFromDashboard(BuildContext context, String path) {
  final uri = Uri.parse(path);
  final query = Map<String, String>.from(uri.queryParameters)
    ..['from'] = 'dashboard';
  context.push(uri.replace(queryParameters: query).toString());
}

/// True when screen was opened from dashboard cards/tiles.
bool isOpenedFromDashboard(BuildContext context) {
  return GoRouterState.of(context).uri.queryParameters['from'] == 'dashboard';
}
