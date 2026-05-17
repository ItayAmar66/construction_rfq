/// Badge label for live counts. Returns a number when [count] > 0, otherwise null.
String? countBadgeLabel(int count, {bool showEmptyLabel = false}) {
  if (count > 0) return '$count';
  if (showEmptyLabel) return 'אין';
  return null;
}
