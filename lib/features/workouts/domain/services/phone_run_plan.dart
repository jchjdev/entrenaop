import 'dart:math' as math;

import '../entities/workout_execution.dart';
import '../entities/workout_template.dart';
import 'phone_running.dart';

class PhoneRunStep {
  const PhoneRunStep({
    required this.setId,
    required this.kind,
    required this.completion,
    this.seconds,
    this.meters,
    this.fastestPace,
    this.slowestPace,
    this.associatedRecovery = false,
  });

  final String setId;
  final RunningStepKind kind;
  final RunningStepCompletion completion;
  final int? seconds, fastestPace, slowestPace;
  final double? meters;
  final bool associatedRecovery;

  String get id => associatedRecovery ? '$setId/recovery' : setId;
  bool get passive => kind == RunningStepKind.rest;
  bool get recovery =>
      passive ||
      associatedRecovery ||
      kind == RunningStepKind.recovery ||
      kind == RunningStepKind.walking ||
      kind == RunningStepKind.jogging;

  bool reached(
    PhoneRunTotals totals, {
    required bool trackMode,
  }) => switch (completion) {
    RunningStepCompletion.time => totals.elapsedMilliseconds >= seconds! * 1000,
    RunningStepCompletion.distance =>
      !trackMode && totals.distanceReliable && totals.distanceMeters >= meters!,
    RunningStepCompletion.manual => false,
  };
}

bool _runningFormat(WorkoutBlockFormat format) => switch (format) {
  WorkoutBlockFormat.running ||
  WorkoutBlockFormat.warmUp ||
  WorkoutBlockFormat.coolDown => true,
  _ => false,
};

bool supportsPhoneRunSet(WorkoutExecutionSet set) =>
    _runningFormat(set.blockFormat) &&
    set.exerciseId == runningExerciseId &&
    set.performancePrescription == null &&
    set.targetReps == null;

bool supportsPhoneRun(WorkoutTemplate workout) =>
    workout.blocks.isNotEmpty &&
    workout.blocks.every(
      (block) =>
          _runningFormat(block.format) &&
          block.timeCapSeconds == null &&
          block.items.isNotEmpty &&
          block.items.every(
            (item) =>
                item.exerciseId == runningExerciseId &&
                item.sets.isNotEmpty &&
                item.sets.every(
                  (set) =>
                      set.targetReps == null &&
                      set.performancePrescription == null,
                ),
          ),
    );

List<PhoneRunStep> phoneRunSteps(WorkoutExecution execution) {
  if (execution.status != WorkoutExecutionStatus.inProgress) return const [];
  final first = execution.currentSet;
  final sets = execution.sets
      .skipWhile((set) => set.id != first?.id)
      .takeWhile(
        (set) =>
            set.status == WorkoutSetStatus.pending && supportsPhoneRunSet(set),
      );
  return [
    for (final set in sets) ...[
      PhoneRunStep(
        setId: set.id,
        kind:
            set.runningStep?.kind ??
            (switch (set.blockFormat) {
              WorkoutBlockFormat.warmUp => RunningStepKind.warmup,
              WorkoutBlockFormat.coolDown => RunningStepKind.cooldown,
              _ => RunningStepKind.run,
            }),
        completion:
            set.runningStep?.completion ??
            _completion(set.targetDurationSeconds, set.targetDistanceMeters),
        seconds: set.targetDurationSeconds,
        meters: set.targetDistanceMeters,
        fastestPace: set.targetPaceMinSecondsPerKm,
        slowestPace: set.targetPaceMaxSecondsPerKm,
      ),
      ?_recovery(set),
    ],
  ];
}

PhoneRunStep? _recovery(WorkoutExecutionSet set) {
  final meters = set.recoveryDistanceMeters;
  final seconds =
      set.recoveryDurationSeconds ??
      ((meters ?? 0) > 0 ? null : set.restAfterSeconds);
  final completion = _completion(seconds, meters);
  if (completion == RunningStepCompletion.manual) return null;
  return PhoneRunStep(
    setId: set.id,
    kind: switch (set.recoveryType) {
      RunningRecoveryType.walking => RunningStepKind.walking,
      RunningRecoveryType.jogging => RunningStepKind.jogging,
      RunningRecoveryType.passive || null => RunningStepKind.rest,
    },
    completion: completion,
    seconds: seconds,
    meters: meters,
    associatedRecovery: true,
  );
}

RunningStepCompletion _completion(int? seconds, double? meters) =>
    (meters ?? 0) > 0
    ? RunningStepCompletion.distance
    : (seconds ?? 0) > 0
    ? RunningStepCompletion.time
    : RunningStepCompletion.manual;

/// Un cruce tardío consume los parciales anteriores sin acumular locuciones.
int phoneRunSplitIndex(double meters, double interval, {int? limit}) {
  if (interval <= 0) return 0;
  final index = (meters / interval).floor();
  return limit == null ? index : math.min(index, limit);
}

String phoneRunSpokenPace(int secondsPerKm) =>
    '${secondsPerKm ~/ 60} minutos y ${secondsPerKm % 60} segundos por kilómetro';

Iterable<({WorkoutSetResultInput result, bool ended})> phoneRunResults({
  required Iterable<WorkoutExecutionSet> sets,
  required List<PhoneRunStep> steps,
  required List<PhoneRunLap> laps,
  required Map<String, WorkoutSetResultInput> previous,
  PhoneRunLap? partial,
}) sync* {
  final finished = {for (final lap in laps) lap.stepId: lap.totals};
  final measured = {
    ...finished,
    if (partial != null) partial.stepId: partial.totals,
  };
  final byId = {for (final step in steps) step.id: step};
  for (final set in sets) {
    final work = measured[set.id];
    final recovery = measured['${set.id}/recovery'];
    if (work == null && recovery == null) continue;
    final old = previous[set.id];
    yield (
      ended: finished.containsKey(set.id),
      result: WorkoutSetResultInput(
        resultId: set.id,
        actualDurationSeconds: _seconds(work) ?? old?.actualDurationSeconds,
        actualDistanceMeters: byId[set.id]?.passive == true
            ? 0.0
            : _meters(work) ?? old?.actualDistanceMeters,
        actualRpe: old?.actualRpe,
        actualRecoveryDurationSeconds: set.recoveryDurationSeconds == null
            ? old?.actualRecoveryDurationSeconds
            : _seconds(recovery) ?? old?.actualRecoveryDurationSeconds,
        actualRecoveryDistanceMeters: set.recoveryDistanceMeters == null
            ? old?.actualRecoveryDistanceMeters
            : _meters(recovery) ?? old?.actualRecoveryDistanceMeters,
      ),
    );
  }
}

int? _seconds(PhoneRunTotals? totals) =>
    totals != null && totals.seconds > 0 ? totals.seconds : null;

double? _meters(PhoneRunTotals? totals) =>
    totals != null && totals.distanceReliable && totals.distanceMeters >= 1
    ? totals.distanceMeters.roundToDouble()
    : null;
