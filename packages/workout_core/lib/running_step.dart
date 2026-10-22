import 'package:equatable/equatable.dart';

/// Semántica de EntrenaOP, independiente del formato de cada fabricante.
enum RunningStepKind { warmup, run, recovery, rest, cooldown, walking, jogging }

enum RunningStepCompletion { time, distance, manual }

extension RunningStepKindLabel on RunningStepKind {
  String get label => switch (this) {
    RunningStepKind.warmup => 'Calentamiento',
    RunningStepKind.run => 'Carrera',
    RunningStepKind.recovery => 'Recuperación',
    RunningStepKind.rest => 'Descanso',
    RunningStepKind.cooldown => 'Enfriamiento',
    RunningStepKind.walking => 'Caminar',
    RunningStepKind.jogging => 'Trotar',
  };
}

/// Ausente en recetas antiguas. No se infiere una duración para avance manual.
class RunningStepMetadata extends Equatable {
  const RunningStepMetadata({required this.kind, required this.completion});
  final RunningStepKind kind;
  final RunningStepCompletion completion;
  @override
  List<Object?> get props => [kind, completion];
}
