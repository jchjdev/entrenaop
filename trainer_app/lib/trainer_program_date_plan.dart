import 'package:workout_core/guided_program.dart';

import 'trainer_program_repository.dart';

/// Propuesta de presentación ya usada en el envío individual: una pasada,
/// separando dos días civiles. No desarrolla semanas ni prescribe cargas.
List<TrainerProgramEntry> proposeTrainerProgramDates(
  GuidedProgram program,
  int phase,
  DateTime start,
) {
  final entries = <TrainerProgramEntry>[];
  for (var pi = 0; pi < program.phases.length; pi++) {
    if (phase != -1 && pi != phase) continue;
    for (var si = 0; si < program.phases[pi].sessions.length; si++) {
      entries.add(
        TrainerProgramEntry(
          pi,
          si,
          DateTime(start.year, start.month, start.day + entries.length * 2),
        ),
      );
    }
  }
  return entries;
}

String trainerPlanningDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// Las URLs abren un día civil concreto; una fecha inválida usa la entrada normal.
DateTime? parseTrainerPlanningDate(String? value) {
  if (value == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    return null;
  }
  final date = DateTime.tryParse(value);
  if (date == null ||
      date.year < 1970 ||
      date.year > 2200 ||
      trainerPlanningDate(date) != value) {
    return null;
  }
  return date;
}

String trainerClientPlanningLocation(String clientId, DateTime date) =>
    '/clients/${Uri.encodeComponent(clientId)}/workouts?date=${trainerPlanningDate(date)}';
