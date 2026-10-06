import 'package:equatable/equatable.dart';

/// Instantánea deportiva entregada por el planificador. La presentación no
/// deduce identidad, objetivos ni progresiones a partir del nombre del ejercicio.
class PerformanceSetPrescription extends Equatable {
  const PerformanceSetPrescription({
    required this.exerciseCode,
    required this.exerciseVersion,
    required this.protocolKey,
    required this.protocolVersion,
    required this.setupKey,
    required this.measurement,
    required this.loadMode,
    required this.policyVersion,
    required this.targetValue,
    this.intent = 'work',
    this.fixedDurationSeconds,
    this.fixedDistanceMeters,
    this.externalLoadKg,
    this.bodyMassKg,
    this.targetRir,
    this.effortMode,
    this.targetRpe,
    this.stimulusCode,
    this.instructions = '',
    this.recordsStimulusResponses = false,
    this.recordsPenaltySeconds = false,
  });

  final String exerciseCode;
  final int exerciseVersion;
  final String protocolKey;
  final int protocolVersion;
  final String setupKey;
  final String measurement;
  final String loadMode;
  final String policyVersion;
  final double targetValue;
  final String intent;
  final double? fixedDurationSeconds;
  final double? fixedDistanceMeters;
  final double? externalLoadKg;
  final double? bodyMassKg;
  final double? targetRir;
  final String? effortMode;
  final double? targetRpe;
  final String? stimulusCode;
  final String instructions;

  /// Capacidades del protocolo; cronometrar un circuito no lo hace reactivo.
  final bool recordsStimulusResponses;
  final bool recordsPenaltySeconds;

  bool get usesRir => effortMode == null
      ? intent == 'work' &&
            const ['REPS', 'LOAD_REPS', 'REPS_IN_TIME'].contains(measurement)
      : effortMode == 'rir';
  bool get usesRpe => effortMode == 'rpe';
  bool get usesLoad =>
      loadMode != 'bodyweight' &&
      (loadMode != 'assisted' || externalLoadKg != null);
  bool get needsBodyMass => loadMode == 'bodyweight_plus_external';
  bool get isIntegerValue => const [
    'REPS',
    'LOAD_REPS',
    'REPS_IN_TIME',
    'PASS_FAIL',
  ].contains(measurement);
  String get unit => switch (measurement) {
    'REPS' || 'LOAD_REPS' || 'REPS_IN_TIME' => 'repeticiones válidas',
    'DURATION' || 'TIME_FOR_DISTANCE' || 'TIME_FOR_COURSE' => 'segundos',
    'REACTIVE_METRICS' => 'segundos de contacto medidos',
    'DISTANCE' || 'HEIGHT' => 'metros',
    'MAX_LOAD' => 'kg',
    'PASS_FAIL' => 'intento técnico',
    _ => throw StateError('Medición desconocida: $measurement'),
  };

  @override
  List<Object?> get props => [
    exerciseCode,
    exerciseVersion,
    protocolKey,
    protocolVersion,
    setupKey,
    measurement,
    loadMode,
    policyVersion,
    targetValue,
    intent,
    fixedDurationSeconds,
    fixedDistanceMeters,
    externalLoadKg,
    bodyMassKg,
    targetRir,
    effortMode,
    targetRpe,
    stimulusCode,
    instructions,
    recordsStimulusResponses,
    recordsPenaltySeconds,
  ];
}

/// Ausencia de información no equivale a éxito, cero esfuerzo o técnica válida.
class PerformanceSetResult extends Equatable {
  const PerformanceSetResult({
    this.value,
    this.techniqueValid,
    this.conditionsConfirmed,
    this.tolerated,
    this.rir,
    this.rpe,
    this.loadKg,
    this.bodyMassKg,
    this.penaltySeconds,
    this.correctResponses,
    this.totalResponses,
    this.succeeded,
    this.actualDurationSeconds,
    this.jumpHeightMeters,
    this.measurementMethod,
    this.stopReason = 'unknown',
  });
  final double? value;
  final bool? techniqueValid;
  final bool? conditionsConfirmed;
  final bool? tolerated;
  final double? rir;
  final double? rpe;
  final double? loadKg;
  final double? bodyMassKg;
  final double? penaltySeconds;
  final int? correctResponses;
  final int? totalResponses;
  final bool? succeeded;
  final double? actualDurationSeconds;
  final double? jumpHeightMeters;
  final String? measurementMethod;
  final String stopReason;

  String? validate(PerformanceSetPrescription prescription) {
    if (![
      value,
      rir,
      rpe,
      loadKg,
      bodyMassKg,
      penaltySeconds,
      actualDurationSeconds,
      jumpHeightMeters,
    ].every((v) => v == null || (v.isFinite && v >= 0))) {
      return 'Introduce valores finitos y no negativos.';
    }
    if (value != null && prescription.isIntegerValue && value! % 1 != 0) {
      return 'Las repeticiones y los intentos deben ser enteros.';
    }
    if (prescription.measurement == 'PASS_FAIL' && value != null) {
      return 'Indica éxito o fallo, no una medición numérica.';
    }
    if (rir != null && (!prescription.usesRir || rir! > 10)) {
      return 'El margen de repeticiones no corresponde a esta tarea.';
    }
    if (rpe != null && (!prescription.usesRpe || rpe! < 1 || rpe! > 10)) {
      return 'El esfuerzo de 1 a 10 corresponde a la sujeción pautada.';
    }
    if (bodyMassKg != null && bodyMassKg! <= 0) {
      return 'La masa corporal debe ser positiva.';
    }
    if (!const [
      'none',
      'time',
      'difficulty',
      'discomfort',
      'unknown',
    ].contains(stopReason)) {
      return 'Motivo de parada desconocido.';
    }
    if (correctResponses != null || totalResponses != null) {
      if (!const [
            'TIME_FOR_COURSE',
            'PASS_FAIL',
          ].contains(prescription.measurement) ||
          correctResponses == null ||
          totalResponses == null ||
          correctResponses! < 0 ||
          totalResponses! < 1 ||
          correctResponses! > totalResponses!) {
        return 'Revisa aciertos y estímulos recibidos.';
      }
    }
    if (succeeded != null && prescription.measurement != 'PASS_FAIL') {
      return 'El éxito o fallo corresponde a un intento técnico.';
    }
    if (prescription.measurement == 'REACTIVE_METRICS' &&
        (value != null || jumpHeightMeters != null) &&
        (measurementMethod == null || measurementMethod!.trim().length < 3)) {
      return 'Indica el instrumento y método de medición; el cronómetro manual no mide el contacto.';
    }
    if (jumpHeightMeters != null &&
        prescription.measurement != 'REACTIVE_METRICS') {
      return 'La altura complementaria corresponde a una medición reactiva.';
    }
    if (actualDurationSeconds != null &&
        prescription.measurement != 'REPS_IN_TIME') {
      return 'La ventana realizada corresponde a repeticiones en tiempo fijo.';
    }
    if (penaltySeconds != null &&
        prescription.measurement != 'TIME_FOR_COURSE') {
      return 'Las penalizaciones corresponden a un recorrido cronometrado.';
    }
    return null;
  }

  @override
  List<Object?> get props => [
    value,
    techniqueValid,
    conditionsConfirmed,
    tolerated,
    rir,
    rpe,
    loadKg,
    bodyMassKg,
    penaltySeconds,
    correctResponses,
    totalResponses,
    succeeded,
    actualDurationSeconds,
    jumpHeightMeters,
    measurementMethod,
    stopReason,
  ];
}
