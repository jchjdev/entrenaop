import 'package:equatable/equatable.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_program.dart';

abstract final class PreparationProgramIds {
  static const armedForcesTroopEntry = 'armed_forces_troop_entry';
}

class PreparationGoal extends Equatable {
  const PreparationGoal({required this.program, this.id, this.targetDate});

  final String? id;
  final PreparationProgram program;
  final DateTime? targetDate;

  String get programId => program.id;

  @override
  List<Object?> get props => [id, program, targetDate];
}
