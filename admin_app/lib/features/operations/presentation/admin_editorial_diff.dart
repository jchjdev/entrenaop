import 'dart:convert';

typedef EditorialDifference = ({String path, String before, String after});

/// Se comparan valores, no el orden de las claves JSON ni el texto serializado.
List<EditorialDifference> editorialDifferences(Object? before, Object? after) {
  final result = <EditorialDifference>[];
  String display(Object? value) => value == null
      ? '—'
      : value is String
      ? value
      : jsonEncode(value);
  void visit(String path, Object? a, Object? b) {
    if (result.length >= 200) return;
    if ((a is Map || a == null) &&
        (b is Map || b == null) &&
        (a is Map || b is Map)) {
      final beforeMap = a as Map? ?? const {};
      final afterMap = b as Map? ?? const {};
      final keys = {
        ...beforeMap.keys,
        ...afterMap.keys,
      }.map((k) => k.toString()).toList()..sort();
      for (final key in keys) {
        final label = _labels[key] ?? key;
        visit(
          path.isEmpty ? label : '$path / $label',
          beforeMap[key],
          afterMap[key],
        );
      }
    } else if (a is List && b is List) {
      for (var i = 0; i < a.length || i < b.length; i++) {
        visit(
          '$path / ${i + 1}',
          i < a.length ? a[i] : null,
          i < b.length ? b[i] : null,
        );
      }
    } else if (a != b) {
      result.add((
        path: path.isEmpty ? 'Contenido' : path,
        before: display(a),
        after: display(b),
      ));
    }
  }

  visit('', before, after);
  return result;
}

const _labels = {
  'payload': 'Contenido',
  'name': 'Nombre',
  'description': 'Descripción',
  'blocks': 'Bloques',
  'exercises': 'Ejercicios',
  'sets': 'Series',
  'target_reps': 'Repeticiones',
  'target_load_kg': 'Carga (kg)',
  'target_rir': 'RIR',
  'rest_after_seconds': 'Descanso (s)',
  'target_duration_seconds': 'Tiempo (s)',
  'target_distance_meters': 'Distancia (m)',
  'exercise_id': 'Ejercicio de catálogo',
  'exercise_name': 'Nombre del ejercicio',
  'format': 'Formato',
  'rounds': 'Rondas',
  'version': 'Versión',
  'status': 'Estado',
  'show_in_library': 'Mostrar como sesión suelta',
  'phases': 'Fases',
  'sessions': 'Sesiones',
  'template_id': 'Sesión de catálogo',
  'warmup_id': 'Calentamiento adjunto',
  'instructions': 'Indicaciones',
  'estimated_duration_minutes': 'Duración estimada (min)',
  'category_ids': 'Categorías',
  'primary_category_id': 'Categoría principal',
  'audience': 'Destinatarios',
  'equipment': 'Material',
  'time_cap_seconds': 'Límite (s)',
};
