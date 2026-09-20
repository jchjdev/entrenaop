import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';

class PreparationGoalModel {
  const PreparationGoalModel._();

  static PreparationGoal fromJson(Map<String, dynamic> json) {
    final targetDate = json['target_date'] as String?;
    return PreparationGoal(
      id: json['id'] as String,
      programId: json['program_id'] as String,
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
