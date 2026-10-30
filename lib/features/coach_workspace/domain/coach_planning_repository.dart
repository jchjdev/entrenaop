import 'coach_workspace_repository.dart';

import 'package:trainer_access/trainer_access.dart';
import 'package:trainer_access/trainer_appointments.dart';
import 'package:trainer_access/trainer_followup.dart';
import 'package:trainer_access/trainer_followup_codec.dart';
import 'package:workout_core/workout_template.dart';

class CoachLibrarySession {
  const CoachLibrarySession({
    required this.id,
    required this.name,
    required this.version,
    required this.isRunning,
    required this.createdAt,
  });
  final String id, name;
  final int version;
  final bool isRunning;
  final DateTime createdAt;
}

class CoachPrivateNotes {
  const CoachPrivateNotes({
    required this.notes,
    required this.goal,
    required this.revision,
    required this.canEdit,
  });
  final String notes, goal;
  final int revision;
  final bool canEdit;
}

class CoachExerciseReference {
  const CoachExerciseReference({
    required this.id,
    required this.name,
    required this.official,
    this.description = '',
    this.imageUrl,
    this.videoUrl,
  });
  final String id, name, description;
  final bool official;
  final String? imageUrl, videoUrl;
}

/// Acciones móviles sobre contratos profesionales existentes. No contiene
/// autoría, facturación ni autoridad para ampliar el servicio de un alumno.
abstract interface class CoachPlanningRepository {
  Future<List<CoachExerciseReference>> exercises({required bool official});
  Future<List<CoachLibrarySession>> sessions({CoachLibrarySession? before});
  Future<WorkoutTemplate> template(String id);
  Future<TrainerClient> self();
  Future<void> assign({
    required String operationId,
    required String relationId,
    required String templateId,
    required DateTime date,
    required String note,
  });
  Future<List<Map<String, dynamic>>> schedule(String clientId, DateTime day);
  Future<void> withdraw(String assignmentId);
  Future<void> move(String operationId, CoachAssignment previous, DateTime day);
  Future<CoachPrivateNotes> notes(String clientId);
  Future<void> saveNotes(
    String operationId,
    String clientId,
    CoachPrivateNotes previous,
    String notes,
    String goal,
  );
  TrainerAppointmentRepository get appointments;
  Future<List<TrainerFollowupFormVersion>> forms();
  Future<void> sendForm(
    String operationId,
    String relationId,
    String formId,
    DateTime dueDate,
  );
  Future<List<TrainerFormAssignment>> formAssignments(
    String clientId, {
    TrainerFormAssignment? before,
  });
  Future<TrainerFormAssignment> formSubmission(String id);
}
