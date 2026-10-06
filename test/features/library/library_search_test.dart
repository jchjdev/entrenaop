import 'package:entrenaop/features/library/presentation/library_search.dart';
import 'package:entrenaop/features/exercises/domain/entities/exercise_entity.dart';
import 'package:entrenaop/features/exercises/presentation/exercise_library_filter.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/presentation/workout_library_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('busca palabras sin tildes, mayúsculas, orden o espacios repetidos', () {
    expect(
      matchesLibrarySearch('  TECNICA   pierna ', [
        'Técnica de sentadilla',
        'PIERNAS',
      ]),
      isTrue,
    );
    expect(
      matchesLibrarySearch('técnica salto', ['Tecnica de sentadilla']),
      isFalse,
    );
    expect(matchesLibrarySearch('sentadilla', ['Sentadilla\u0301']), isTrue);
    expect(matchesLibrarySearch('  ', ['cualquier nombre']), isTrue);
  });
  test(
    'las opciones usan solo datos reales y agrupan duplicados textuales',
    () {
      expect(
        libraryOptions(['  ', 'Espalda', 'espalda', ' Bíceps ', 'biceps']),
        {'biceps': 'Bíceps', 'espalda': 'Espalda'},
      );
      expect(libraryOptionLabel('duración'), 'Tiempo');
      expect(libraryOptionLabel('beginner'), 'Inicial');
    },
  );
  test(
    'tipo, duración y texto se combinan sin inferir formatos de bloques',
    () {
      expect(
        const WorkoutLibraryFilter(
          type: LibrarySessionType.running,
          query: 'intervalos',
          duration: LibrarySessionDuration.medium,
        ).matches(_session(30, running: true)),
        isTrue,
      );
      expect(
        const WorkoutLibraryFilter(type: LibrarySessionType.strength)
            .matches(_session(30, running: true)),
        isFalse,
      );
      expect(
        const WorkoutLibraryFilter(duration: LibrarySessionDuration.short)
            .matches(_session(null)),
        isFalse,
      );
      expect(const WorkoutLibraryFilter().matches(_session(null)), isTrue);
    },
  );
  test('los límites de duración son explícitos y no se solapan', () {
    for (final (minutes, type) in [
      (29, LibrarySessionDuration.short),
      (30, LibrarySessionDuration.medium),
      (45, LibrarySessionDuration.medium),
      (46, LibrarySessionDuration.long),
    ]) {
      final matches = LibrarySessionDuration.values
          .where(
            (v) => WorkoutLibraryFilter(duration: v).matches(_session(minutes)),
          )
          .toList();
      expect(matches, [type]);
    }
  });
  test('ejercicios combinan nombre, grupo, tipo, material y dificultad', () {
    expect(
      const ExerciseLibraryFilter(
        query: 'biceps barra',
        muscle: 'espalda',
        type: 'repeticiones',
        equipment: 'barra',
        difficulty: 'intermedio',
      ).matches(_exercise),
      isTrue,
    );
    expect(
      const ExerciseLibraryFilter(muscle: 'piernas').matches(_exercise),
      isFalse,
    );
    expect(
      const ExerciseLibraryFilter(type: 'duracion').matches(_exercise),
      isFalse,
    );
    expect(
      const ExerciseLibraryFilter(equipment: 'mancuerna').matches(_exercise),
      isFalse,
    );
    expect(
      const ExerciseLibraryFilter(difficulty: 'avanzado').matches(_exercise),
      isFalse,
    );
    expect(
      const ExerciseLibraryFilter(query: 'piernas').matches(_exercise),
      isFalse,
    );
  });
  test('buscar no modifica los datos originales ni reclasifica contenido', () {
    const filter = ExerciseLibraryFilter(query: 'ESPALDA');
    expect([_exercise].where(filter.matches), hasLength(1));
    expect(_exercise.muscleGroups, ['espalda', 'bíceps']);
    expect(_exercise.origin, ExerciseOrigin.user);
  });
}

WorkoutTemplateSummary _session(int? minutes, {bool running = false}) =>
    WorkoutTemplateSummary(
      id: 'session',
      name: 'Sesión general',
      description: 'Trabajo por intervalos.',
      estimatedDurationMinutes: minutes,
      origin: WorkoutTemplateOrigin.system,
      version: 1,
      isRunning: running,
    );
const _exercise = ExerciseEntity(
  id: 'mine',
  name: 'Dominadas',
  description: 'Controla el movimiento.',
  muscleGroups: ['espalda', 'bíceps'],
  equipment: ['barra'],
  difficulty: 'intermedio',
  exerciseType: 'repeticiones',
  isPublic: false,
  origin: ExerciseOrigin.user,
  createdBy: 'me',
);
