import 'package:equatable/equatable.dart';

import 'workout_execution.dart';

/// Cuenta manual opcional. Ningún toque acredita una serie ni una vuelta real.
class WorkoutAmrapDraft extends Equatable {
  const WorkoutAmrapDraft({
    this.rounds = '0',
    this.hasPartial = false,
    this.partialItemOrder,
    this.partialReps = '0',
  });

  final String rounds, partialReps;
  final bool hasPartial;
  final int? partialItemOrder;

  WorkoutAmrapDraft copyWith({
    String? rounds,
    bool? hasPartial,
    int? partialItemOrder,
    String? partialReps,
  }) => WorkoutAmrapDraft(
    rounds: rounds ?? this.rounds,
    hasPartial: hasPartial ?? this.hasPartial,
    partialItemOrder: partialItemOrder ?? this.partialItemOrder,
    partialReps: partialReps ?? this.partialReps,
  );

  WorkoutAmrapDraft changeRounds(int delta) => copyWith(
    rounds: ((int.tryParse(rounds) ?? 0) + delta)
        .clamp(0, 2147483647)
        .toString(),
  );

  String? validate(List<WorkoutExecutionSet> sequence) {
    final count = int.tryParse(rounds);
    if (count == null || count < 0 || count > 2147483647) {
      return 'Introduce un número entero de vueltas, igual o mayor que cero.';
    }
    if (sequence.isEmpty) return 'No encontramos los ejercicios del bloque.';
    if (!hasPartial) return null;
    final selected = sequence.where((s) => s.itemOrder == partialItemOrder);
    if (selected.length != 1) return 'Selecciona dónde terminaste la vuelta.';
    final reps = int.tryParse(partialReps);
    if (reps == null || reps < 0 || reps > 2147483647) {
      return 'Introduce las repeticiones realizadas, igual o mayor que cero.';
    }
    final target = selected.single.targetReps;
    if (target == null || target <= 0) {
      return 'Este ejercicio no tiene un objetivo de repeticiones válido.';
    }
    if (reps >= target) {
      return 'Si completaste este ejercicio, selecciona el siguiente con 0 repeticiones. Si era el último, suma una vuelta completa.';
    }
    return null;
  }

  WorkoutAmrapResultInput toResult({
    required String executionId,
    required int blockOrder,
    required List<WorkoutExecutionSet> sequence,
  }) {
    final error = validate(sequence);
    if (error != null) throw ArgumentError(error);
    final reps = hasPartial ? int.parse(partialReps) : 0;
    final firstOrder = sequence
        .map((s) => s.itemOrder)
        .reduce((a, b) => a < b ? a : b);
    // Cero en el primer movimiento equivale a no haber empezado otra vuelta.
    // Cero en otro conserva los movimientos anteriores ya completados.
    final order = !hasPartial || (reps == 0 && partialItemOrder == firstOrder)
        ? null
        : partialItemOrder;
    return WorkoutAmrapResultInput(
      executionId: executionId,
      blockOrder: blockOrder,
      completedRounds: int.parse(rounds),
      partialItemOrder: order,
      partialReps: reps,
    );
  }

  @override
  List<Object?> get props => [
    rounds,
    hasPartial,
    partialItemOrder,
    partialReps,
  ];
}
