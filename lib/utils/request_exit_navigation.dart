import '../models/quote_request.dart';

/// Where to send the user when leaving a request status / compare screen.
abstract final class RequestExitNavigation {
  static String routeFor({QuoteRequest? request}) {
    final projectId = request?.projectId;
    if (projectId != null && projectId.isNotEmpty) {
      return '/projects/$projectId';
    }
    return '/my-requests';
  }

  static String labelFor({QuoteRequest? request}) {
    final projectId = request?.projectId;
    if (projectId != null && projectId.isNotEmpty) {
      return 'חזרה לפרויקט';
    }
    return 'חזרה לבקשות';
  }
}
