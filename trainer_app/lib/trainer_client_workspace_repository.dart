import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainer_access/trainer_access.dart';
import 'package:workout_core/performance_set_codec.dart';
import 'package:workout_core/trainer_progress.dart';
import 'package:workout_core/workout_template.dart';

typedef ClientWorkspaceJson = Map<String, dynamic>;
String workspaceDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class TrainerClientWorkspace {
  TrainerClientWorkspace.fromJson(ClientWorkspaceJson row)
    : client = TrainerClient.fromJson(
        ClientWorkspaceJson.from(row['client'] as Map),
      ),
      relations = List.unmodifiable(
        (row['relations'] as List).map(
          (r) => ClientWorkspaceJson.unmodifiable(r as Map),
        ),
      ),
      relationsComplete = row['relations_complete'] == true,
      revision = (row['notes'] as Map)['revision'] as int,
      notes = (row['notes'] as Map)['notes'] as String,
      goal = (row['notes'] as Map)['goal'] as String,
      canEditNotes = row['can_edit_notes'] == true;
  final TrainerClient client;
  final List<ClientWorkspaceJson> relations;
  final bool relationsComplete, canEditNotes;
  final int revision;
  final String notes, goal;
}

class TrainerClientProgressReport {
  TrainerClientProgressReport({
    required this.start,
    required this.endExclusive,
    required this.asOfDate,
    required Iterable<ClientWorkspaceJson> assignments,
    required Iterable<ClientWorkspaceJson> sets,
    required Iterable<ClientWorkspaceJson> amrap,
  }) : assignments = List.unmodifiable(
         assignments.map(ClientWorkspaceJson.unmodifiable),
       ),
       sets = List.unmodifiable(sets.map(ClientWorkspaceJson.unmodifiable)),
       amrap = List.unmodifiable(amrap.map(ClientWorkspaceJson.unmodifiable)) {
    period = TrainerProgressPeriod(
      startInclusive: TrainerProgressDate.fromCalendarDate(start),
      endExclusive: TrainerProgressDate.fromCalendarDate(endExclusive),
    );
    compliance = summarizeTrainerCompliance(
      assignments: this.assignments.map(
        (a) => TrainerProgressAssignment(
          id: a['id'] as String,
          scheduledDate: _date(a['scheduled_date'] as String),
          status: switch (a['status']) {
            'planned' => TrainerProgressAssignmentStatus.planned,
            'in_progress' => TrainerProgressAssignmentStatus.inProgress,
            'completed' => TrainerProgressAssignmentStatus.completed,
            'skipped' => TrainerProgressAssignmentStatus.skipped,
            'abandoned' => TrainerProgressAssignmentStatus.abandoned,
            'cancelled' => TrainerProgressAssignmentStatus.cancelled,
            final unknown => throw FormatException(
              'Estado de pauta desconocido: $unknown',
            ),
          },
          executionId: a['execution_id'] as String?,
        ),
      ),
      period: period,
      asOfDate: TrainerProgressDate.fromCalendarDate(asOfDate),
    );
    results = summarizeTrainerExerciseResults(
      sets: this.sets.map(
        (s) => TrainerProgressSetRecord(
          id: s['id'] as String,
          executionId: s['execution_id'] as String,
          exerciseId: s['exercise_id'] as String,
          recordDate: _date(s['record_date'] as String),
          status: switch (s['status']) {
            'pending' => TrainerProgressSetStatus.pending,
            'completed' => TrainerProgressSetStatus.completed,
            'skipped' => TrainerProgressSetStatus.skipped,
            final unknown => throw FormatException(
              'Estado de serie desconocido: $unknown',
            ),
          },
          blockFormat: _format(s['block_format'] as String),
          actualReps: s['actual_reps'] as int?,
          actualDurationSeconds: _num(s['actual_duration_seconds']),
          actualDistanceMeters: _num(s['actual_distance_meters']),
          actualLoadKg: _num(s['actual_load_kg']),
          actualRpe: _num(s['actual_rpe']),
          actualRir: _num(s['actual_rir']),
          performancePrescription: s['performance_prescription'] == null
              ? null
              : PerformanceSetCodec.prescription(
                  ClientWorkspaceJson.from(
                    s['performance_prescription'] as Map,
                  ),
                ),
          performanceResult: s['performance_result'] == null
              ? null
              : PerformanceSetCodec.result(
                  ClientWorkspaceJson.from(s['performance_result'] as Map),
                ),
        ),
      ),
      period: period,
      amrapBlocks: this.amrap.map(
        (a) => TrainerProgressAmrapRecord(
          executionId: a['execution_id'] as String,
          blockOrder: a['block_order'] as int,
          recordDate: _date(a['record_date'] as String),
          completedRounds: a['completed_rounds'] as int,
          partialItemOrder: a['partial_item_order'] as int?,
          partialReps: a['partial_reps'] as int,
        ),
      ),
    );
  }
  final DateTime start, endExclusive, asOfDate;
  final List<ClientWorkspaceJson> assignments, sets, amrap;
  late final TrainerProgressPeriod period;
  late final TrainerComplianceSummary compliance;
  late final TrainerExerciseResultsSummary results;
  static double? _num(Object? value) => (value as num?)?.toDouble();
  static TrainerProgressDate _date(String text) =>
      TrainerProgressDate.fromCalendarDate(DateTime.parse(text));
  static WorkoutBlockFormat _format(String value) => switch (value) {
    'straight_sets' => WorkoutBlockFormat.straightSets,
    'circuit' => WorkoutBlockFormat.circuit,
    'superset' => WorkoutBlockFormat.superset,
    'intervals' => WorkoutBlockFormat.intervals,
    'emom' => WorkoutBlockFormat.emom,
    'amrap' => WorkoutBlockFormat.amrap,
    'tabata' => WorkoutBlockFormat.tabata,
    'running' => WorkoutBlockFormat.running,
    'warm_up' => WorkoutBlockFormat.warmUp,
    'cool_down' => WorkoutBlockFormat.coolDown,
    _ => throw FormatException('Formato de bloque desconocido: $value'),
  };
  String exerciseName(String id) =>
      sets.where((s) => s['exercise_id'] == id).firstOrNull?['exercise_name']
          as String? ??
      id;
}

abstract class TrainerClientWorkspaceRepository {
  Future<TrainerClientWorkspace> get(String clientId);
  Future<int> saveNotes(
    String operationId,
    String clientId,
    int expectedRevision, {
    required String notes,
    required String goal,
  });
  Future<TrainerClientProgressReport> progress(
    String clientId,
    DateTime start,
    DateTime endExclusive,
  );
}

class SupabaseTrainerClientWorkspaceRepository
    implements TrainerClientWorkspaceRepository {
  const SupabaseTrainerClientWorkspaceRepository(this.client, this.userId);
  final SupabaseClient client;
  final String userId;
  void _identity() {
    if (client.auth.currentUser?.id != userId) {
      throw StateError('La cuenta ha cambiado.');
    }
  }

  Future<dynamic> _rpc(String name, Map<String, dynamic> parameters) async {
    _identity();
    final value = await client.rpc(name, params: parameters);
    _identity();
    return value;
  }

  @override
  Future<TrainerClientWorkspace> get(String clientId) async =>
      TrainerClientWorkspace.fromJson(
        ClientWorkspaceJson.from(
          await _rpc('get_trainer_client_workspace', {'p_client_id': clientId})
              as Map,
        ),
      );
  @override
  Future<int> saveNotes(
    String operationId,
    String clientId,
    int expectedRevision, {
    required String notes,
    required String goal,
  }) async {
    if (notes.trim().length > 2000 || goal.trim().length > 500) {
      throw const FormatException(
        'Las notas admiten 2.000 caracteres y el objetivo 500.',
      );
    }
    return await _rpc('save_trainer_client_notes', {
      'p_operation_id': operationId,
      'p_client_id': clientId,
      'p_expected_revision': expectedRevision,
      'p_notes': notes.trim(),
      'p_goal': goal.trim(),
    }) as int;
  }

  @override
  Future<TrainerClientProgressReport> progress(
    String clientId,
    DateTime start,
    DateTime endExclusive,
  ) async {
    if (endExclusive.difference(start).inDays > 366 ||
        !endExclusive.isAfter(start)) {
      throw const FormatException(
        'Selecciona un periodo de entre 1 y 366 días.',
      );
    }
    String? fingerprint;
    Future<List<ClientWorkspaceJson>> all(String kind) async {
      final rows = <ClientWorkspaceJson>[];
      String? beforeDate, beforeId;
      int? total;
      while (true) {
        final response = ClientWorkspaceJson.from(
          await _rpc('get_trainer_client_progress', {
            'p_client_id': clientId,
            'p_start': workspaceDate(start),
            'p_end_exclusive': workspaceDate(endExclusive),
            'p_kind': kind,
            'p_before_date': beforeDate,
            'p_before_id': beforeId,
          }) as Map,
        );
        final expectedBasis = kind == 'assignments'
            ? 'scheduled_civil_date'
            : 'execution_started_at_utc';
        if (response['date_basis'] != expectedBasis ||
            response['fingerprint'] is! String ||
            (fingerprint != null && fingerprint != response['fingerprint']) ||
            (total != null && total != response['total'])) {
          throw StateError(
            'Los resultados cambiaron durante la carga. Actualiza el informe.',
          );
        }
        fingerprint ??= response['fingerprint'] as String;
        total = response['total'] as int;
        final page = (response['items'] as List)
            .map((r) => ClientWorkspaceJson.from(r as Map))
            .toList();
        rows.addAll(page);
        if (response['has_more'] != true) {
          if (rows.length != total) {
            throw StateError(
              'El informe está incompleto. Actualiza para volver a cargarlo.',
            );
          }
          return rows;
        }
        if (page.isEmpty ||
            (page.last['record_date'] == beforeDate &&
                page.last['id'] == beforeId)) {
          throw StateError('La paginación no avanza. Actualiza el informe.');
        }
        beforeDate = page.last['record_date'] as String;
        beforeId = page.last['id'] as String;
      }
    }

    // Solo se calcula el resumen cuando se han cargado todas las páginas de
    // cada clase de dato; un error nunca convierte el primer lote en un total.
    final data = await Future.wait([
      all('assignments'),
      all('sets'),
      all('amrap'),
    ]);
    return TrainerClientProgressReport(
      start: start,
      endExclusive: endExclusive,
      asOfDate: DateTime.now().toUtc(),
      assignments: data[0],
      sets: data[1],
      amrap: data[2],
    );
  }
}
