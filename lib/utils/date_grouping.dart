import 'package:intl/intl.dart';

/// A Hebrew-labelled section of items sharing the same calendar group.
class DateGroupSection<T> {
  const DateGroupSection({
    required this.header,
    required this.items,
    required this.sortKey,
  });

  final String header;
  final List<T> items;

  /// Used to order sections newest-first.
  final DateTime sortKey;
}

/// Hebrew section title for a calendar day.
String hebrewDateGroupHeader(DateTime date, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final local = date.toLocal();
  final today = DateTime(reference.year, reference.month, reference.day);
  final day = DateTime(local.year, local.month, local.day);
  final diff = today.difference(day).inDays;

  if (diff == 0) return 'היום';
  if (diff == 1) return 'אתמול';
  if (diff < 7) return 'השבוע';
  return DateFormat('dd/MM/yyyy', 'he').format(local);
}

/// Groups [items] by day. Items must be pre-sorted newest-first.
List<DateGroupSection<T>> groupItemsByDate<T>(
  List<T> items,
  DateTime Function(T item) dateFor,
) {
  if (items.isEmpty) return [];

  final sections = <DateGroupSection<T>>[];
  final headerOrder = <String>[];
  final buckets = <String, List<T>>{};
  final sortKeys = <String, DateTime>{};

  for (final item in items) {
    final date = dateFor(item).toLocal();
    final header = hebrewDateGroupHeader(date);
    buckets.putIfAbsent(header, () => []).add(item);
    if (!headerOrder.contains(header)) {
      headerOrder.add(header);
      sortKeys[header] = DateTime(date.year, date.month, date.day);
    } else {
      final existing = sortKeys[header]!;
      final dayKey = DateTime(date.year, date.month, date.day);
      if (dayKey.isAfter(existing)) sortKeys[header] = dayKey;
    }
  }

  headerOrder.sort((a, b) => sortKeys[b]!.compareTo(sortKeys[a]!));

  for (final header in headerOrder) {
    final bucket = buckets[header]!;
    sections.add(
      DateGroupSection(
        header: header,
        items: bucket,
        sortKey: sortKeys[header]!,
      ),
    );
  }

  return sections;
}
