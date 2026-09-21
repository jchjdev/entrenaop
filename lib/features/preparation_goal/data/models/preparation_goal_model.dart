import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_program.dart';

class PreparationGoalModel {
  const PreparationGoalModel._();

  static PreparationGoal fromJson(Map<String, dynamic> json) {
    final targetDate = json['target_date'] as String?;
    final programJson = Map<String, dynamic>.from(
      json['preparation_programs'] as Map,
    );
    return PreparationGoal(
      id: json['id'] as String,
      program: PreparationProgramModel.fromJson(programJson),
      targetDate: targetDate == null ? null : DateTime.parse(targetDate),
    );
  }

  static Map<String, dynamic> toJson(
    PreparationGoal goal, {
    required String userId,
  }) {
    return {
      'user_id': userId,
      'program_id': goal.programId,
      'target_date': goal.targetDate?.toIso8601String().split('T').first,
    };
  }
}

class PreparationProgramModel {
  const PreparationProgramModel._();

  static PreparationProgram fromJson(Map<String, dynamic> json) =>
      PreparationProgram(
        id: json['id'] as String,
        name: json['name'] as String,
        kind: switch (json['kind'] as String) {
          'access' => PreparationProgramKind.access,
          'internal_assessment' => PreparationProgramKind.internalAssessment,
          final value => throw FormatException(
            'Tipo de preparación desconocido: $value',
          ),
        },
      );
}
