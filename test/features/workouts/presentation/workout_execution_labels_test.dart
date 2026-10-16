import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/presentation/widgets/workout_execution_labels.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/workout_amrap_fixture.dart';

void main() {
  test('AMRAP se cuenta como un bloque, no como tres series', () {
    final execution = amrapFixture();
    expect(workoutProgressLabel(execution), '0 de 1 bloque resuelto');
    expect(workoutProgressValue(execution), 0);
    final completed = execution.copyWith(
      sets: [
        for (final set in execution.sets)
          set.copyWith(status: WorkoutSetStatus.completed),
      ],
    );
    expect(workoutProgressLabel(completed), '1 de 1 bloque resuelto');
    expect(workoutProgressValue(completed), 1);
  });
  test('un bloque parcial no queda resuelto ni adelanta otro bloque', () {
    final source = amrapFixture();
    final mixed = source.copyWith(
      sets: [
        for (final set in source.sets)
          set.copyWith(status: WorkoutSetStatus.completed),
        const WorkoutExecutionSet(
          id: 'next',
          blockOrder: 1,
          blockName: 'Fuerza',
          blockFormat: WorkoutBlockFormat.straightSets,
          itemOrder: 0,
          exerciseId: 'next',
          exerciseName: 'Dominadas',
          setOrder: 0,
          restAfterSeconds: 0,
          status: WorkoutSetStatus.pending,
        ),
      ],
    );
    expect(workoutProgressLabel(mixed), '1 de 2 bloques resueltos');
    expect(workoutProgressValue(mixed), .5);
    expect(
      workoutProgressValue(
        source.copyWith(
          sets: [
            source.sets.first.copyWith(status: WorkoutSetStatus.completed),
            ...source.sets.skip(1),
          ],
        ),
      ),
      0,
    );
  });
  test('el parcial entre ejercicios explica el trabajo anterior', () {
    final label = workoutAmrapResultLabel(
      WorkoutAmrapResult(
        blockOrder: 0,
        completedRounds: 5,
        partialItemOrder: 2,
        partialReps: 0,
        completedAt: DateTime.utc(2026, 10, 16),
      ),
      amrapFixture().sets,
    );
    expect(
      label,
      contains('completaste Flexiones, Plancha frontal sobre antebrazos'),
    );
    expect(label, contains('0 repeticiones de Sentadilla'));
  });
}
