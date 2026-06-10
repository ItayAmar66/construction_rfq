import '../models/quote_request.dart';

abstract final class ProjectDisplayHelpers {
  static String? chipLabel(QuoteRequest request) {
    final name = request.projectName?.trim();
    if (name == null || name.isEmpty) return null;
    final location = (request.projectLocation ?? request.siteName)?.trim();
    if (location != null && location.isNotEmpty) {
      return 'פרויקט: $name · $location';
    }
    return 'פרויקט: $name';
  }

  static String? chipLabelFromParts({
    String? projectName,
    String? projectLocation,
  }) {
    final name = projectName?.trim();
    if (name == null || name.isEmpty) return null;
    final location = projectLocation?.trim();
    if (location != null && location.isNotEmpty) {
      return 'פרויקט: $name · $location';
    }
    return 'פרויקט: $name';
  }
}
