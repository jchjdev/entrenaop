/// Datos de presentación del catálogo autorizado por cada consumidor.
/// Incluir un ejercicio aquí no concede permiso de lectura ni de guardado.
class WorkoutEditorExercise {
  const WorkoutEditorExercise({
    required this.id,
    required this.name,
    this.muscleGroups = const [],
    this.equipment = const [],
    this.thumbnailUrl,
    this.catalogScope,
  });

  final String id, name;
  final List<String> muscleGroups, equipment;
  final String? thumbnailUrl;

  /// Etiqueta del catálogo autorizado; no concede acceso ni cambia permisos.
  final String? catalogScope;
}
