import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/workout_template.dart';
import 'package:workout_editor_ui/running_editor_groups.dart';
import 'package:workout_editor_ui/workout_editor_initial_state.dart';
import 'package:workout_editor_ui/workout_editor_snapshot.dart';

const work = WorkoutSetDraft(
  targetType: WorkoutTargetType.distance,
  targetValue: 400,
  restAfterSeconds: 0,
  targetPaceMinSecondsPerKm: 250,
  targetPaceMaxSecondsPerKm: 270,
  runningStep: RunningStepMetadata(
    kind: RunningStepKind.run,
    completion: RunningStepCompletion.distance,
  ),
);
const soft = WorkoutSetDraft(
  targetType: WorkoutTargetType.duration,
  targetValue: 90,
  restAfterSeconds: 0,
  targetPaceMinSecondsPerKm: 300,
  targetPaceMaxSecondsPerKm: 330,
  runningStep: RunningStepMetadata(
    kind: RunningStepKind.recovery,
    completion: RunningStepCompletion.time,
  ),
);
WorkoutSetDraft lap(RunningStepKind kind) => WorkoutSetDraft(
  targetType: WorkoutTargetType.manual,
  targetValue: 0,
  restAfterSeconds: 0,
  runningStep: RunningStepMetadata(
    kind: kind,
    completion: RunningStepCompletion.manual,
  ),
);
CreatePersonalWorkoutInput recipe(List<WorkoutSetDraft> sets) =>
    CreatePersonalWorkoutInput(
      name: 'Series',
      description: '',
      blocks: [
        WorkoutBlockDraft(
          name: 'Carrera',
          format: WorkoutBlockFormat.running,
          exercises: [
            WorkoutExerciseDraft(exerciseId: runningExerciseId, sets: sets),
          ],
        ),
      ],
    );
WorkoutEditorSnapshot fixture({int count = 10, bool omit = false}) =>
    workoutEditorStateFromInput(
      recipe([
        lap(RunningStepKind.warmup),
        for (var i = 0; i < count; i++) ...[
          work,
          if (!omit || i < count - 1) soft,
        ],
        lap(RunningStepKind.cooldown),
      ]),
    );
List<WorkoutSetDraft> sets(WorkoutEditorSnapshot snapshot) =>
    projectWorkoutEditorSnapshot(snapshot).blocks.single.exercises.single.sets;

void main() {
  test(
    'diez parejas se presentan en un tramo sin modificar pasos ni ritmos',
    () {
      for (final omit in [false, true]) {
        final original = fixture(omit: omit),
            before = jsonEncode(fixture(omit: omit).value);
        final groups = runningEditorGroups(original);
        expect(groups.length, 3);
        expect(groups[1].repetitions, 10);
        expect(groups[1].recovery.length, omit ? 9 : 10);
        expect(groups[1].omitLastRecovery, omit);
        expect(jsonEncode(original.value), before);
      }
    },
  );
  test(
    'omisión asociada permanece agrupada después de publicar y recuperar',
    () {
      final original = fixture(count: 1);
      final rows = (original.value['segments'] as List).cast<Map>();
      final attached = WorkoutEditorSnapshot({
        ...original.value,
        'segments': [
          rows.first,
          {
            ...rows[1],
            'countText': '9',
            'recoveryType': 'jogging',
            'recoveryTimeText': '01:30',
          },
          {...rows[1], 'recoveryTimeText': ''},
          rows.last,
        ],
      });
      final groups = runningEditorGroups(attached);
      expect(groups.length, 3);
      expect(groups[1].repetitions, 10);
      expect(groups[1].omittedAttachedRecovery, isTrue);
      final reopened = workoutEditorStateFromInput(
        projectWorkoutEditorSnapshot(attached),
      );
      expect(runningEditorGroups(reopened)[1].repetitions, 10);
      expect(runningEditorGroups(reopened)[1].omitLastRecovery, isTrue);
      final five = resizeRunningEditorGroup(
        reopened,
        runningEditorGroups(reopened)[1],
        5,
        omitLastRecovery: true,
      );
      expect(sets(five).length, 7);
      expect(sets(five)[1].recoveryDurationSeconds, 90);
      expect(sets(five)[5].recoveryType, isNull);
    },
  );
  test('cambiar repeticiones conserva cada pareja y la omisión explícita', () {
    final original = fixture();
    final result = resizeRunningEditorGroup(
      original,
      runningEditorGroups(original)[1],
      5,
      omitLastRecovery: true,
    );
    expect(sets(result), [
      lap(RunningStepKind.warmup),
      for (var i = 0; i < 5; i++) ...[work, if (i < 4) soft],
      lap(RunningStepKind.cooldown),
    ]);
    expect(runningEditorGroups(result)[1].repetitions, 5);
    expect(
      () => resizeRunningEditorGroup(
        original,
        runningEditorGroups(original)[1],
        20,
      ),
      throwsFormatException,
    );
    expect(
      () => resizeRunningEditorGroup(
        original,
        runningEditorGroups(original)[1],
        0,
      ),
      throwsFormatException,
    );
  });
  test('duplicar diez series con última recuperación omitida respeta el límite exacto', () {
    final original = fixture(omit: true);
    final result = duplicateRunningEditorGroup(
      original,
      runningEditorGroups(original)[1],
    );
    expect(sets(result).length, 40);
    expect(
      sets(result)
          .where((s) => s.runningStep?.kind == RunningStepKind.run)
          .length,
      20,
    );
    expect(
      sets(result)
          .where((s) => s.runningStep?.kind == RunningStepKind.recovery)
          .length,
      18,
    );
  });
  test('no oculta una recuperación distinta ni altera una excepción', () {
    final original = fixture(count: 3);
    original.value['segments'][4]['paceText'] = '06:00';
    original.value['segments'][4]['paceMaxText'] = '06:20';
    expect(runningEditorGroups(original).where((g) => g.paired).length, 3);
    expect(sets(original)[4].targetPaceMinSecondsPerKm, 360);
  });
  test(
    'duplicar y mover mantiene orden, recuperación y recetas originales',
    () {
      final original = fixture(count: 2),
          groups = runningEditorGroups(fixture(count: 2));
      final duplicated = duplicateRunningEditorGroup(original, groups[1]);
      expect(sets(duplicated), [
        lap(RunningStepKind.warmup),
        work,
        soft,
        work,
        soft,
        work,
        soft,
        work,
        soft,
        lap(RunningStepKind.cooldown),
      ]);
      final moved = moveRunningEditorGroup(original, groups[1], groups[0]);
      expect(sets(moved), [
        work,
        soft,
        work,
        soft,
        lap(RunningStepKind.warmup),
        lap(RunningStepKind.cooldown),
      ]);
      expect(sets(original), [
        lap(RunningStepKind.warmup),
        work,
        soft,
        work,
        soft,
        lap(RunningStepKind.cooldown),
      ]);
    },
  );
  test('editar una repetición por separado conserva la recuperación dentro de ella', () {
    final original = fixture(count: 3);
    final groups = runningEditorGroups(
      original,
      separateRepetitions: {1, 3, 5},
    );
    expect(groups.length, 5);
    expect(groups.where((g) => g.paired).length, 3);
    expect(groups[2].recovery, [4]);
  });
  test(
    'una copia puede mantenerse separada visualmente sin cambiar su receta',
    () {
      final original = fixture(count: 2);
      final duplicate = duplicateRunningEditorGroup(
        original,
        runningEditorGroups(original)[1],
      );
      final groups = runningEditorGroups(duplicate, breakBefore: {5, 9});
      expect(groups.length, 4);
      expect(groups[1].repetitions, 2);
      expect(groups[2].repetitions, 2);
    },
  );
}
