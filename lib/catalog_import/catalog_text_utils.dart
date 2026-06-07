/// Hebrew-friendly normalization for search tokens and prefixes.
abstract final class CatalogTextUtils {
  static String normalizeForSearch(String input) {
    var s = input.trim().toLowerCase();
    s = s.replaceAll(RegExp(r'[\u0591-\u05C7]'), '');
    s = s.replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  static List<String> buildSearchTokens({
    required String name,
    List<String> aka = const [],
    int maxTokens = 30,
  }) {
    final tokens = <String>{};
    void addWords(String text) {
      final norm = normalizeForSearch(text);
      if (norm.isEmpty) return;
      tokens.add(norm);
      for (final part in norm.split(' ')) {
        if (part.length >= 2) tokens.add(part);
      }
    }

    addWords(name);
    for (final a in aka) {
      addWords(a);
    }

    return tokens.take(maxTokens).toList();
  }

  /// True when query should use skuLower prefix search (not general text).
  static bool looksLikeSkuQuery(String input) {
    final s = input.trim().toLowerCase();
    if (s.length < 2 || s.length > 24) return false;
    if (RegExp(r'[\u0590-\u05FF]').hasMatch(s)) return false;
    if (s.contains(' ')) return false;
    if (!RegExp(r'^[a-z0-9\-]+$').hasMatch(s)) return false;
    if (RegExp(r'\d').hasMatch(s)) return true;
    if (s.contains('-') && s.length >= 3) return true;
    return false;
  }

  static String stripHtml(String html) {
    if (html.isEmpty) return '';
    var s = html
        .replaceAll(RegExp(r'<[^>]*>', multiLine: true), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.length > 2000) {
      s = '${s.substring(0, 2000)}…';
    }
    return s;
  }

  static String unitFromSize(Map<String, dynamic>? size) {
    if (size == null) return '';
    final unit = size['unit']?.toString() ?? '';
    final type = size['type']?.toString() ?? '';
    if (unit.isNotEmpty && type.isNotEmpty) return '$type / $unit';
    return unit.isNotEmpty ? unit : type;
  }

  static String packagingFromSize(Map<String, dynamic>? size) {
    if (size == null) return '';
    final amount = size['amount'];
    final unit = size['unit']?.toString() ?? '';
    if (amount != null && unit.isNotEmpty) {
      return '$amount $unit';
    }
    return unit;
  }

  static String idToString(dynamic id) => id?.toString() ?? '';
}
