import 'package:workout_core/workout_template.dart';

import 'duration_input_formatter.dart';
import 'workout_editor_snapshot.dart';

/// Adaptación de borradores locales antiguos al formulario común. No publica
/// ni altera la receta: la proyección inversa conserva series y excepciones.
WorkoutEditorSnapshot workoutEditorStateFromInput(
  CreatePersonalWorkoutInput input,
) {
  String number(num? value) => value == null
      ? ''
      : value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
  final running =
      input.blocks.length == 1 &&
      input.blocks.single.format == WorkoutBlockFormat.running;
  final segments = <Map<String, dynamic>>[];
  if (running) {
    if (input.blocks.single.exercises.length != 1) {
      throw const FormatException(
        'La carrera guardada no es compatible con este formulario. Se conserva.',
      );
    }
    for (final set in input.blocks.single.exercises.single.sets) {
      final row = <String, dynamic>{
        if (set.runningStep != null) 'stepKind': set.runningStep!.kind.name,
        if (set.targetType == WorkoutTargetType.manual) 'manual': true,
        'countText': '1',
        'targetText': set.targetType == WorkoutTargetType.duration
            ? formatDurationSeconds(set.targetValue.round())
            : number(set.targetValue),
        'paceText': set.targetPaceMinSecondsPerKm == null
            ? ''
            : formatDurationSeconds(set.targetPaceMinSecondsPerKm!),
        'paceMaxText': set.targetPaceMaxSecondsPerKm == null
            ? ''
            : formatDurationSeconds(set.targetPaceMaxSecondsPerKm!),
        'recoveryTimeText': set.recoveryDistanceMeters != null
            ? number(set.recoveryDistanceMeters)
            : formatDurationSeconds(set.recoveryDurationSeconds ?? 60),
        'byDistance': set.targetType == WorkoutTargetType.distance,
        'recoveryByDistance': set.recoveryDistanceMeters != null,
        'recoveryType': set.recoveryType?.name,
      };
      if (segments.isNotEmpty &&
          segments.last.entries
              .where((e) => e.key != 'countText')
              .every((e) => row[e.key] == e.value)) {
        segments.last['countText'] =
            '${int.parse(segments.last['countText'] as String) + 1}';
      } else {
        segments.add(row);
      }
    }
  }
  Map<String, dynamic> exerciseRow(WorkoutExerciseDraft exercise) {
    if (exercise.sets.isEmpty ||
        exercise.sets.any(
          (s) => s.targetType != exercise.sets.first.targetType,
        )) {
      throw const FormatException(
        'El borrador contiene objetivos distintos en una posición. Se conserva sin sobrescribir.',
      );
    }
    final first = exercise.sets.first;
    // Vacío hereda el común. Elegir común vacío si alguna serie carece de
    // carga/RIR permite conservar también una retirada explícita de ese valor.
    final load = exercise.sets.any((s) => s.targetLoadKg == null)
        ? null
        : first.targetLoadKg;
    final rir = exercise.sets.any((s) => s.targetRir == null)
        ? null
        : first.targetRir;
    final variations = <Map<String, dynamic>>[
      for (var i = 0; i < exercise.sets.length; i++)
        if (exercise.sets[i].targetValue != first.targetValue ||
            exercise.sets[i].restAfterSeconds != first.restAfterSeconds ||
            exercise.sets[i].targetLoadKg != load ||
            exercise.sets[i].targetRir != rir)
          {
            'setIndex': i,
            'targetText': number(exercise.sets[i].targetValue),
            'restText': '${exercise.sets[i].restAfterSeconds}',
            'loadText': number(exercise.sets[i].targetLoadKg),
            'rirText': number(exercise.sets[i].targetRir),
          },
    ];
    return {
      'exerciseId': exercise.exerciseId,
      'targetType': first.targetType.name,
      'automaticSlot': false,
      'customSets': variations.isNotEmpty,
      'countText': '${exercise.sets.length}',
      'targetText': number(first.targetValue),
      'restText': '${first.restAfterSeconds}',
      'loadText': number(load),
      'rirText': number(rir),
      'amrapRepetitionsText': number(first.targetValue),
      'amrapRirText': number(rir),
      'variations': variations,
    };
  }

  return WorkoutEditorSnapshot({
    'schema': 1,
    'running': running,
    'nameText': input.name,
    'descriptionText': input.description ?? '',
    'durationText': number(input.estimatedDurationMinutes),
    'segments': segments,
    'blocks': running
        ? <Map<String, dynamic>>[]
        : [
            for (final block in input.blocks)
              {
                'nameText': block.name,
                'format': block.format.name,
                'roundsText': '${block.rounds}',
                'restText': formatDurationSeconds(block.restAfterSeconds),
                'capText': formatDurationSeconds(block.timeCapSeconds ?? 600),
                'exercises': [
                  for (final exercise in block.exercises) exerciseRow(exercise),
                ],
              },
          ],
  });
}
