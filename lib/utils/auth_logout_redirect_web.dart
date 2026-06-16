// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

bool get usesHardWebLoginRedirect => true;

/// Full browser navigation to login — bypasses GoRouter race on web release.
void hardRedirectToLogin() {
  final pathname = html.window.location.pathname;
  final basePath = (pathname == null || pathname.isEmpty) ? '/' : pathname;
  html.window.location.replace('$basePath#/login');
}
