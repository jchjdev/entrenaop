/// Clasificación guardada al iniciar, independiente de la plantilla actual.
enum WorkoutSessionType { running, strength, mixed, unclassified }

extension WorkoutSessionTypeDescription on WorkoutSessionType {
  String get label => switch (this) {
    WorkoutSessionType.running => 'Carrera',
    WorkoutSessionType.strength => 'Fuerza y acondicionamiento',
    WorkoutSessionType.mixed => 'Mixta',
    WorkoutSessionType.unclassified => 'Sin clasificar',
  };
}
