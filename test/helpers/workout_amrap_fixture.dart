import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';

WorkoutExecution amrapFixture({String executionId = 'amrap-session'}) =>
    WorkoutExecution(
      id: executionId,
      templateId: 'amrap-template',
      templateName: 'Circuito AMRAP',
      templateVersion: 1,
      status: WorkoutExecutionStatus.inProgress,
      startedAt: DateTime.utc(2026, 10, 16),
      sets: [
        for (final (index, name) in [
          (0, 'Flexiones'),
          (1, 'Plancha frontal sobre antebrazos'),
          (2, 'Sentadilla con peso corporal'),
        ])
          WorkoutExecutionSet(
            id: 'amrap-set-$index',
            exerciseId: 'exercise-$index',
            blockOrder: 0,
            blockName: 'Principal',
            blockFormat: WorkoutBlockFormat.amrap,
            blockTimeCapSeconds: 600,
            itemOrder: index,
            exerciseName: name,
            exerciseDescription: 'Técnica de $name',
            setOrder: 0,
            targetReps: index == 1 ? 30 : 10,
            targetRir: 2,
            restAfterSeconds: 0,
            status: WorkoutSetStatus.pending,
          ),
      ],
    );
