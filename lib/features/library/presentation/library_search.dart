/// Normaliza texto únicamente para buscar y agrupar opciones de presentación.
/// No modifica nombres, etiquetas ni datos guardados del catálogo.
String librarySearchText(String value) {
  const accents = 'áàäâéèëêíìïîóòöôúùüûñ';
  const plain = 'aaaaeeeeiiiioooouuuun';
  var text = value.toLowerCase();
  for (var i = 0; i < accents.length; i++) {
    text = text.replaceAll(accents[i], plain[i]);
  }
  return text
      .replaceAll(RegExp(r'[\u0300-\u036f]'), '')
      .replaceAll('_', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

bool matchesLibrarySearch(String query, Iterable<String> fields) {
  final words = librarySearchText(query)
      .split(' ')
      .where((word) => word.isNotEmpty);
  final haystack = librarySearchText(fields.join(' '));
  return words.every(haystack.contains);
}

String libraryOptionLabel(String value) {
  final normalized = librarySearchText(value);
  final translated = switch (normalized) {
    'strength' => 'Fuerza',
    'cardio' => 'Cardio',
    'mobility' => 'Movilidad',
    'repetitions' => 'Repeticiones',
    'duration' || 'duracion' => 'Tiempo',
    'distance' => 'Distancia',
    'beginner' => 'Inicial',
    'intermediate' => 'Intermedio',
    'advanced' => 'Avanzado',
    _ => value.trim().replaceAll('_', ' '),
  };
  if (translated.isEmpty) return translated;
  return '${translated[0].toUpperCase()}${translated.substring(1)}';
}

Map<String, String> libraryOptions(Iterable<String> values) {
  final options = <String, String>{};
  for (final value in values) {
    final normalized = librarySearchText(value);
    if (normalized.isNotEmpty) {
      options.putIfAbsent(normalized, () => libraryOptionLabel(value));
    }
  }
  final keys = options.keys.toList()
    ..sort((a, b) => options[a]!.compareTo(options[b]!));
  return {for (final key in keys) key: options[key]!};
}
