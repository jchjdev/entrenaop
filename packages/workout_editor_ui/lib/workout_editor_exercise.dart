import 'package:workout_core/workout_template.dart';

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
    this.selectable = true,
    this.exerciseType,
  });

  final String id, name;
  final List<String> muscleGroups, equipment;
  final String? thumbnailUrl;
  final String? exerciseType;

  WorkoutTargetType get defaultTargetType => switch (exerciseType) {
    'duración' => WorkoutTargetType.duration,
    'distancia' => WorkoutTargetType.distance,
    _ => WorkoutTargetType.repetitions,
  };

  /// Etiqueta del catálogo autorizado; no concede acceso ni cambia permisos.
  final String? catalogScope;

  /// Una referencia histórica puede renderizarse sin ofrecerla en una receta
  /// nueva. Los permisos y las escrituras se vuelven a comprobar en servidor.
  final bool selectable;
}
