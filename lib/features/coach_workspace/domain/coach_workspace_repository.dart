import 'package:trainer_access/trainer_calendar.dart';
import 'package:trainer_access/trainer_access.dart';
import 'package:trainer_access/trainer_messages.dart';
import 'package:workout_core/professional_opposition_goal.dart';

class CoachAccount {
  const CoachAccount({required this.enabled});
  final bool enabled;
}

/// Proyección de consulta de la pauta existente, sin estado de edición propio.
class CoachAssignment {
  const CoachAssignment({
    required this.id,
    required this.name,
    required this.date,
    required this.clientId,
    required this.clientName,
    required this.status,
    required this.createdAt,
    this.changedAt,
    this.relationId,
    this.executionId,
    this.templateId,
    this.planningRevision,
    this.note,
  });
  final String id, name, clientId, clientName, status;
  final String? relationId, executionId, templateId, note;
  final int? planningRevision;
  final DateTime date, createdAt;
  final DateTime? changedAt;
  String get statusLabel => switch (status) {
    'planned' => 'Pendiente',
    'in_progress' => 'En curso',
    'completed' => 'Completada',
    'abandoned' => 'Abandonada',
    'skipped' => 'Omitida',
    'cancelled' => 'Retirada',
    _ => 'Sin confirmar',
  };
}

class CoachClientDetail {
  const CoachClientDetail(this.client, this.goal);
  final TrainerClient client;
  final ProfessionalOppositionGoal goal;
}

class CoachTechniquePending {
  const CoachTechniquePending({
    required this.id,
    required this.assignmentId,
    required this.createdAt,
    required this.clientName,
    required this.name,
  });
  final String id, assignmentId, clientName, name;
  final DateTime createdAt;
}

abstract class CoachWorkspaceRepository {
  Future<List<CoachTechniquePending>> pendingTechnique({
    CoachTechniquePending? before,
  });
  Future<SharedCalendarPage> sharedCalendar(
    String clientId,
    DateTime from,
    DateTime to, {
    SharedCalendarEntry? after,
  });
  Future<CoachAccount> account();
  Future<List<TrainerClient>> clients({
    TrainerClientState state = TrainerClientState.active,
    TrainerClient? before,
  });
  Future<CoachClientDetail> client(String id);
  Future<List<TrainerRelation>> relations(
    String clientId, {
    TrainerRelation? before,
  });
  Future<CoachAssignment> assignment(String id);
  Future<List<CoachAssignment>> agenda(
    DateTime from,
    DateTime to, {
    CoachAssignment? after,
  });
  Future<List<CoachAssignment>> assignments(
    String clientId, {
    CoachAssignment? before,
  });
  Future<List<CoachAssignment>> reviews({CoachAssignment? before});
  Future<Map<String, dynamic>?> result(String assignmentId);
  Future<List<Map<String, dynamic>>> technique(String assignmentId);
  Future<void> review(
    String operation,
    String assignmentId,
    int revision,
    String note,
  );
  Future<void> feedback(
    String operation,
    String assetId,
    double second,
    String body,
  );
  Future<TrainerMessageInbox> inbox();
}
