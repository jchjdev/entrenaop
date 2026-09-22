import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/domain/services/running_execution_assessment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('detecta una serie dentro del ritmo y recuperación prescritos', () {
    expect(
      assessRunningExecution([
        _set(actualDuration: 88, actualRecovery: 61),
        _set(actualDuration: 89, actualRecovery: 60, order: 1),
      ]),
      RunningExecutionAssessment.onTarget,
    );
  });

  test('detecta desviación individual aunque el promedio pueda encajar', () {
    expect(
      assessRunningExecution([
        _set(actualDuration: 76, actualRecovery: 60),
        _set(actualDuration: 100, actualRecovery: 60, order: 1),
      ]),
      RunningExecutionAssessment.changed,
    );
  });

  test('clasifica como parcial si se omite un tramo', () {
    expect(
      assessRunningExecution([
        _set(actualDuration: 88, actualRecovery: 60),
        _set(status: WorkoutSetStatus.skipped, order: 1),
      ]),
      RunningExecutionAssessment.incomplete,
    );
  });
}

WorkoutExecutionSet _set({
  WorkoutSetStatus status = WorkoutSetStatus.completed,
  int? actualDuration,
  int? actualRecovery,
  int order = 0,
}) => WorkoutExecutionSet(
  id: 'set-$order',
  blockOrder: 0,
  blockName: 'Series',
  blockFormat: WorkoutBlockFormat.running,
  itemOrder: 0,
  exerciseId: runningExerciseId,
  exerciseName: 'Carrera',
  setOrder: order,
  restAfterSeconds: 0,
  status: status,
  targetDistanceMeters: 400,
  targetPaceMinSecondsPerKm: 215,
  targetPaceMaxSecondsPerKm: 225,
  recoveryType: RunningRecoveryType.passive,
  recoveryDurationSeconds: 60,
  actualDistanceMeters: status == WorkoutSetStatus.completed ? 400 : null,
  actualDurationSeconds: actualDuration,
  actualRecoveryDurationSeconds: actualRecovery,
  resultSource: status == WorkoutSetStatus.completed
      ? WorkoutResultSource.manual
      : null,
);
