String normalizeCatalogSearch(String value) {
  var normalized = value.trim().toLowerCase();
  const accents = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u'};
  for (final entry in accents.entries) {
    normalized = normalized.replaceAll(entry.key, entry.value);
  }
  return normalized.replaceAll(RegExp(r'\s+'), ' ');
}

bool matchesCatalogSearch(String query, Iterable<String> values) {
  final terms = normalizeCatalogSearch(query)
      .split(' ')
      .where((term) => term.isNotEmpty);
  final text = normalizeCatalogSearch(values.join(' '));
  return terms.every(text.contains);
}
