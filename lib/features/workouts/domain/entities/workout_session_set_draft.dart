import 'workout_template.dart';

import 'package:equatable/equatable.dart';

import 'workout_execution.dart';

/// Un borrador no acredita resultados deportivos hasta su confirmación.
class WorkoutSessionSetDraft extends Equatable {
  const WorkoutSessionSetDraft({
    required this.result,
    this.fields = const {},
    this.endedAt,
    this.confirmed = false,
    this.saved = false,
    this.needsCorrection = false,
  });
  final WorkoutSetResultInput result;
  final Map<String, String> fields;
  final DateTime? endedAt;
  final bool confirmed;
  final bool saved;
  final bool needsCorrection;

  WorkoutSessionSetDraft copyWith({
    WorkoutSetResultInput? result,
    Map<String, String>? fields,
    DateTime? endedAt,
    bool? confirmed,
    bool? saved,
    bool? needsCorrection,
  }) => WorkoutSessionSetDraft(
    result: result ?? this.result,
    fields: fields ?? this.fields,
    endedAt: endedAt ?? this.endedAt,
    confirmed: confirmed ?? this.confirmed,
    saved: saved ?? this.saved,
    needsCorrection: needsCorrection ?? this.needsCorrection,
  );

  bool canConfirm(WorkoutExecutionSet set) {
    if (set.id != result.resultId) return false;
    if (set.performancePrescription != null) {
      return result.performanceResult != null;
    }
    // Conservar un borrador heredado no autoriza confirmar RIR nuevo
    // para una tarea donde esa métrica no corresponde.
    if (result.actualRir != null && !set.usesRir) return false;
    bool number(double? n) => n == null || (n.isFinite && n >= 0);
    bool effort(double? n, double minimum) =>
        n == null ||
        (n.isFinite &&
            n >= minimum &&
            n <= 10 &&
            n * 2 == (n * 2).roundToDouble());
    if (set.targetReps != null &&
        (result.actualReps == null || result.actualReps! < 0)) {
      return false;
    }
    if (set.targetDurationSeconds != null &&
        (result.actualDurationSeconds == null ||
            result.actualDurationSeconds! <= 0)) {
      return false;
    }
    if (set.targetDistanceMeters != null &&
        result.actualDistanceMeters == null) {
      return false;
    }
    if (set.targetLoadKg != null && result.actualLoadKg == null) return false;
    if (set.blockFormat == WorkoutBlockFormat.running &&
        (result.actualDurationSeconds == null ||
            result.actualDurationSeconds! <= 0 ||
            result.actualDistanceMeters == null ||
            result.actualDistanceMeters! <= 0)) {
      return false;
    }
    if (result.actualRecoveryDurationSeconds != null &&
        result.actualRecoveryDurationSeconds! <= 0) {
      return false;
    }
    return number(result.actualDistanceMeters) &&
        number(result.actualLoadKg) &&
        number(result.actualRecoveryDistanceMeters) &&
        effort(result.actualRir, 0) &&
        effort(result.actualRpe, 1);
  }

  @override
  List<Object?> get props => [
    result,
    fields,
    endedAt,
    confirmed,
    saved,
    needsCorrection,
  ];
}
