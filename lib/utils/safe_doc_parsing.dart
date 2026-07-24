import 'app_logger.dart';

/// Maps a list of raw documents to models, isolating per-document parse
/// failures so a single corrupted or legacy document cannot error an entire
/// stream/future and blank out a whole list screen.
///
/// Field-level parsing already flows through `FirestoreParsing` and rarely
/// throws, so this is defense-in-depth: if a future field, an unexpected
/// nested shape, or an enum parse does throw for one document, that single row
/// is dropped and reported via [AppLogger.error] (which forwards to the
/// configured `CrashReporter`) instead of taking the list down with it.
///
/// [docs] is left decoupled from `cloud_firestore` types on purpose — pass any
/// iterable of document handles and a [parse] callback that may throw. [label]
/// names the collection/model for the diagnostic breadcrumb.
List<T> parseDocsSafely<D, T>(
  Iterable<D> docs,
  T Function(D doc) parse, {
  required String label,
}) {
  final result = <T>[];
  for (final doc in docs) {
    try {
      result.add(parse(doc));
    } catch (error, stackTrace) {
      AppLogger.error(
        'Skipped a corrupted "$label" document while parsing a list',
        tag: 'SafeDocParsing',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
  return result;
}
