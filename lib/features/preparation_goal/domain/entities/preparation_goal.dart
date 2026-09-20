import 'package:equatable/equatable.dart';

abstract final class PreparationProgramIds {
  static const armedForcesTroopEntry = 'armed_forces_troop_entry';
}

class PreparationGoal extends Equatable {
  const PreparationGoal({required this.programId, this.id, this.targetDate});

  final String? id;
  final String programId;
  final DateTime? targetDate;

  @override
  List<Object?> get props => [id, programId, targetDate];
}
